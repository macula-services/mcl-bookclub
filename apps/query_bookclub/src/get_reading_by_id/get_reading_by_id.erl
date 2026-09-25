%% @doc get_reading_by_id: the reading, by its stream id.
%%
%% A query desk is a pure module answered by the query store: no state, no
%% framework, no mesh.
-module(get_reading_by_id).

-export([find/1]).

%% @doc One reading, or not_found. The row's cells arrive in SELECT order; the
%% schema-contract test keeps that order aligned with the PRJ division's DDL.
-spec find(binary()) -> {ok, map()} | {error, term()}.
find(ReadingId) when is_binary(ReadingId) ->
    found(bookclub_query_store:q(
            "SELECT reading_id, member_id, book_id, status, started_at,"
            " pages_read, finished_at FROM readings WHERE reading_id = ?",
            [ReadingId]));
find(_) ->
    {error, missing_reading_id}.

found([[ReadingId, MemberId, BookId, Status, StartedAt, Pages, FinishedAt] | _]) ->
    {ok, #{reading_id => ReadingId,
           member_id => MemberId,
           book_id => BookId,
           status => Status,
           started_at => StartedAt,
           pages_read => Pages,
           finished_at => FinishedAt}};
found([]) ->
    {error, not_found};
found({error, Reason}) ->
    {error, {store_error, Reason}}.
