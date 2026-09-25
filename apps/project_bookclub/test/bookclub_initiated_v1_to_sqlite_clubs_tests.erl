%% @doc The whole released pipeline, end to end: dispatch against a real
%% reckon-db store, the $all subscription, the evoq router, the projection
%% handlers, and the sqlite rows they write.
%%
%% This is the suite that proves guides/event_delivery.md for the clubs
%% table: the projections are idempotent writes keyed on the stream id,
%% the rows carry the applied position (event_id, version), and a replay
%% changes nothing.
-module(bookclub_initiated_v1_to_sqlite_clubs_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun project_bookclub_test_env:start/0,
     fun project_bookclub_test_env:stop/1,
     [{timeout, 60, fun an_initiated_club_is_projected_to_sqlite/0},
      {timeout, 60, fun the_row_carries_the_applied_version_and_event_id/0},
      {timeout, 60, fun reapplying_the_same_event_changes_nothing/0},
      {timeout, 60, fun an_archived_club_moves_the_row_to_archived/0}]}.

schema_contract_test_() ->
    [fun the_query_columns_are_all_in_the_prj_schema/0,
     fun the_prj_division_imports_no_mesh_module/0,
     fun the_prj_division_writes_no_status_literal/0].

%% The Demon 68 boundary, as a mechanism: a readable-status literal
%% spelled out as a single-quoted SQL value ('active', 'archived',
%% 'on_shelf', 'retired', 'in_progress', 'finished', 'unregistered') in
%% any PRJ source is the relapse -- the projections must take each status
%% string from the CMD status module's flag map, never spell one out
%% here. Only the QUOTED forms count: the bare words legitimately appear
%% in event-type names ("book_retired_v1") and column names
%% ("finished_at"); a status VALUE is always a quoted literal. Comments
%% count too: naming the literal in prose is how the drift starts.
the_prj_division_writes_no_status_literal() ->
    lists:foreach(
      fun(Src) ->
              {ok, Text} = file:read_file(Src),
              lists:foreach(
                fun(Literal) ->
                        ?assertEqual(nomatch, binary:match(Text, Literal),
                                     {status_literal_in_prj_source, Literal, Src})
                end,
                [<<"'active'">>, <<"\"active\"">>, <<"'archived'">>,
                 <<"'on_shelf'">>, <<"'retired'">>, <<"'in_progress'">>,
                 <<"'finished'">>, <<"'unregistered'">>])
      end, project_bookclub_test_env:erl_sources(
             project_bookclub_test_env:repo_file("apps/project_bookclub/src"))).

