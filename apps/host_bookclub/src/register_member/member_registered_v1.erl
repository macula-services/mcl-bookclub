%% @doc The member_registered_v1 event: a fact about the past.
%%
%% Self-contained: it carries the club the member joined, so any downstream
%% consumer (the plan_party policy, the mesh emitter, the projection) reads
%% one event and knows everything it needs.
-module(member_registered_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_member_id/1, get_club_id/1, get_name/1, get_registered_at/1]).

-record(member_registered, {
    member_id :: binary(),
    club_id :: binary(),
    name :: binary(),
    club_name :: binary(),
    registered_at :: integer()
}).

-opaque t() :: #member_registered{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"member_registered_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{member_id := MemberId, club_id := ClubId, name := Name} = Params)
        when is_binary(MemberId), is_binary(ClubId), is_binary(Name) ->
    {ok, #member_registered{member_id = MemberId,
                            club_id = ClubId,
                            name = Name,
                            club_name = maps:get(club_name, Params, <<>>),
                            registered_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#member_registered{member_id = MemberId,
                          club_id = ClubId,
                          name = Name,
                          club_name = ClubName,
                          registered_at = At}) ->
    #{event_type => event_type(),
      member_id => MemberId,
      club_id => ClubId,
      name => Name,
      club_name => ClubName,
      registered_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{member_id := MemberId} = Map) ->
    {ok, #member_registered{
        member_id = MemberId,
        club_id = maps:get(club_id, Map, <<>>),
        name = maps:get(name, Map, <<>>),
        club_name = maps:get(club_name, Map, <<>>),
        registered_at = maps:get(registered_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_member_id(t()) -> binary().
get_member_id(#member_registered{member_id = MemberId}) ->
    MemberId.

-spec get_club_id(t()) -> binary().
get_club_id(#member_registered{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#member_registered{name = Name}) ->
    Name.

-spec get_registered_at(t()) -> integer().
get_registered_at(#member_registered{registered_at = At}) ->
    At.
