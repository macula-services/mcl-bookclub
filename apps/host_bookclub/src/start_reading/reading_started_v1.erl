%% @doc The reading_started_v1 event: a fact about the past.
%%
%% Self-contained: it carries the member and the book being read, so any
%% downstream consumer reads one event and knows everything it needs.
-module(reading_started_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_reading_id/1, get_member_id/1, get_book_id/1, get_started_at/1]).

-record(reading_started, {
    reading_id :: binary(),
    member_id :: binary(),
    book_id :: binary(),
    started_at :: integer()
}).

-opaque t() :: #reading_started{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"reading_started_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{reading_id := ReadingId, member_id := MemberId, book_id := BookId})
        when is_binary(ReadingId), is_binary(MemberId), is_binary(BookId) ->
    {ok, #reading_started{reading_id = ReadingId,
                          member_id = MemberId,
                          book_id = BookId,
                          started_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#reading_started{reading_id = ReadingId,
                        member_id = MemberId,
                        book_id = BookId,
                        started_at = At}) ->
    #{event_type => event_type(),
      reading_id => ReadingId,
      member_id => MemberId,
      book_id => BookId,
      started_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{reading_id := ReadingId} = Map) ->
    {ok, #reading_started{
        reading_id = ReadingId,
        member_id = maps:get(member_id, Map, <<>>),
        book_id = maps:get(book_id, Map, <<>>),
        started_at = maps:get(started_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_reading_id(t()) -> binary().
get_reading_id(#reading_started{reading_id = ReadingId}) ->
    ReadingId.

-spec get_member_id(t()) -> binary().
get_member_id(#reading_started{member_id = MemberId}) ->
    MemberId.

-spec get_book_id(t()) -> binary().
get_book_id(#reading_started{book_id = BookId}) ->
    BookId.

-spec get_started_at(t()) -> integer().
get_started_at(#reading_started{started_at = At}) ->
    At.
