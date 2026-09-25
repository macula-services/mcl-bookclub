%% @doc Aggregate root for one member's reading of one book.
%%
%% One stream per reading, born by start_reading_v1 and closed by
%% finish_reading_v1. The reading is the child: the member identifies it
%% (mints the reading id), the reading initiates itself with its own birth
%% event. Like every aggregate here, it owns a blanket lifecycle guard:
%% every command on a finished stream is refused before any desk sees it.
-module(reading_aggregate).

-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, snapshot/1, from_snapshot/1]).

-spec state_module() -> module().
state_module() -> reading_state.

init(AggregateId) ->
    {ok, reading_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) -- State FIRST. The guard rules live in
%% the desk's maybe_ module; the aggregate owns the stream's lifecycle.
execute(State, #{command_type := start_reading_v1} = Payload) ->
    guarded(State, Payload, fun maybe_start_reading:handle_from_map/2);
execute(State, #{command_type := finish_reading_v1} = Payload) ->
    guarded(State, Payload, fun maybe_finish_reading:handle_from_map/2);
execute(_State, _Unknown) ->
    {error, unknown_command}.

guarded(State, Payload, Desk) ->
    case reading_state:is_finished(State) of
        true -> {error, finished};
        false -> Desk(State, Payload)
    end.

apply(State, Event) ->
    reading_state:apply_event(State, Event).

snapshot(State) -> reading_state:to_map(State).

from_snapshot(Map) ->
    {ok, State} = reading_state:from_map(Map),
    State.
