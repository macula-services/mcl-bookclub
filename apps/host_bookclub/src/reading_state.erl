%% @doc The reading aggregate's state: the record, its fold, its shape.
%%
%% The state module is the only module that sees the record. It remembers
%% the birth details (member_id, book_id, started_at), so the finished
%% event can echo them and stay self-contained for its projection -- the
%% fold a consumer needs, carried by the event instead of re-read from the
%% stream.
-module(reading_state).

-behaviour(evoq_state).

-include("reading_status.hrl").

-export([new/1, apply_event/2, to_map/1, from_map/1]).
-export([reading_id/1, member_id/1, book_id/1, started_at/1, pages_read/1]).
-export([is_in_progress/1, is_finished/1]).

-record(reading_state, {
    reading_id :: binary(),
    member_id = <<>> :: binary(),
    book_id = <<>> :: binary(),
    started_at = 0 :: non_neg_integer(),
    pages_read = 0 :: non_neg_integer(),
    status = 0 :: non_neg_integer()
}).

-opaque t() :: #reading_state{}.
-export_type([t/0]).

-spec new(binary()) -> t().
new(ReadingId) ->
    #reading_state{reading_id = ReadingId}.

%% @doc Fold one event. evoq hands apply/2 TWO SHAPES for the same event:
%% the raw event right after execute/2 (business fields inline), and the
%% stored envelope on reload (business fields under `data'). Read tolerantly.
-spec apply_event(t(), map()) -> t().
apply_event(State, #{event_type := <<"reading_started_v1">>} = Event) ->
    Data = event_data(Event),
    State#reading_state{
        member_id = maps:get(member_id, Data),
        book_id = maps:get(book_id, Data),
        started_at = maps:get(started_at, Data, 0),
        status = evoq_bit_flags:set(State#reading_state.status, ?READING_IN_PROGRESS)};
apply_event(State, #{event_type := <<"reading_finished_v1">>} = Event) ->
    Data = event_data(Event),
    State#reading_state{
        pages_read = maps:get(pages_read, Data, 0),
        status = evoq_bit_flags:set(State#reading_state.status, ?READING_FINISHED)};
apply_event(State, _Event) ->
    State.

-spec to_map(t()) -> map().
to_map(#reading_state{reading_id = ReadingId,
                      member_id = MemberId,
                      book_id = BookId,
                      started_at = StartedAt,
                      pages_read = Pages,
                      status = Status}) ->
    #{reading_id => ReadingId,
      member_id => MemberId,
      book_id => BookId,
      started_at => StartedAt,
      pages_read => Pages,
      status => Status}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{reading_id := ReadingId} = Map) ->
    {ok, #reading_state{
        reading_id = ReadingId,
        member_id = maps:get(member_id, Map, <<>>),
        book_id = maps:get(book_id, Map, <<>>),
        started_at = maps:get(started_at, Map, 0),
        pages_read = maps:get(pages_read, Map, 0),
        status = maps:get(status, Map, 0)}};
from_map(_) ->
    {error, missing_reading_id}.

-spec reading_id(t()) -> binary().
reading_id(#reading_state{reading_id = ReadingId}) ->
    ReadingId.

-spec member_id(t()) -> binary().
member_id(#reading_state{member_id = MemberId}) ->
    MemberId.

-spec book_id(t()) -> binary().
book_id(#reading_state{book_id = BookId}) ->
    BookId.

-spec started_at(t()) -> non_neg_integer().
started_at(#reading_state{started_at = At}) ->
    At.

-spec pages_read(t()) -> non_neg_integer().
pages_read(#reading_state{pages_read = Pages}) ->
    Pages.

-spec is_in_progress(t()) -> boolean().
is_in_progress(#reading_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?READING_IN_PROGRESS).

-spec is_finished(t()) -> boolean().
is_finished(#reading_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?READING_FINISHED).

event_data(#{data := Data}) -> Data;
event_data(Event) ->
    maps:without([event_type, version, metadata, event_id, stream_id,
                  timestamp, epoch_us, tags], Event).
