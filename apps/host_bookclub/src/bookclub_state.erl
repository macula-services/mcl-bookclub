%% @doc The bookclub aggregate's state: the record, its fold, its shape.
%%
%% The state module is the only module that sees the record. The aggregate and
%% the handlers work through semantic getters (is_initiated/1, name/1, ...),
%% so a change to what the state keeps never ripples past this file.
-module(bookclub_state).

-behaviour(evoq_state).

-include("bookclub_status.hrl").

-export([new/1, apply_event/2, to_map/1, from_map/1]).
-export([is_initiated/1, is_archived/1, name/1]).

-record(bookclub_state, {
    club_id :: binary(),
    name = <<>> :: binary(),
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
        status = evoq_bit_flags:set(State#bookclub_state.status, ?BOOKCLUB_INITIATED)};
apply_event(State, _Event) ->
    State.

-spec to_map(t()) -> map().
to_map(#bookclub_state{club_id = ClubId, name = Name, status = Status}) ->
    #{club_id => ClubId, name => Name, status => Status}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId} = Map) ->
    {ok, #bookclub_state{
        club_id = ClubId,
        name = maps:get(name, Map, <<>>),
        status = maps:get(status, Map, 0)}};
from_map(_) ->
    {error, missing_club_id}.

-spec is_initiated(t()) -> boolean().
is_initiated(#bookclub_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOKCLUB_INITIATED).

-spec is_archived(t()) -> boolean().
is_archived(#bookclub_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOKCLUB_ARCHIVED).

-spec name(t()) -> binary().
name(#bookclub_state{name = Name}) ->
    Name.

event_data(#{data := Data}) -> Data;
event_data(Event) ->
    maps:without([event_type, version, metadata, event_id, stream_id,
                  timestamp, epoch_us, tags], Event).
