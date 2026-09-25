%% @doc The bookclub_archived_v1 event: a fact about the past.
%%
%% SELF-CONTAINED, DELIBERATELY: it echoes name, initiated_by and
%% initiated_at from the aggregate state, so its projection can rebuild the
%% whole clubs row from this event alone and stay an idempotent, absolute
%% write. The alternative -- a projection UPDATE that assumes the initiated
%% event arrived first -- breaks silently the day a projection is added
%% after history exists. The house rule: if an event is too poor for its
%% consumers, enrich it at the source.
-module(bookclub_archived_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_club_id/1, get_name/1, get_initiated_by/1, get_initiated_at/1,
         get_archived_by/1, get_archived_at/1]).

-record(bookclub_archived, {
    club_id :: binary(),
    name :: binary(),
    initiated_by :: binary(),
    initiated_at :: non_neg_integer(),
    archived_by :: binary(),
    archived_at :: integer()
}).

-opaque t() :: #bookclub_archived{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"bookclub_archived_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId, name := Name, initiated_by := InitiatedBy,
      initiated_at := InitiatedAt, archived_by := By})
        when is_binary(ClubId), is_binary(Name), is_binary(InitiatedBy),
             is_integer(InitiatedAt), is_binary(By) ->
    {ok, #bookclub_archived{club_id = ClubId,
                            name = Name,
                            initiated_by = InitiatedBy,
                            initiated_at = InitiatedAt,
                            archived_by = By,
                            archived_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

%% @doc The stored payload: atom keys, event_type included -- evoq extracts
%% the type with an atom lookup when it builds the envelope.
-spec to_map(t()) -> map().
to_map(#bookclub_archived{club_id = ClubId,
                          name = Name,
                          initiated_by = InitiatedBy,
                          initiated_at = InitiatedAt,
                          archived_by = By,
                          archived_at = At}) ->
    #{event_type => event_type(),
      club_id => ClubId,
      name => Name,
      initiated_by => InitiatedBy,
      initiated_at => InitiatedAt,
      archived_by => By,
      archived_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId, name := Name} = Map) ->
    {ok, #bookclub_archived{
        club_id = ClubId,
        name = Name,
        initiated_by = maps:get(initiated_by, Map, <<>>),
        initiated_at = maps:get(initiated_at, Map, 0),
        archived_by = maps:get(archived_by, Map, <<>>),
        archived_at = maps:get(archived_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_club_id(t()) -> binary().
get_club_id(#bookclub_archived{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#bookclub_archived{name = Name}) ->
    Name.

-spec get_initiated_by(t()) -> binary().
get_initiated_by(#bookclub_archived{initiated_by = By}) ->
    By.

-spec get_initiated_at(t()) -> non_neg_integer().
get_initiated_at(#bookclub_archived{initiated_at = At}) ->
    At.

-spec get_archived_by(t()) -> binary().
get_archived_by(#bookclub_archived{archived_by = By}) ->
    By.

-spec get_archived_at(t()) -> integer().
get_archived_at(#bookclub_archived{archived_at = At}) ->
    At.
