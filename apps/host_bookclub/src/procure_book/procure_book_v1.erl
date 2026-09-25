%% @doc The procure_book_v1 command: the club acquires a book for its shelf.
%%
%% `procure', the business verb for acquisition -- never add. The command
%% names the book's stream id (minted), the club, and the bibliographic
%% facts.
-module(procure_book_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([mint_book_id/0, stream_id/1, get_book_id/1, get_club_id/1,
         get_title/1, get_author/1]).

-record(procure_book, {
    book_id :: binary(),
    club_id :: binary(),
    title :: binary(),
    author :: binary()
}).

-opaque t() :: #procure_book{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> procure_book_v1.

%% @doc Mint the book's stream id. The AggregateId IS the reckon stream id
%% (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the title goes in the payload and this
%% derived id is what the command is addressed to.
-spec mint_book_id() -> binary().
mint_book_id() ->
    reckon_gater_stream_id:new(<<"book">>).

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{book_id := BookId, club_id := ClubId, title := Title, author := Author}) ->
    record_when(is_binary(BookId), BookId =/= <<>>,
                is_binary(ClubId), ClubId =/= <<>>,
                is_binary(Title), Title =/= <<>>,
                is_binary(Author), Author =/= <<>>,
                BookId, ClubId, Title, Author);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, true, true, true, true,
            BookId, ClubId, Title, Author) ->
    {ok, #procure_book{book_id = BookId, club_id = ClubId,
                       title = Title, author = Author}};
record_when(_, _, _, _, _, _, _, _, _, _, _, _) ->
    {error, invalid_params}.

-spec validate(t()) -> ok | {error, term()}.
validate(#procure_book{book_id = BookId, club_id = ClubId}) ->
    case {reckon_gater_stream_id:validate(BookId),
          reckon_gater_stream_id:validate(ClubId)} of
        {ok, ok} ->
            ok;
        {{error, Reason}, _} ->
            {error, Reason};
        {_, {error, Reason}} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#procure_book{book_id = BookId, club_id = ClubId,
                     title = Title, author = Author}) ->
    #{command_type => command_type(),
      book_id => BookId,
      club_id => ClubId,
      title => Title,
      author => Author}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{book_id := BookId, club_id := ClubId, title := Title, author := Author}) ->
    new(#{book_id => BookId, club_id => ClubId, title => Title, author => Author});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the book's own id.
-spec stream_id(t()) -> binary().
stream_id(#procure_book{book_id = BookId}) ->
    BookId.

-spec get_book_id(t()) -> binary().
get_book_id(#procure_book{book_id = BookId}) ->
    BookId.

-spec get_club_id(t()) -> binary().
get_club_id(#procure_book{club_id = ClubId}) ->
    ClubId.

-spec get_title(t()) -> binary().
get_title(#procure_book{title = Title}) ->
    Title.

-spec get_author(t()) -> binary().
get_author(#procure_book{author = Author}) ->
    Author.
