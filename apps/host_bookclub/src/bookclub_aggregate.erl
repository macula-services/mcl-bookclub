%% @doc Aggregate root for a book club.
%%
%% One stream per club, born by initiate_bookclub_v1. The aggregate is the
%% consistency boundary: it refuses a second initiation and (in a later slice)
%% every command once archived. The club's stream id IS its identity -- minted
%% by the caller with initiate_bookclub_v1:mint_club_id/0, never derived from
%% a human-readable name.
-module(bookclub_aggregate).

-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, snapshot/1, from_snapshot/1]).

-spec state_module() -> module().
state_module() -> bookclub_state.

init(AggregateId) ->
    {ok, bookclub_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) -- State FIRST. The guard rules live in
%% the desk's maybe_ module; the aggregate only dispatches on the command
%% type, which is the house split: the desk owns the business rule, the
%% aggregate owns the stream boundary.
execute(State, #{command_type := initiate_bookclub_v1} = Payload) ->
    maybe_initiate_bookclub:handle_from_map(State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    bookclub_state:apply_event(State, Event).

snapshot(State) -> bookclub_state:to_map(State).

from_snapshot(Map) ->
    {ok, State} = bookclub_state:from_map(Map),
    State.
