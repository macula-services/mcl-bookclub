%% @doc The book_procured_v1 event: a fact about the past.
%%
%% Self-contained: it carries the club and the bibliographic facts, so any
%% downstream consumer reads one event and knows everything it needs.
-module(book_procured_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_book_id/1, get_club_id/1, get_title/1, get_author/1, get_procured_at/1]).

-record(book_procured, {
    book_id :: binary(),
    club_id :: binary(),
    title :: binary(),
    author :: binary(),
    procured_at :: integer()
}).

-opaque t() :: #book_procured{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"book_procured_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{book_id := BookId, club_id := ClubId, title := Title, author := Author})
        when is_binary(BookId), is_binary(ClubId),
             is_binary(Title), is_binary(Author) ->
    {ok, #book_procured{book_id = BookId,
                        club_id = ClubId,
                        title = Title,
                        author = Author,
                        procured_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#book_procured{book_id = BookId,
                      club_id = ClubId,
                      title = Title,
                      author = Author,
                      procured_at = At}) ->
    #{event_type => event_type(),
      book_id => BookId,
      club_id => ClubId,
      title => Title,
      author => Author,
      procured_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{book_id := BookId} = Map) ->
    {ok, #book_procured{
        book_id = BookId,
        club_id = maps:get(club_id, Map, <<>>),
        title = maps:get(title, Map, <<>>),
        author = maps:get(author, Map, <<>>),
        procured_at = maps:get(procured_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_book_id(t()) -> binary().
get_book_id(#book_procured{book_id = BookId}) ->
    BookId.

-spec get_club_id(t()) -> binary().
get_club_id(#book_procured{club_id = ClubId}) ->
    ClubId.

-spec get_title(t()) -> binary().
get_title(#book_procured{title = Title}) ->
    Title.

-spec get_author(t()) -> binary().
get_author(#book_procured{author = Author}) ->
    Author.

-spec get_procured_at(t()) -> integer().
get_procured_at(#book_procured{procured_at = At}) ->
    At.
