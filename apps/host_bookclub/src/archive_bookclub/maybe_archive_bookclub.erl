%% @doc Handler for `archive_bookclub_v1'.
%%
%% The desk: one module that owns the business rule (a club archives once,
%% and only after it exists), produces the matching `bookclub_archived_v1'
%% event, and dispatches. The aggregate calls handle_from_map/2; callers
%% dispatch/1.
%%
%% The event echoes the club's birth details from the aggregate state, so
%% the projection stays a self-sufficient absolute write -- see
%% bookclub_archived_v1's moduledoc for why that matters.
-module(maybe_archive_bookclub).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% archive_bookclub_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := archive_bookclub_v1} = Payload) ->
    handled(State, archive_bookclub_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a club can
%% only be archived once it exists. The already-archived refusal is NOT
%% here: the aggregate's blanket lifecycle guard owns it and returns
%% `{error, archived}' for every command on an archived stream before any
%% desk sees it, so a check here would be dead code.
-spec handle(bookclub_state:t(), archive_bookclub_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    archive_when_initiated(bookclub_state:is_initiated(State), State, Cmd).

archive_when_initiated(false, _State, _Cmd) ->
    {error, not_initiated};
archive_when_initiated(true, State, Cmd) ->
    case archive_bookclub_v1:validate(Cmd) of
        ok ->
            events(State, Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(State, Cmd) ->
    {ok, Event} = bookclub_archived_v1:new(#{
        club_id => bookclub_state:club_id(State),
        name => bookclub_state:name(State),
        initiated_by => bookclub_state:initiated_by(State),
        initiated_at => bookclub_state:initiated_at(State),
        archived_by => archive_bookclub_v1:get_archived_by(Cmd)}),
    {ok, [bookclub_archived_v1:to_map(Event)]}.

%% @doc Archive the club on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(archive_bookclub_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case archive_bookclub_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(archive_bookclub_v1, bookclub_aggregate,
                               archive_bookclub_v1:stream_id(Cmd),
                               archive_bookclub_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
