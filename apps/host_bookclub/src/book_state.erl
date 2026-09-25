%% @doc The book aggregate's state: the record, its fold, its shape.
%%
%% The state module is the only module that sees the record. It remembers
%% the birth details (club_id, title, author, procured_at), so the retired
%% event can echo them and stay self-contained for its projection.
-module(book_state).

-behaviour(evoq_state).

-include("book_status.hrl").

-export([new/1, apply_event/2, to_map/1, from_map/1]).
-export([book_id/1, club_id/1, title/1, author/1, procured_at/1, club_name/1]).
-export([is_on_shelf/1, is_retired/1]).

-record(book_state, {
    book_id :: binary(),
    club_id = <<>> :: binary(),
    title = <<>> :: binary(),
    author = <<>> :: binary(),
    procured_at = 0 :: non_neg_integer(),
    club_name = <<>> :: binary(),
    status = 0 :: non_neg_integer()
}).

-opaque t() :: #book_state{}.
-export_type([t/0]).

-spec new(binary()) -> t().
new(BookId) ->
    #book_state{book_id = BookId}.

%% @doc Fold one event. evoq hands apply/2 TWO SHAPES for the same event:
%% the raw event right after execute/2 (business fields inline), and the
%% stored envelope on reload (business fields under `data'). Read tolerantly.
-spec apply_event(t(), map()) -> t().
apply_event(State, #{event_type := <<"book_procured_v1">>} = Event) ->
    Data = event_data(Event),
    State#book_state{
        club_id = maps:get(club_id, Data),
        title = maps:get(title, Data),
        author = maps:get(author, Data),
        procured_at = maps:get(procured_at, Data, 0),
        club_name = maps:get(club_name, Data, <<>>),
        status = evoq_bit_flags:set(State#book_state.status, ?BOOK_ON_SHELF)};
apply_event(State, #{event_type := <<"book_retired_v1">>}) ->
    State#book_state{
        status = evoq_bit_flags:set(State#book_state.status, ?BOOK_RETIRED)};
apply_event(State, _Event) ->
    State.

-spec to_map(t()) -> map().
to_map(#book_state{book_id = BookId,
                   club_id = ClubId,
                   title = Title,
                   author = Author,
                   procured_at = At,
                   club_name = ClubName,
                   status = Status}) ->
    #{book_id => BookId,
      club_id => ClubId,
      title => Title,
      author => Author,
      procured_at => At,
      club_name => ClubName,
      status => Status}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{book_id := BookId} = Map) ->
    {ok, #book_state{
        book_id = BookId,
        club_id = maps:get(club_id, Map, <<>>),
        title = maps:get(title, Map, <<>>),
        author = maps:get(author, Map, <<>>),
        procured_at = maps:get(procured_at, Map, 0),
        club_name = maps:get(club_name, Map, <<>>),
        status = maps:get(status, Map, 0)}};
from_map(_) ->
    {error, missing_book_id}.

-spec book_id(t()) -> binary().
book_id(#book_state{book_id = BookId}) ->
    BookId.

-spec club_id(t()) -> binary().
club_id(#book_state{club_id = ClubId}) ->
    ClubId.

-spec title(t()) -> binary().
title(#book_state{title = Title}) ->
    Title.

-spec author(t()) -> binary().
author(#book_state{author = Author}) ->
    Author.

-spec procured_at(t()) -> non_neg_integer().
procured_at(#book_state{procured_at = At}) ->
    At.

-spec club_name(t()) -> binary().
club_name(#book_state{club_name = ClubName}) ->
    ClubName.

-spec is_on_shelf(t()) -> boolean().
is_on_shelf(#book_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOK_ON_SHELF).

-spec is_retired(t()) -> boolean().
is_retired(#book_state{status = Status}) ->
    evoq_bit_flags:has(Status, ?BOOK_RETIRED).

event_data(#{data := Data}) -> Data;
event_data(Event) ->
    maps:without([event_type, version, metadata, event_id, stream_id,
                  timestamp, epoch_us, tags], Event).
