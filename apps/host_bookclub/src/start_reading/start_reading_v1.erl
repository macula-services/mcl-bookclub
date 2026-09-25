%% @doc The start_reading_v1 command: a member starts reading a book.
%%
%% The reading is the child aggregate: the member's side identifies it (the
%% reading id is minted here), and the reading initiates itself with its own
%% birth event. The command carries the member and the book being read --
%% the parents the reading refers to.
-module(start_reading_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([mint_reading_id/0, stream_id/1, get_reading_id/1,
         get_member_id/1, get_book_id/1]).

-record(start_reading, {
    reading_id :: binary(),
    member_id :: binary(),
    book_id :: binary()
}).

-opaque t() :: #start_reading{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> start_reading_v1.

%% @doc Mint the reading's stream id. The AggregateId IS the reckon stream
%% id, so the parents go in the payload and this derived id is what the
%% command is addressed to.
-spec mint_reading_id() -> binary().
mint_reading_id() ->
    reckon_gater_stream_id:new(<<"reading">>).

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{reading_id := ReadingId, member_id := MemberId, book_id := BookId}) ->
    record_when(is_binary(ReadingId), ReadingId =/= <<>>,
                is_binary(MemberId), MemberId =/= <<>>,
                is_binary(BookId), BookId =/= <<>>,
                ReadingId, MemberId, BookId);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, true, true, ReadingId, MemberId, BookId) ->
    {ok, #start_reading{reading_id = ReadingId, member_id = MemberId, book_id = BookId}};
record_when(_, _, _, _, _, _, _, _, _) ->
    {error, invalid_params}.

%% @doc Checks about the world, not the shape: every stream id must satisfy
%% the reckon-db stream contract.
-spec validate(t()) -> ok | {error, term()}.
validate(#start_reading{reading_id = ReadingId, member_id = MemberId, book_id = BookId}) ->
    case {reckon_gater_stream_id:validate(ReadingId),
          reckon_gater_stream_id:validate(MemberId),
          reckon_gater_stream_id:validate(BookId)} of
        {ok, ok, ok} ->
            ok;
        {{error, Reason}, _, _} ->
            {error, Reason};
        {_, {error, Reason}, _} ->
            {error, Reason};
        {_, _, {error, Reason}} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#start_reading{reading_id = ReadingId, member_id = MemberId, book_id = BookId}) ->
    #{command_type => command_type(),
      reading_id => ReadingId,
      member_id => MemberId,
      book_id => BookId}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{reading_id := ReadingId, member_id := MemberId, book_id := BookId}) ->
    new(#{reading_id => ReadingId, member_id => MemberId, book_id => BookId});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the reading's own id.
-spec stream_id(t()) -> binary().
stream_id(#start_reading{reading_id = ReadingId}) ->
    ReadingId.

-spec get_reading_id(t()) -> binary().
get_reading_id(#start_reading{reading_id = ReadingId}) ->
    ReadingId.

-spec get_member_id(t()) -> binary().
get_member_id(#start_reading{member_id = MemberId}) ->
    MemberId.

-spec get_book_id(t()) -> binary().
get_book_id(#start_reading{book_id = BookId}) ->
    BookId.
