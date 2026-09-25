%% @doc The reading_finished_v1 event: a fact about the past.
%%
%% SELF-CONTAINED, like every soft-delete event here: it echoes the member,
%% the book and the start time from the aggregate state, so its projection
%% can fold the readings row from this event alone -- an absolute,
%% idempotent write that never depends on the started event having arrived
%% first.
-module(reading_finished_v1).

-behaviour(evoq_event).

-export([event_type/0, new/1, to_map/1, from_map/1]).
-export([get_reading_id/1, get_member_id/1, get_book_id/1, get_started_at/1,
         get_pages_read/1, get_finished_at/1]).

-record(reading_finished, {
    reading_id :: binary(),
    member_id :: binary(),
    book_id :: binary(),
    started_at :: non_neg_integer(),
    pages_read :: non_neg_integer(),
    finished_at :: integer()
}).

-opaque t() :: #reading_finished{}.
-export_type([t/0]).

-spec event_type() -> binary().
event_type() -> <<"reading_finished_v1">>.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{reading_id := ReadingId, member_id := MemberId, book_id := BookId,
      started_at := StartedAt, pages_read := Pages})
        when is_binary(ReadingId), is_binary(MemberId), is_binary(BookId),
             is_integer(StartedAt), is_integer(Pages), Pages >= 0 ->
    {ok, #reading_finished{reading_id = ReadingId,
                           member_id = MemberId,
                           book_id = BookId,
                           started_at = StartedAt,
                           pages_read = Pages,
                           finished_at = erlang:system_time(millisecond)}};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(t()) -> map().
to_map(#reading_finished{reading_id = ReadingId,
                         member_id = MemberId,
                         book_id = BookId,
                         started_at = StartedAt,
                         pages_read = Pages,
                         finished_at = At}) ->
    #{event_type => event_type(),
      reading_id => ReadingId,
      member_id => MemberId,
      book_id => BookId,
      started_at => StartedAt,
      pages_read => Pages,
      finished_at => At}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{reading_id := ReadingId} = Map) ->
    {ok, #reading_finished{
        reading_id = ReadingId,
        member_id = maps:get(member_id, Map, <<>>),
        book_id = maps:get(book_id, Map, <<>>),
        started_at = maps:get(started_at, Map, 0),
        pages_read = maps:get(pages_read, Map, 0),
        finished_at = maps:get(finished_at, Map, 0)}};
from_map(_) ->
    {error, missing_required_fields}.

-spec get_reading_id(t()) -> binary().
get_reading_id(#reading_finished{reading_id = ReadingId}) ->
    ReadingId.

-spec get_member_id(t()) -> binary().
get_member_id(#reading_finished{member_id = MemberId}) ->
    MemberId.

-spec get_book_id(t()) -> binary().
get_book_id(#reading_finished{book_id = BookId}) ->
    BookId.

-spec get_started_at(t()) -> non_neg_integer().
get_started_at(#reading_finished{started_at = At}) ->
    At.

-spec get_pages_read(t()) -> non_neg_integer().
get_pages_read(#reading_finished{pages_read = Pages}) ->
    Pages.

-spec get_finished_at(t()) -> integer().
get_finished_at(#reading_finished{finished_at = At}) ->
    At.
