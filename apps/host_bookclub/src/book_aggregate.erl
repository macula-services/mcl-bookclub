%% @doc Aggregate root for a book on the club's shelf.
%%
%% One stream per book, born by procure_book_v1 and soft-deleted by
%% retire_book_v1. Like the club and the member, the aggregate owns a
%% blanket lifecycle guard: every command on a retired stream is refused
%% before any desk sees it.
-module(book_aggregate).

-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, snapshot/1, from_snapshot/1]).

-spec state_module() -> module().
state_module() -> book_state.

init(AggregateId) ->
    {ok, book_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) -- State FIRST. The guard rules live in
%% the desk's maybe_ module; the aggregate owns the stream's lifecycle.
execute(State, #{command_type := procure_book_v1} = Payload) ->
    guarded(State, Payload, fun maybe_procure_book:handle_from_map/2);
execute(State, #{command_type := retire_book_v1} = Payload) ->
    guarded(State, Payload, fun maybe_retire_book:handle_from_map/2);
execute(_State, _Unknown) ->
    {error, unknown_command}.

guarded(State, Payload, Desk) ->
    case book_state:is_retired(State) of
        true -> {error, retired};
        false -> Desk(State, Payload)
    end.

apply(State, Event) ->
    book_state:apply_event(State, Event).

snapshot(State) -> book_state:to_map(State).

from_snapshot(Map) ->
    {ok, State} = book_state:from_map(Map),
    State.
