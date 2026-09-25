%% @doc Handler for `start_reading_v1'.
%%
%% The desk: one module that owns the business rule (a reading starts
%% once), produces the matching `reading_started_v1' event, and dispatches.
%% The aggregate calls handle_from_map/2; callers dispatch/1.
-module(maybe_start_reading).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% start_reading_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := start_reading_v1} = Payload) ->
    handled(State, start_reading_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a reading
%% starts exactly once. The already-finished refusal is the aggregate's
%% blanket guard, not this desk's.
-spec handle(reading_state:t(), start_reading_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    start_when_fresh(reading_state:is_in_progress(State), Cmd).

start_when_fresh(true, _Cmd) ->
    {error, already_started};
start_when_fresh(false, Cmd) ->
    case start_reading_v1:validate(Cmd) of
        ok ->
            events(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(Cmd) ->
    {ok, Event} = reading_started_v1:new(#{
        reading_id => start_reading_v1:get_reading_id(Cmd),
        member_id => start_reading_v1:get_member_id(Cmd),
        book_id => start_reading_v1:get_book_id(Cmd)}),
    {ok, [reading_started_v1:to_map(Event)]}.

%% @doc Start the reading on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(start_reading_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case start_reading_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(start_reading_v1, reading_aggregate,
                               start_reading_v1:stream_id(Cmd),
                               start_reading_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
