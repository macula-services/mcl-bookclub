%% @doc get_book_by_id: the book, by its stream id.
%%
%% A query desk is a pure module answered by the query store: no state, no
%% framework, no mesh. A retired book is still answerable by id, with its
%% status visible.
-module(get_book_by_id).

-export([find/1]).

%% @doc One book, or not_found. The row's cells arrive in SELECT order; the
%% schema-contract test keeps that order aligned with the PRJ division's DDL.
-spec find(binary()) -> {ok, map()} | {error, term()}.
find(BookId) when is_binary(BookId) ->
    found(bookclub_query_store:q(
            "SELECT book_id, club_id, title, author, status, procured_at FROM books WHERE book_id = ?",
            [BookId]));
find(_) ->
    {error, missing_book_id}.

found([[BookId, ClubId, Title, Author, Status, At] | _]) ->
    {ok, #{book_id => BookId,
           club_id => ClubId,
           title => Title,
           author => Author,
           status => Status,
           procured_at => At}};
found([]) ->
    {error, not_found};
found({error, Reason}) ->
    {error, {store_error, Reason}}.
