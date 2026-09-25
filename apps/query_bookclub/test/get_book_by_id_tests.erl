%% @doc get_book_by_id, against the sqlite read model.
%%
%% The test opens the same file the PRJ division writes and creates the
%% schema from bookclub_read_model_store:schema/0 -- it STANDS IN for the
%% PRJ division having run, it does not duplicate the DDL.
-module(get_book_by_id_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun start_store/0,
     fun stop_store/1,
     [fun a_known_book_is_found/0,
      fun an_unknown_book_is_not_found/0,
      fun a_retired_book_is_found_with_its_status/0,
      fun a_non_binary_id_is_refused/0]}.

a_known_book_is_found() ->
    BookId = seed_book(<<"Project Hail Mary">>, <<"on_shelf">>),
    {ok, Book} = get_book_by_id:find(BookId),
    ?assertEqual(#{book_id => BookId,
                   club_id => <<"bookclub-", (binary:copy(<<"c">>, 32))/binary>>,
                   title => <<"Project Hail Mary">>,
                   author => <<"Andy Weir">>,
                   status => <<"on_shelf">>,
                   procured_at => 42}, Book).

an_unknown_book_is_not_found() ->
    ?assertEqual({error, not_found},
                 get_book_by_id:find(<<"book-", (binary:copy(<<"b">>, 32))/binary>>)).

%% A retired book is still answerable by id, with its status visible.
%% Hiding happens in the paged list desks, not the by-id lookup.
a_retired_book_is_found_with_its_status() ->
    BookId = seed_book(<<"The Moon Is a Harsh Mistress">>, <<"retired">>),
    {ok, Book} = get_book_by_id:find(BookId),
    ?assertEqual(<<"retired">>, maps:get(status, Book)).

a_non_binary_id_is_refused() ->
    ?assertEqual({error, missing_book_id}, get_book_by_id:find("project-hail-mary")).

%%============================================================================
%% Helpers
%%============================================================================

seed_book(Title, Status) ->
    BookId = list_to_binary(
               io_lib:format("book-~32.16.0b", [erlang:unique_integer([positive])])),
    Sql = "INSERT INTO books (book_id, club_id, title, author, status,"
          " procured_at, event_id, version)"
          " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    {ok, Conn} = esqlite3:open(filename:join(data_dir(), "bookclub.sqlite3")),
    ok = run_insert(Conn, Sql,
                    [BookId, <<"bookclub-", (binary:copy(<<"c">>, 32))/binary>>,
                     Title, <<"Andy Weir">>, Status, 42, <<"evt-1">>, 0]),
    BookId.

run_insert(Conn, Sql, Args) ->
    {ok, Stmt} = esqlite3:prepare(Conn, Sql),
    ok = esqlite3:bind(Stmt, Args),
    '$done' = esqlite3:step(Stmt),
    ok.

start_store() ->
    Dir = filename:join(["/tmp", "get_book_by_id_tests",
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