an_initiated_club_is_projected_to_sqlite() ->
    {ok, Cmd} = club(<<"The Crooked Shelf">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    [ClubId, <<"The Crooked Shelf">>, <<"active">>, <<"bea">>, At, _EventId, 0] =
        project_bookclub_test_env:await_row(
          "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
          " FROM clubs WHERE club_id = ?", [ClubId], 100),
    ?assert(is_integer(At)).

%% The row IS the applied position: the event_id and stream version of the
%% event that last wrote it, saved with the projected data in one statement.
%% The stored event is the authority; the row mirrors it.
the_row_carries_the_applied_version_and_event_id() ->
    {ok, Cmd} = club(<<"Versioned">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(ClubId)),
    [ClubId, <<"Versioned">>, <<"active">>, <<"bea">>, _At, EventId, 0] =
        project_bookclub_test_env:await_row(
          "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
          " FROM clubs WHERE club_id = ?", [ClubId], 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(0, Stored#event.version).

%% Idempotency lives in the write, not in checkpoint arithmetic: re-applying
%% the stored envelope -- what a replay does -- writes the same row again,
%% and it is still ONE row.
reapplying_the_same_event_changes_nothing() ->
    {ok, Cmd} = club(<<"Replayed">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    project_bookclub_test_env:await_row(
      "SELECT club_id FROM clubs WHERE club_id = ?", [ClubId], 100),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(ClubId)),
    Envelope = #{event_type => <<"bookclub_initiated_v1">>,
                 event_id => Stored#event.event_id,
                 version => Stored#event.version,
                 data => Stored#event.data},
    {ok, #{}} = bookclub_initiated_v1_to_sqlite_clubs:handle_event(
                   <<"bookclub_initiated_v1">>, Envelope, #{}, #{}),
    [[1]] = bookclub_read_model_store:q(
              "SELECT COUNT(*) FROM clubs WHERE club_id = ?", [ClubId]).

%% The two projections feed the same table in stream order: the archived
%% event rewrites the row with the archived status and the NEW applied
%% position (its own event id and version 1), all from its own payload --
%% the initiated event never needs to have been seen.
an_archived_club_moves_the_row_to_archived() ->
    {ok, Cmd} = club(<<"To Be Archived">>),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ClubId = initiate_bookclub_v1:stream_id(Cmd),
    project_bookclub_test_env:await_row(
      "SELECT club_id FROM clubs WHERE club_id = ?", [ClubId], 100),
    {ok, ArchiveCmd} = archive_bookclub_v1:new(#{club_id => ClubId,
                                                archived_by => <<"raf">>}),
    {ok, 1, _} = maybe_archive_bookclub:dispatch(ArchiveCmd),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(ClubId)),
    [ClubId, <<"To Be Archived">>, <<"archived">>, <<"bea">>, _At, EventId, 1] =
        project_bookclub_test_env:await_row(
          "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
          " FROM clubs WHERE club_id = ?", [ClubId], 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(<<"bookclub_archived_v1">>, Stored#event.event_type).

%% THE SCHEMA CONTRACT, AS A MECHANISM, over every query desk. The QRY
%% division selects columns the PRJ division declares; the only copy of the
%% truth is bookclub_read_model_store:schema/0. This parses each desk's
%% SELECT, extracts its columns AND its table, and refuses any column the
%% matching CREATE TABLE does not declare -- including a `SELECT *'.
%% (Column names are matched within the table's own DDL, so a name in one
%% table cannot mask a missing one in another.)
the_query_columns_are_all_in_the_prj_schema() ->
    Schema = iolist_to_binary(lists:join(" ", bookclub_read_model_store:schema())),
    lists:foreach(
      fun(Src) ->
              {ok, Text} = file:read_file(Src),
              lists:foreach(fun(Select) -> assert_select(Schema, Select, Src) end,
                            selects(Text))
      end, project_bookclub_test_env:erl_sources(
             project_bookclub_test_env:repo_file("apps/query_bookclub/src"))).

assert_select(Schema, [Columns, Table], Src) ->
    TableDdl = table_ddl(Schema, Table),
    lists:foreach(
      fun(Col) ->
              ?assertNotEqual(nomatch, binary:match(TableDdl, Col),
                              {column_missing_from_prj_schema, Col, Table, Src})
      end,
      [string:trim(C) || C <- binary:split(Columns, <<",">>, [global])]).

selects(Text) ->
    case re:run(Text, "SELECT\\s+(.+?)\\s+FROM\\s+([a-z_]+)",
                [global, {capture, all_but_first, binary}]) of
        {match, Captures} -> Captures;
        nomatch -> []
    end.

table_ddl(Schema, Table) ->
    case re:run(Schema, "CREATE TABLE[^(]*" ++ binary_to_list(Table) ++ "\\s*\\(.*?\\)",
                [{capture, first, binary}, dotall]) of
        {match, [Ddl]} -> Ddl;
        nomatch -> <<>>
    end.

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
                end, project_bookclub_test_env:erl_sources(
                       project_bookclub_test_env:repo_file("apps/project_bookclub/src")))
      end,
      [<<"macula">>, <<"mcl_om">>]).

%%============================================================================
%% Helpers
%%============================================================================

club(Name) ->
    initiate_bookclub_v1:new(#{club_id => initiate_bookclub_v1:mint_club_id(),
                               name => Name,
                               initiated_by => <<"bea">>}).
