%% @doc The bookclub_initiated_v1 event: a fact about the past.
%%
%% Past tense, business verb, `_v1' suffix -- the house event-naming rules.
%% The module returns a binary from event_type/0, which is what
%% evoq_event_handler's interested_in/0 matches on (the behaviour spec says
%% atom; every real consumer in this family matches binaries).
-module(bookclub_initiated_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_club_id/1, get_name/1, get_initiated_by/1, get_initiated_at/1]).

-record(bookclub_initiated, {
    club_id :: binary(),
    name :: binary(),
    initiated_by :: binary(),
    initiated_at :: integer()
}).

-opaque t() :: #bookclub_initiated{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"bookclub_initiated_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId, name := Name, initiated_by := By})
        when is_binary(ClubId), is_binary(Name), is_binary(By) ->
    {ok, #bookclub_initiated{club_id = ClubId,
                             name = Name,
                             initiated_by = By,
                             initiated_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

%% @doc The stored payload: atom keys, event_type included -- evoq extracts
%% the type with an atom lookup when it builds the envelope.
-spec to_map(t()) -> map().
to_map(#bookclub_initiated{club_id = ClubId,
                           name = Name,
                           initiated_by = By,
                           initiated_at = At}) ->
    #{event_type => event_type(),
      club_id => ClubId,
      name => Name,
      initiated_by => By,
      initiated_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId} = Map) ->
    {ok, #bookclub_initiated{
        club_id = ClubId,
        name = maps:get(name, Map, <<>>),
        initiated_by = maps:get(initiated_by, Map, <<>>),
        initiated_at = maps:get(initiated_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_club_id(t()) -> binary().
get_club_id(#bookclub_initiated{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#bookclub_initiated{name = Name}) ->
    Name.

-spec get_initiated_by(t()) -> binary().
get_initiated_by(#bookclub_initiated{initiated_by = By}) ->
    By.

-spec get_initiated_at(t()) -> integer().
get_initiated_at(#bookclub_initiated{initiated_at = At}) ->
    At.
