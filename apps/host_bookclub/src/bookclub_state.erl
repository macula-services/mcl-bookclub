%% @doc The bookclub aggregate's state: the record, its fold, its shape.
%%
%% The state module is the only module that sees the record. The aggregate and
%% the handlers work through semantic getters (is_initiated/1, name/1, ...),
%% so a change to what the state keeps never ripples past this file.
%%
%% The state remembers the club's BIRTH DETAILS (initiated_by, initiated_at),
%% not just its name. That is load-bearing: events that downstream consumers
%% need must be self-contained, and the aggregate is the only place with the
%% state to echo those details into them -- so the state keeps them.
-module(bookclub_state).

-behaviour(evoq_state).

-include("bookclub_status.hrl").

-export([new/1, apply_event/2, to_map/1, from_map/1]).
-export([club_id/1, name/1, initiated_by/1, initiated_at/1, parties_planned/1]).
-export([is_initiated/1, is_archived/1]).

-record(bookclub_state, {
    club_id :: binary(),
    name = <<>> :: binary(),
    initiated_by = <<>> :: binary(),
    initiated_at = 0 :: non_neg_integer(),
    parties_planned = 0 :: non_neg_integer(),
    status = 0 :: non_neg_integer()
}).

-opaque t() :: #bookclub_state{}.
-export_type([t/0]).

-spec new(binary()) -> t().
new(ClubId) ->
    #bookclub_state{club_id = ClubId}.

%% @doc Fold one event. evoq hands apply/2 TWO SHAPES for the same event:
%% the raw event right after execute/2, with the business fields inline and
%% no `data' key (the in-memory fold), and the stored envelope on reload,
%% with the business fields under `data'. Read tolerantly -- matching one
%% shape only is a bug that shows up on the second command, never the first.
-spec apply_event(t(), map()) -> t().
apply_event(State, #{event_type := <<"bookclub_initiated_v1">>} = Event) ->
    Data = event_data(Event),
    State#bookclub_state{
        name = maps:get(name, Data),
        initiated_by = maps:get(initiated_by, Data),
        initiated_at = maps:get(initiated_at, Data, 0),
        status = evoq_bit_flags:set(State#bookclub_state.status, ?BOOKCLUB_INITIATED)};
apply_event(State, #{event_type := <<"bookclub_archived_v1">>}) ->
    State#bookclub_state{
        status = evoq_bit_flags:set(State#bookclub_state.status, ?BOOKCLUB_ARCHIVED)};
apply_event(State, #{event_type := <<"party_planned_v1">>} = Event) ->
    Data = event_data(Event),
    State#bookclub_state{
        parties_planned = maps:get(parties_planned, Data, 0)};
apply_event(State, _Event) ->
    State.

-spec to_map(t()) -> map().
to_map(#bookclub_state{club_id = ClubId,
                       name = Name,
                       initiated_by = By,
                       initiated_at = At,
                       parties_planned = Parties,
                       status = Status}) ->
    #{club_id => ClubId,
      name => Name,
      initiated_by => By,
      initiated_at => At,
      parties_planned => Parties,
      status => Status}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId} = Map) ->
    {ok, #bookclub_state{
        club_id = ClubId,
        name = maps:get(name, Map, <<>>),
        initiated_by = maps:get(initiated_by, Map, <<>>),
        initiated_at = maps:get(initiated_at, Map, 0),
        parties_planned = maps:get(parties_planned, Map, 0),
        status = maps:get(status, Map, 0)}};
from_map(_) ->
    {error, missing_club_id}.

-spec club_id(t()) -> binary().
club_id(#bookclub_state{club_id = ClubId}) ->
    ClubId.

-spec name(t()) -> binary().
name(#bookclub_state{name = Name}) ->
    Name.

-spec initiated_by(t()) -> binary().
initiated_by(#bookclub_state{initiated_by = By}) ->
    By.

-spec initiated_at(t()) -> non_neg_integer().
initiated_at(#bookclub_state{initiated_at = At}) ->
    At.

-spec parties_planned(t()) -> non_neg_integer().
parties_planned(#bookclub_state{parties_planned = Parties}) ->
    Parties.

-spec is_initiated(t()) -> boolean().
is_initiated(#bookclub_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOKCLUB_INITIATED).

-spec is_archived(t()) -> boolean().
is_archived(#bookclub_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOKCLUB_ARCHIVED).

event_data(#{data := Data}) -> Data;
event_data(Event) ->
    maps:without([event_type, version, metadata, event_id, stream_id,
                  timestamp, epoch_us, tags], Event).
