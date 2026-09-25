%% @doc The book_retired_v1 event: a fact about the past.
%%
%% SELF-CONTAINED, like the club's archived and the member's unregistered
%% events: it echoes the bibliographic facts from the aggregate state, so
%% its projection stays an absolute, idempotent write that never depends on
%% the procured event having arrived first.
-module(book_retired_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_book_id/1, get_club_id/1, get_title/1, get_author/1,
         get_procured_at/1, get_retired_by/1, get_retired_at/1]).

-record(book_retired, {
    book_id :: binary(),
    club_id :: binary(),
    title :: binary(),
    author :: binary(),
    procured_at :: non_neg_integer(),
    club_name :: binary(),
    retired_by :: binary(),
    retired_at :: integer()
}).

-opaque t() :: #book_retired{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"book_retired_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{book_id := BookId, club_id := ClubId, title := Title, author := Author,
      procured_at := ProcuredAt, retired_by := By} = Params)
        when is_binary(BookId), is_binary(ClubId), is_binary(Title),
             is_binary(Author), is_integer(ProcuredAt), is_binary(By) ->
    {ok, #book_retired{book_id = BookId,
                       club_id = ClubId,
                       title = Title,
                       author = Author,
                       procured_at = ProcuredAt,
                       club_name = maps:get(club_name, Params, <<>>),
                       retired_by = By,
                       retired_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#book_retired{book_id = BookId,
                     club_id = ClubId,
                     title = Title,
                     author = Author,
                     procured_at = ProcuredAt,
                     club_name = ClubName,
                     retired_by = By,
                     retired_at = At}) ->
    #{event_type => event_type(),
      book_id => BookId,
      club_id => ClubId,
      title => Title,
      author => Author,
      procured_at => ProcuredAt,
      club_name => ClubName,
      retired_by => By,
      retired_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{book_id := BookId} = Map) ->
    {ok, #book_retired{
        book_id = BookId,
        club_id = maps:get(club_id, Map, <<>>),
        title = maps:get(title, Map, <<>>),
        author = maps:get(author, Map, <<>>),
        procured_at = maps:get(procured_at, Map, 0),
        club_name = maps:get(club_name, Map, <<>>),
        retired_by = maps:get(retired_by, Map, <<>>),
        retired_at = maps:get(retired_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_book_id(t()) -> binary().
get_book_id(#book_retired{book_id = BookId}) ->
    BookId.

-spec get_club_id(t()) -> binary().
get_club_id(#book_retired{club_id = ClubId}) ->
    ClubId.

-spec get_title(t()) -> binary().
get_title(#book_retired{title = Title}) ->
    Title.

-spec get_author(t()) -> binary().
get_author(#book_retired{author = Author}) ->
    Author.

-spec get_procured_at(t()) -> non_neg_integer().
get_procured_at(#book_retired{procured_at = At}) ->
    At.

-spec get_retired_by(t()) -> binary().
get_retired_by(#book_retired{retired_by = By}) ->
    By.

-spec get_retired_at(t()) -> integer().
get_retired_at(#book_retired{retired_at = At}) ->
    At.
