%% @doc The retire_book_v1 command: soft-delete the book.
%%
%% `retire', the shelf-domain verb for a book leaving the shelf -- never
%% delete. Everything else the retired event needs comes from the aggregate
%% state, echoed into the event.
-module(retire_book_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([stream_id/1, get_book_id/1, get_retired_by/1]).

-record(retire_book, {
    book_id :: binary(),
    retired_by :: binary()
}).

-opaque t() :: #retire_book{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> retire_book_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{book_id := BookId, retired_by := By}) ->
    record_when(is_binary(BookId), BookId =/= <<>>,
                is_binary(By), By =/= <<>>,
                BookId, By);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, BookId, By) ->
    {ok, #retire_book{book_id = BookId, retired_by = By}};
record_when(_, _, _, _, _, _) ->
    {error, invalid_params}.

-spec validate(t()) -> ok | {error, term()}.
validate(#retire_book{book_id = BookId}) ->
    case reckon_gater_stream_id:validate(BookId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#retire_book{book_id = BookId, retired_by = By}) ->
    #{command_type => command_type(),
      book_id => BookId,
      retired_by => By}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{book_id := BookId, retired_by := By}) ->
    new(#{book_id => BookId, retired_by => By});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the book's own id.
-spec stream_id(t()) -> binary().
stream_id(#retire_book{book_id = BookId}) ->
    BookId.

-spec get_book_id(t()) -> binary().
get_book_id(#retire_book{book_id = BookId}) ->
    BookId.

-spec get_retired_by(t()) -> binary().
get_retired_by(#retire_book{retired_by = By}) ->
    By.
