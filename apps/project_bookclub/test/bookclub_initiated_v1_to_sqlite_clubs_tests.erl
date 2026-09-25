%% @doc The whole released pipeline, end to end: dispatch against a real
%% reckon-db store, the $all subscription, the evoq router, the projection
%% handler, and the sqlite row it writes.
%%
%% This is the suite that proves guides/event_delivery.md: the projection is
%% an idempotent write keyed on the stream id, the row carries the applied
%% position (event_id, version), and a replay changes nothing.
-module(bookclub_initiated_v1_to_sqlite_clubs_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(STORE, mcl_bookclub_store).

store_test_() ->
    {setup,
     fun start_everything/0,
     fun stop_everything/1,
     [{timeout, 60, fun an_initiated_club_is_projected_to_sqlite/0},
      {timeout, 60, fun the_row_carries_the_applied_version_and_event_id/0},
      {timeout, 60, fun reapplying_the_same_event_changes_nothing/0},
      {timeout, 60, fun an_archived_club_moves_the_row_to_archived/0}]}.

schema_contract_test_() ->
    [fun the_query_columns_are_all_in_the_prj_schema/0,
     fun the_prj_division_imports_no_mesh_module/0].

an_initiated_club_is_projected_to_sqlite() ->
    {ok, Cmd} = club(<<"The Crooked Shelf">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    [ClubId, <<"The Crooked Shelf">>, <<"active">>, <<"bea">>, At, _EventId, 0] =
        await_row(ClubId, 100),
    ?assert(is_integer(At)).

%% The row IS the applied position: the event_id and stream version of the
%% event that last wrote it, saved with the projected data in one statement.
%% The stored event is the authority; the row mirrors it.
the_row_carries_the_applied_version_and_event_id() ->
    {ok, Cmd} = club(<<"Versioned">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    [Stored | _] = lists:reverse(stream(ClubId)),
    [ClubId, <<"Versioned">>, <<"active">>, <<"bea">>, _At, EventId, 0] =
        await_row(ClubId, 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(0, Stored#event.version).

%% Idempotency lives in the write, not in checkpoint arithmetic: re-applying
%% the stored envelope -- what a replay does -- writes the same row again,
%% and it is still ONE row.
reapplying_the_same_event_changes_nothing() ->
    {ok, Cmd} = club(<<"Replayed">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    await_row(ClubId, 100),
    [Stored | _] = lists:reverse(stream(ClubId)),
    Envelope = #{event_type => <<"bookclub_initiated_v1">>,
                 event_id => Stored#event.event_id,
                 version => Stored#event.version,
                 data => Stored#event.data},
    {ok, #{}} = bookclub_initiated_v1_to_sqlite_clubs:handle_event(
                   <<"bookclub_initiated_v1">>, Envelope, #{}, #{}),
    [[1]] = bookclub_read_model_store:q(
              "SELECT COUNT(*) FROM clubs WHERE club_id = ?", [ClubId]).

%% THE SCHEMA CONTRACT, AS A MECHANISM. The QRY division selects columns the
%% PRJ division declares; the only copy of the truth is bookclub_read_model_store:schema/0.
%% This parses the query desk's SELECT, extracts its columns, and refuses any
%% of them that the schema does not declare -- including a `SELECT *'.
the_query_columns_are_all_in_the_prj_schema() ->
    {ok, Source} = file:read_file(repo_file("apps/query_bookclub/src/get_bookclub_by_id/get_bookclub_by_id.erl")),
    {match, [Columns]} = re:run(Source, "SELECT\\s+(.+?)\\s+FROM\\s+clubs",
                                [{capture, all_but_first, binary}]),
    Schema = iolist_to_binary(lists:join(" ", bookclub_read_model_store:schema())),
    lists:foreach(
      fun(Col) ->
              ?assertNotEqual(nomatch, binary:match(Schema, Col),
                              {column_missing_from_prj_schema, Col})
      end,
      [string:trim(C) || C <- binary:split(Columns, <<",">>, [global])]).

%% The division boundary, as a mechanism rather than a convention: the PRJ
%% sources must not name a mesh module. Comments count.
the_prj_division_imports_no_mesh_module() ->
    lists:foreach(
      fun(Forbidden) ->
              lists:foreach(
                fun(Src) ->
                        {ok, Text} = file:read_file(Src),
                        ?assertEqual(nomatch, binary:match(Text, Forbidden),
                                     {forbidden_reference, Forbidden, Src})
                end, erl_sources(repo_file("apps/project_bookclub/src")))
      end,
      [<<"macula">>, <<"mcl_om">>]).

%% The two projections feed the same table in stream order: the archived
%% event rewrites the row with the archived status and the NEW applied
%% position (its own event id and version 1), all from its own payload --
%% the initiated event never needs to have been seen.
an_archived_club_moves_the_row_to_archived() ->
    {ok, Cmd} = club(<<"To Be Archived">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    await_row(ClubId, 100),
    {ok, ArchiveCmd} = archive_bookclub_v1:new(#{club_id => ClubId,
                                                archived_by => <<"raf">>}),
    {ok, 1, _} = maybe_archive_bookclub:dispatch(ArchiveCmd),
    [Stored | _] = lists:reverse(stream(ClubId)),
    [ClubId, <<"To Be Archived">>, <<"archived">>, <<"bea">>, _At, EventId, 1] =
        await_row(ClubId, 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(<<"bookclub_archived_v1">>, Stored#event.event_type).

%%============================================================================
%% Helpers
%%============================================================================

club(Name) ->
    initiate_bookclub_v1:new(#{club_id => initiate_bookclub_v1:mint_club_id(),
                               name => Name,
                               initiated_by => <<"bea">>}).

stream(ClubId) ->
    events(reckon_db_streams:read(?STORE, ClubId, 0, 1000, forward)).

events({ok, Events}) -> Events;
events({error, {stream_not_found, _}}) -> [];
events({error, _} = Error) -> error(Error).

await_row(_ClubId, 0) -> error(not_projected);
await_row(ClubId, Tries) ->
    case bookclub_read_model_store:q(
           "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
           " FROM clubs WHERE club_id = ?", [ClubId]) of
        [Row | _] -> Row;
        [] -> timer:sleep(100), await_row(ClubId, Tries - 1);
        {error, Reason} -> error({store_error, Reason})
    end.

start_everything() ->
    Dir = filename:join(["/tmp", "bookclub_projection_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    %% evoq may already be loaded in the eunit VM; either way it must accept
    %% the env below.
    load_app(evoq),
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, ?STORE}]],
    os:putenv("MCL_DATA_DIR", Dir),
    {ok, Started} = application:ensure_all_started(
                      [reckon_db, evoq, reckon_evoq, esqlite, project_bookclub]),
    {ok, _} = reckon_db_sup:start_store(#store_config{store_id = ?STORE,
                                                      data_dir = filename:join(Dir, "store"),
                                                      mode = single}),
    {ok, Sub} = evoq_store_subscription:start_link(?STORE),
    unlink(Sub),
    {Dir, Started, Sub}.

stop_everything({Dir, Started, Sub}) ->
    exit(Sub, shutdown),
    [application:stop(App) || App <- lists:reverse(Started)],
    os:unsetenv("MCL_DATA_DIR"),
    file:del_dir_r(Dir).

load_app(App) ->
    case application:load(App) of
        ok -> ok;
        {error, {already_loaded, App}} -> ok
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
