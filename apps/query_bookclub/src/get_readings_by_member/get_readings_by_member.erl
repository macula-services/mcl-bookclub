%% @doc get_readings_by_member: the readings of one member, oldest first.
%%
%% The field-query pattern (get_{aggregates}_by_{field}), deliberately not
%% a paged list: a member's reading history is small and ordered, and the
%% paged pattern arrives with the list desks. The clause is here, not
%% hidden in a shared helper.
-module(get_readings_by_member).

-export([find/1]).

%% @doc Every reading of one member, ordered by start time, as a list of
%% maps in the same shape get_reading_by_id returns. Empty for a member
%% with no readings.
-spec find(binary()) -> {ok, [map()]} | {error, term()}.
find(MemberId) when is_binary(MemberId) ->
    found(bookclub_query_store:q(
            "SELECT reading_id, member_id, book_id, status, started_at,"
            " pages_read, finished_at FROM readings"
            " WHERE member_id = ? ORDER BY started_at",
            [MemberId]));
find(_) ->
    {error, missing_member_id}.

found(Rows) when is_list(Rows) ->
    {ok, [to_map(Row) || Row <- Rows]};
found({error, Reason}) ->
    {error, {store_error, Reason}}.

to_map([ReadingId, MemberId, BookId, Status, StartedAt, Pages, FinishedAt]) ->
    #{reading_id => ReadingId,
      member_id => MemberId,
      book_id => BookId,
      status => Status,
      started_at => StartedAt,
      pages_read => Pages,
      finished_at => FinishedAt}.
