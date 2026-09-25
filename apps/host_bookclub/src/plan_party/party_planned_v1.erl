%% @doc The party_planned_v1 event: a fact about the past.
%%
%% It carries the club's NEW party count, echoed from the aggregate state:
%% a downstream consumer can rebuild the club's party tally from this event
%% alone, and the fold is an absolute assignment (applying the same event
%% twice sets the same count), never a relative increment.
-module(party_planned_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_club_id/1, get_parties_planned/1, get_planned_at/1]).

-record(party_planned, {
    club_id :: binary(),
    parties_planned :: non_neg_integer(),
    planned_at :: integer()
}).

-opaque t() :: #party_planned{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"party_planned_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId, parties_planned := Parties})
        when is_binary(ClubId), is_integer(Parties), Parties >= 0 ->
    {ok, #party_planned{club_id = ClubId,
                        parties_planned = Parties,
                        planned_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#party_planned{club_id = ClubId,
                      parties_planned = Parties,
                      planned_at = At}) ->
    #{event_type => event_type(),
      club_id => ClubId,
      parties_planned => Parties,
      planned_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId} = Map) ->
    {ok, #party_planned{
        club_id = ClubId,
        parties_planned = maps:get(parties_planned, Map, 0),
        planned_at = maps:get(planned_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_club_id(t()) -> binary().
get_club_id(#party_planned{club_id = ClubId}) ->
    ClubId.

-spec get_parties_planned(t()) -> non_neg_integer().
get_parties_planned(#party_planned{parties_planned = Parties}) ->
    Parties.

-spec get_planned_at(t()) -> integer().
get_planned_at(#party_planned{planned_at = At}) ->
    At.
