%% @doc get_reading_by_id and get_readings_by_member, against the sqlite
%% read model.
%%
%% The test opens the same file the PRJ division writes and creates the
%% schema from bookclub_read_model_store:schema/0 -- it STANDS IN for the
%% PRJ division having run, it does not duplicate the DDL.
-module(get_reading_by_id_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun start_store/0,
     fun stop_store/1,
     [fun a_known_reading_is_found/0,
      fun an_unknown_reading_is_not_found/0,
      fun a_members_readings_come_back_oldest_first/0,
      fun a_member_without_readings_gets_none/0,
      fun a_non_binary_id_is_refused/0]}.

a_known_reading_is_found() ->
    {ReadingId, MemberId} = seed_reading(<<"in_progress">>, 0, null),
    {ok, Reading} = get_reading_by_id:find(ReadingId),
    ?assertEqual(#{reading_id => ReadingId,
                   member_id => MemberId,
                   book_id => <<"book-", (binary:copy(<<"c">>, 32))/binary>>,
                   status => <<"in_progress">>,
                   started_at => 42,
                   pages_read => 0,
                   finished_at => undefined}, Reading).

an_unknown_reading_is_not_found() ->
    ?assertEqual({error, not_found},
                 get_reading_by_id:find(<<"reading-", (binary:copy(<<"b">>, 32))/binary>>)).

a_members_readings_come_back_oldest_first() ->
    MemberId = list_to_binary(
                 io_lib:format("member-~32.16.0b", [erlang:unique_integer([positive])])),
    {R1, _} = seed_reading_for(MemberId, <<"finished">>, 476, 51, 100),
    {R2, _} = seed_reading_for(MemberId, <<"finished">>, 320, 52, 101),
    {ok, Readings} = get_readings_by_member:find(MemberId),
    ?assertEqual([R1, R2], [maps:get(reading_id, R) || R <- Readings]),
    ?assertEqual([476, 320], [maps:get(pages_read, R) || R <- Readings]).

a_member_without_readings_gets_none() ->
    MemberId = list_to_binary(
                 io_lib:format("member-~32.16.0b", [erlang:unique_integer([positive])])),
    ?assertEqual({ok, []}, get_readings_by_member:find(MemberId)).

a_non_binary_id_is_refused() ->
    ?assertEqual({error, missing_reading_id}, get_reading_by_id:find("the-reading")),
    ?assertEqual({error, missing_member_id}, get_readings_by_member:find("bea")).

%%============================================================================
%% Helpers
%%============================================================================

seed_reading(Status, Pages, FinishedAt) ->
    MemberId = list_to_binary(
                 io_lib:format("member-~32.16.0b", [erlang:unique_integer([positive])])),
    seed_reading_for(MemberId, Status, Pages, FinishedAt, 42).

seed_reading_for(MemberId, Status, Pages, FinishedAt, StartedAt) ->
    ReadingId = list_to_binary(
                  io_lib:format("reading-~32.16.0b", [erlang:unique_integer([positive])])),
    Sql = "INSERT INTO readings (reading_id, member_id, book_id, status,"
          " started_at, pages_read, finished_at, event_id, version)"
          " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    {ok, Conn} = esqlite3:open(filename:join(data_dir(), "bookclub.sqlite3")),
    ok = run_insert(Conn, Sql,
                    [ReadingId, MemberId, <<"book-", (binary:copy(<<"c">>, 32))/binary>>,
                     Status, StartedAt, Pages, FinishedAt, <<"evt-1">>, 0]),
    {ReadingId, MemberId}.

run_insert(Conn, Sql, Args) ->
    {ok, Stmt} = esqlite3:prepare(Conn, Sql),
    ok = esqlite3:bind(Stmt, Args),
    '$done' = esqlite3:step(Stmt),
    ok.

start_store() ->
    Dir = filename:join(["/tmp", "get_reading_by_id_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    {ok, Conn} = esqlite3:open(filename:join(Dir, "bookclub.sqlite3")),
    [ok = esqlite3:exec(Conn, Sql) || Sql <- bookclub_read_model_store:schema()],
    os:putenv("MCL_DATA_DIR", Dir),
    {ok, Started} = application:ensure_all_started([esqlite, query_bookclub]),
    {Dir, Conn, Started}.

stop_store({Dir, Conn, Started}) ->
    [application:stop(App) || App <- lists:reverse(Started)],
    os:unsetenv("MCL_DATA_DIR"),
    esqlite3:close(Conn),
    file:del_dir_r(Dir).

data_dir() ->
    case os:getenv("MCL_DATA_DIR") of
        false -> "/tmp/mcl_bookclub";
        "" -> "/tmp/mcl_bookclub";
        Path -> Path
    end.
