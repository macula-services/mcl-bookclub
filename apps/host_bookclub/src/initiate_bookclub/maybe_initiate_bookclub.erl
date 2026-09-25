%% @doc Handler for `initiate_bookclub_v1'.
%%
%% The desk: one module that owns the business rule (a club can only be
%% initiated once), produces the matching `bookclub_initiated_v1' event, and
%% dispatches. The aggregate calls handle_from_map/2; callers dispatch/1.
%%
%% The dispatch result IS the only error channel -- it is returned, never
%% discarded, and a bare `catch' around it would hide the rejection.
-module(maybe_initiate_bookclub).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% initiate_bookclub_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := initiate_bookclub_v1} = Payload) ->
    handled(State, initiate_bookclub_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a club is
%% initiated exactly once. The check is here, in the desk, not inside the
%% aggregate -- the aggregate owns the stream boundary, the desk owns the
%% rule.
-spec handle(bookclub_state:t(), initiate_bookclub_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    case {bookclub_state:is_initiated(State), initiate_bookclub_v1:validate(Cmd)} of
        {true, _} ->
            {error, already_initiated};
        {false, ok} ->
            events(Cmd);
        {false, {error, Reason}} ->
            {error, Reason}
    end.

events(Cmd) ->
    {ok, Event} = bookclub_initiated_v1:new(#{
        club_id => initiate_bookclub_v1:get_club_id(Cmd),
        name => initiate_bookclub_v1:get_name(Cmd),
        initiated_by => initiate_bookclub_v1:get_initiated_by(Cmd)}),
    {ok, [bookclub_initiated_v1:to_map(Event)]}.

%% @doc Initiate the club on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' when the aggregate starts and
%% reads a stream whose id fails the contract, so a dispatch that reaches the
%% store with a bad id crashes the aggregate into a restart loop instead of
%% returning an error. The desk is the boundary; it validates, then dispatches.
-spec dispatch(initiate_bookclub_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case initiate_bookclub_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(initiate_bookclub_v1, bookclub_aggregate,
                               initiate_bookclub_v1:stream_id(Cmd),
                               initiate_bookclub_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
