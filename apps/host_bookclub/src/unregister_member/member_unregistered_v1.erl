%% @doc The member_unregistered_v1 event: a fact about the past.
%%
%% SELF-CONTAINED, like the club's archived event: it echoes the member's
%% club, name and registration time from the aggregate state, so its
%% projection stays an absolute, idempotent write that never depends on the
%% registered event having arrived first.
-module(member_unregistered_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_member_id/1, get_club_id/1, get_name/1, get_registered_at/1,
         get_unregistered_by/1, get_unregistered_at/1]).

-record(member_unregistered, {
    member_id :: binary(),
    club_id :: binary(),
    name :: binary(),
    registered_at :: non_neg_integer(),
    unregistered_by :: binary(),
    unregistered_at :: integer()
}).

-opaque t() :: #member_unregistered{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"member_unregistered_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{member_id := MemberId, club_id := ClubId, name := Name,
      registered_at := RegisteredAt, unregistered_by := By})
        when is_binary(MemberId), is_binary(ClubId), is_binary(Name),
             is_integer(RegisteredAt), is_binary(By) ->
    {ok, #member_unregistered{member_id = MemberId,
                              club_id = ClubId,
                              name = Name,
                              registered_at = RegisteredAt,
                              unregistered_by = By,
                              unregistered_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#member_unregistered{member_id = MemberId,
                            club_id = ClubId,
                            name = Name,
                            registered_at = RegisteredAt,
                            unregistered_by = By,
                            unregistered_at = At}) ->
    #{event_type => event_type(),
      member_id => MemberId,
      club_id => ClubId,
      name => Name,
      registered_at => RegisteredAt,
      unregistered_by => By,
      unregistered_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{member_id := MemberId} = Map) ->
    {ok, #member_unregistered{
        member_id = MemberId,
        club_id = maps:get(club_id, Map, <<>>),
        name = maps:get(name, Map, <<>>),
        registered_at = maps:get(registered_at, Map, 0),
        unregistered_by = maps:get(unregistered_by, Map, <<>>),
        unregistered_at = maps:get(unregistered_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_member_id(t()) -> binary().
get_member_id(#member_unregistered{member_id = MemberId}) ->
    MemberId.

-spec get_club_id(t()) -> binary().
get_club_id(#member_unregistered{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#member_unregistered{name = Name}) ->
    Name.

-spec get_registered_at(t()) -> non_neg_integer().
get_registered_at(#member_unregistered{registered_at = At}) ->
    At.

-spec get_unregistered_by(t()) -> binary().
get_unregistered_by(#member_unregistered{unregistered_by = By}) ->
    By.

-spec get_unregistered_at(t()) -> integer().
get_unregistered_at(#member_unregistered{unregistered_at = At}) ->
    At.
