%% @doc The member aggregate's state: the record, its fold, its shape.
%%
%% The state module is the only module that sees the record. Like the club's
%% state, it remembers the birth details (club_id, name, registered_at), so
%% the unregistered event can echo them and stay self-contained for its
%% projection.
-module(member_state).

-behaviour(evoq_state).

-include("member_status.hrl").

-export([new/1, apply_event/2, to_map/1, from_map/1]).
-export([member_id/1, club_id/1, name/1, registered_at/1]).
-export([is_registered/1, is_unregistered/1]).

-record(member_state, {
    member_id :: binary(),
    club_id = <<>> :: binary(),
    name = <<>> :: binary(),
    registered_at = 0 :: non_neg_integer(),
    status = 0 :: non_neg_integer()
}).

-opaque t() :: #member_state{}.
-export_type([t/0]).

-spec new(binary()) -> t().
new(MemberId) ->
    #member_state{member_id = MemberId}.

%% @doc Fold one event. evoq hands apply/2 TWO SHAPES for the same event:
%% the raw event right after execute/2 (business fields inline), and the
%% stored envelope on reload (business fields under `data'). Read tolerantly.
-spec apply_event(t(), map()) -> t().
apply_event(State, #{event_type := <<"member_registered_v1">>} = Event) ->
    Data = event_data(Event),
    State#member_state{
        club_id = maps:get(club_id, Data),
        name = maps:get(name, Data),
        registered_at = maps:get(registered_at, Data, 0),
        status = evoq_bit_flags:set(State#member_state.status, ?MEMBER_REGISTERED)};
apply_event(State, #{event_type := <<"member_unregistered_v1">>}) ->
    State#member_state{
        status = evoq_bit_flags:set(State#member_state.status, ?MEMBER_UNREGISTERED)};
apply_event(State, _Event) ->
    State.

-spec to_map(t()) -> map().
to_map(#member_state{member_id = MemberId,
                     club_id = ClubId,
                     name = Name,
                     registered_at = At,
                     status = Status}) ->
    #{member_id => MemberId,
      club_id => ClubId,
      name => Name,
      registered_at => At,
      status => Status}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{member_id := MemberId} = Map) ->
    {ok, #member_state{
        member_id = MemberId,
        club_id = maps:get(club_id, Map, <<>>),
        name = maps:get(name, Map, <<>>),
        registered_at = maps:get(registered_at, Map, 0),
        status = maps:get(status, Map, 0)}};
from_map(_) ->
    {error, missing_member_id}.

-spec member_id(t()) -> binary().
member_id(#member_state{member_id = MemberId}) ->
    MemberId.

-spec club_id(t()) -> binary().
club_id(#member_state{club_id = ClubId}) ->
    ClubId.

-spec name(t()) -> binary().
name(#member_state{name = Name}) ->
    Name.

-spec registered_at(t()) -> non_neg_integer().
registered_at(#member_state{registered_at = At}) ->
    At.

-spec is_registered(t()) -> boolean().
is_registered(#member_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?MEMBER_REGISTERED).

-spec is_unregistered(t()) -> boolean().
is_unregistered(#member_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?MEMBER_UNREGISTERED).

event_data(#{data := Data}) -> Data;
event_data(Event) ->
    maps:without([event_type, version, metadata, event_id, stream_id,
                  timestamp, epoch_us, tags], Event).
