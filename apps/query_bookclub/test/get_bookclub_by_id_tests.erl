%% @doc get_bookclub_by_id, against the sqlite read model.
%%
%% The test opens the same file the PRJ division writes, creates the schema
%% from bookclub_read_model_store:schema/0 -- the test STANDS IN for the PRJ
%% division having run, it does not duplicate the DDL -- and seeds one row.
-module(get_bookclub_by_id_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun start_store/0,
     fun stop_store/1,
     [fun a_known_club_is_found/0,
      fun an_unknown_club_is_not_found/0,
      fun an_archived_club_is_found_with_its_status/0,
      fun a_non_binary_id_is_refused/0]}.

division_boundary_test_() ->
    [fun the_qry_division_imports_no_framework_or_mesh_module/0].

a_known_club_is_found() ->
    ClubId = seed_club(<<"The Crooked Shelf">>),
    {ok, Club} = get_bookclub_by_id:find(ClubId),
    ?assertEqual(#{club_id => ClubId,
                   name => <<"The Crooked Shelf">>,
                   status => <<"active">>,
                   initiated_by => <<"bea">>,
                   initiated_at => 42}, Club).

an_unknown_club_is_not_found() ->
    ?assertEqual({error, not_found},
                 get_bookclub_by_id:find(<<"bookclub-", (binary:copy(<<"b">>, 32))/binary>>)).

%% An archived club is still answerable by id, with its status visible. The
%% HIDING of archived clubs happens in the paged list desks (a later slice),
%% not in the by-id lookup -- by-id says the truth about one stream.
an_archived_club_is_found_with_its_status() ->
    ClubId = seed_club(<<"Archived Shelf">>, <<"archived">>),
    {ok, Club} = get_bookclub_by_id:find(ClubId),
    ?assertEqual(<<"archived">>, maps:get(status, Club)),
    ?assertEqual(<<"Archived Shelf">>, maps:get(name, Club)).

a_non_binary_id_is_refused() ->
    ?assertEqual({error, missing_club_id}, get_bookclub_by_id:find("the-crooked-shelf")).

%% The division boundary, as a mechanism rather than a convention: the QRY
%% sources must not name a framework, a store or a mesh module. Comments
%% count -- naming the thing in prose is how the drift starts.
the_qry_division_imports_no_framework_or_mesh_module() ->
    lists:foreach(
      fun(Forbidden) ->
              lists:foreach(
                fun(Src) ->
                        {ok, Text} = file:read_file(Src),
                        ?assertEqual(nomatch, binary:match(Text, Forbidden),
                                     {forbidden_reference, Forbidden, Src})
                end, erl_sources(repo_file("apps/query_bookclub/src")))
      end,
      [<<"evoq">>, <<"macula">>, <<"mcl_om">>, <<"reckon">>]).

%%============================================================================
%% Helpers
%%============================================================================

seed_club(Name) ->
    seed_club(Name, <<"active">>).

seed_club(Name, Status) ->
    %% A fresh stream id per call: the clubs table persists across this
    %% suite's tests, and the PK is the stream id.
    ClubId = list_to_binary(
               io_lib:format("bookclub-~32.16.0b", [erlang:unique_integer([positive])])),
    Sql = "INSERT INTO clubs (club_id, name, status, initiated_by,"
          " initiated_at, event_id, version)"
          " VALUES (?, ?, ?, ?, ?, ?, ?)",
    {ok, Conn} = esqlite3:open(filename:join(data_dir(), "bookclub.sqlite3")),
    ok = run_insert(Conn, Sql,
                    [ClubId, Name, Status, <<"bea">>, 42, <<"evt-1">>, 0]),
    ClubId.

run_insert(Conn, Sql, Args) ->
    {ok, Stmt} = esqlite3:prepare(Conn, Sql),
    ok = esqlite3:bind(Stmt, Args),
    '$done' = esqlite3:step(Stmt),
    ok.

start_store() ->
    Dir = filename:join(["/tmp", "get_bookclub_by_id_tests",
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

erl_sources(Dir) ->
    {ok, Entries} = file:list_dir(Dir),
    lists:flatmap(
      fun(Entry) ->
              Path = filename:join(Dir, Entry),
              case filelib:is_dir(Path) of
                  true -> erl_sources(Path);
                  false ->
                      case filename:extension(Path) of
                          ".erl" -> [Path];
                          _ -> []
                      end
              end
      end, Entries).

%% Relative to the beam rather than the working directory, because eunit runs
%% from wherever the developer happens to be standing.
repo_file(Rel) -> climb(filename:dirname(code:which(?MODULE)), Rel, 8).

climb(_Dir, Rel, 0) -> Rel;
climb(Dir, Rel, Left) ->
    Candidate = filename:join(Dir, Rel),
    found(filelib:is_regular(Candidate), Candidate, Dir, Rel, Left).

found(true, Candidate, _Dir, _Rel, _Left) -> Candidate;
found(false, _Candidate, Dir, Rel, Left) ->
    climb(filename:dirname(Dir), Rel, Left - 1).
