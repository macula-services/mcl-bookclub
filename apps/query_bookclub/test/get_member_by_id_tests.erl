%% @doc get_member_by_id, against the sqlite read model.
%%
%% The test opens the same file the PRJ division writes and creates the
%% schema from bookclub_read_model_store:schema/0 -- it STANDS IN for the
%% PRJ division having run, it does not duplicate the DDL.
-module(get_member_by_id_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun start_store/0,
     fun stop_store/1,
     [fun a_known_member_is_found/0,
      fun an_unknown_member_is_not_found/0,
      fun an_unregistered_member_is_found_with_its_status/0,
      fun a_non_binary_id_is_refused/0]}.

a_known_member_is_found() ->
    MemberId = seed_member(<<"Bea">>, <<"active">>),
    {ok, Member} = get_member_by_id:find(MemberId),
    ?assertEqual(#{member_id => MemberId,
                   club_id => <<"bookclub-", (binary:copy(<<"c">>, 32))/binary>>,
                   name => <<"Bea">>,
                   status => <<"active">>,
                   registered_at => 42}, Member).

an_unknown_member_is_not_found() ->
    ?assertEqual({error, not_found},
                 get_member_by_id:find(<<"member-", (binary:copy(<<"b">>, 32))/binary>>)).

%% An unregistered member is still answerable by id, with its status
%% visible. Hiding happens in the paged list desks, not the by-id lookup.
an_unregistered_member_is_found_with_its_status() ->
    MemberId = seed_member(<<"Gone">>, <<"unregistered">>),
    {ok, Member} = get_member_by_id:find(MemberId),
    ?assertEqual(<<"unregistered">>, maps:get(status, Member)).

a_non_binary_id_is_refused() ->
    ?assertEqual({error, missing_member_id}, get_member_by_id:find("bea-the-member")).

%%============================================================================
%% Helpers
%%============================================================================

seed_member(Name, Status) ->
    MemberId = list_to_binary(
                 io_lib:format("member-~32.16.0b", [erlang:unique_integer([positive])])),
    Sql = "INSERT INTO members (member_id, club_id, name, status,"
          " registered_at, event_id, version)"
          " VALUES (?, ?, ?, ?, ?, ?, ?)",
    {ok, Conn} = esqlite3:open(filename:join(data_dir(), "bookclub.sqlite3")),
    ok = run_insert(Conn, Sql,
                    [MemberId, <<"bookclub-", (binary:copy(<<"c">>, 32))/binary>>,
                     Name, Status, 42, <<"evt-1">>, 0]),
    MemberId.

run_insert(Conn, Sql, Args) ->
    {ok, Stmt} = esqlite3:prepare(Conn, Sql),
    ok = esqlite3:bind(Stmt, Args),
    '$done' = esqlite3:step(Stmt),
    ok.

start_store() ->
    Dir = filename:join(["/tmp", "get_member_by_id_tests",
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
