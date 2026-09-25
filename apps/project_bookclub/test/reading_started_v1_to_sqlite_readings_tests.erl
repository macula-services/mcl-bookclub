%% @doc The reading projections, end to end: the fold across two events
%% lands in one readings row, each write self-contained and idempotent.
-module(reading_started_v1_to_sqlite_readings_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(SELECT,
        "SELECT reading_id, member_id, book_id, status, started_at,"
        " pages_read, finished_at, event_id, version"
        " FROM readings WHERE reading_id = ?").

store_test_() ->
    {setup,
     fun project_bookclub_test_env:start/0,
     fun project_bookclub_test_env:stop/1,
     [{timeout, 60, fun a_started_reading_is_projected/0},
      {timeout, 60, fun a_finished_reading_folds_the_row/0}]}.

a_started_reading_is_projected() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, Cmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                       member_id => MemberId,
                                       book_id => BookId}),
    {ok, 0, _} = maybe_start_reading:dispatch(Cmd),
    [ReadingId, MemberId, BookId, <<"in_progress">>, StartedAt, 0, undefined,
     _EventId, 0] =
        project_bookclub_test_env:await_row(?SELECT, [ReadingId], 100),
    ?assert(is_integer(StartedAt)).

%% The finished event folds the row from its own payload: status flips,
%% pages and finish time land, and the applied position moves to the NEW
%% event -- the started event never needs to have been seen.
a_finished_reading_folds_the_row() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, StartCmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                            member_id => MemberId,
                                            book_id => BookId}),
    {ok, 0, _} = maybe_start_reading:dispatch(StartCmd),
    project_bookclub_test_env:await_row(?SELECT, [ReadingId], 100),
    {ok, FinishCmd} = finish_reading_v1:new(#{reading_id => ReadingId,
                                              pages_read => 476}),
    {ok, 1, _} = maybe_finish_reading:dispatch(FinishCmd),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(ReadingId)),
    [ReadingId, MemberId, BookId, <<"finished">>, _StartedAt, 476, FinishedAt,
     EventId, 1] =
        project_bookclub_test_env:await_row(?SELECT, [ReadingId], 100),
    ?assert(is_integer(FinishedAt)),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(<<"reading_finished_v1">>, Stored#event.event_type).

%%============================================================================
%% Helpers
%%============================================================================

reading_ids() ->
    {ok, start_reading_v1:mint_reading_id(),
     register_member_v1:mint_member_id(),
     procure_book_v1:mint_book_id()}.
