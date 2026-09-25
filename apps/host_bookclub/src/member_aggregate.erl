%% @doc Aggregate root for a book-club member.
%%
%% One stream per member, born by register_member_v1 and soft-deleted by
%% unregister_member_v1. Like the club, the aggregate owns a blanket
%% lifecycle guard: every command on an unregistered stream is refused
%% before any desk sees it. The member's stream id IS its identity, minted
%% by the caller with register_member_v1:mint_member_id/0.
-module(member_aggregate).

-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, snapshot/1, from_snapshot/1]).

-spec state_module() -> module().
state_module() -> member_state.

init(AggregateId) ->
    {ok, member_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) -- State FIRST. The guard rules live in
%% the desk's maybe_ module; the aggregate owns the stream's lifecycle.
execute(State, #{command_type := register_member_v1} = Payload) ->
    guarded(State, Payload, fun maybe_register_member:handle_from_map/2);
execute(State, #{command_type := unregister_member_v1} = Payload) ->
    guarded(State, Payload, fun maybe_unregister_member:handle_from_map/2);
execute(_State, _Unknown) ->
    {error, unknown_command}.

guarded(State, Payload, Desk) ->
    case member_state:is_unregistered(State) of
        true -> {error, unregistered};
        false -> Desk(State, Payload)
    end.

apply(State, Event) ->
    member_state:apply_event(State, Event).

snapshot(State) -> member_state:to_map(State).

from_snapshot(Map) ->
    {ok, State} = member_state:from_map(Map),
    State.
