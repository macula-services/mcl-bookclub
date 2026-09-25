%% @doc Handler for `finish_reading_v1'.
%%
%% The desk: one module that owns the business rule (a reading finishes
%% only once it is in progress), produces the matching `reading_finished_v1'
%% event, and dispatches. The already-finished refusal is the aggregate's
%% blanket guard, not this desk's.
-module(maybe_finish_reading).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% finish_reading_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := finish_reading_v1} = Payload) ->
    handled(State, finish_reading_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a reading
%% can only finish once it is in progress.
-spec handle(reading_state:t(), finish_reading_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    finish_when_in_progress(reading_state:is_in_progress(State), State, Cmd).

finish_when_in_progress(false, _State, _Cmd) ->
    {error, not_started};
finish_when_in_progress(true, State, Cmd) ->
    case finish_reading_v1:validate(Cmd) of
        ok ->
            events(State, Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(State, Cmd) ->
    {ok, Event} = reading_finished_v1:new(#{
        reading_id => reading_state:reading_id(State),
        member_id => reading_state:member_id(State),
        book_id => reading_state:book_id(State),
        started_at => reading_state:started_at(State),
        pages_read => finish_reading_v1:get_pages_read(Cmd)}),
    {ok, [reading_finished_v1:to_map(Event)]}.

%% @doc Finish the reading on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(finish_reading_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case finish_reading_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(finish_reading_v1, reading_aggregate,
                               finish_reading_v1:stream_id(Cmd),
                               finish_reading_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
