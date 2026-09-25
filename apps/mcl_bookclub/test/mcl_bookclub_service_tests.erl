%% @doc The service contract, asserted locally.
%%
%% mcl_om resolves its six callbacks BY NAME at startup, on a live node, so a
%% service that forgets one dies with `undef' where nobody is watching. The
%% primary defence is the `-behaviour(mcl_om_service)' attribute on the
%% service module, which turns a missing callback into a compile error under
%% warnings_as_errors.
%%
%% What this suite adds is everything the compiler cannot see: that the
%% attribute has not been quietly dropped, that the values inside those
%% callbacks are the shapes mcl_om will destructure, that the names and
%% version this service reports are the ones it actually has, and that the
%% boundaries the four apps share (the store id, the sqlite path, the runtime
%% pin) agree on both sides. Nothing local boots mcl_om, so asserting the
%% shape by hand is the closest available thing to a rehearsal.
-module(mcl_bookclub_service_tests).

-include_lib("eunit/include/eunit.hrl").

-define(APP, mcl_bookclub).
-define(SERVICE, mcl_bookclub_service).

%% Belt and braces with the behaviour attribute, and it survives the attribute
%% being removed. If mcl_om ever adds a SEVENTH required callback this test
%% keeps passing and the deploy still breaks, which is the honest limit of a
%% local assertion about a remote contract.
exports_every_required_callback_test() ->
    _ = code:ensure_loaded(?SERVICE),
    Required = [{info, 0}, {start, 1}, {stop, 1},
                {health, 0}, {capabilities, 0}, {identity_spec, 0}],
    Missing = [F || {N, A} = F <- Required,
                    not erlang:function_exported(?SERVICE, N, A)],
    ?assertEqual([], Missing).

info_carries_the_three_keys_test() ->
    #{name := Name, version := Vsn, description := Desc} = ?SERVICE:info(),
    ?assert(is_binary(Name)),
    ?assert(is_binary(Vsn)),
    ?assert(is_binary(Desc)),
    ?assertEqual(<<"mcl-bookclub">>, Name).

%% THE TWO NAMES MUST AGREE. The OTP application is snake_case because it is an
%% Erlang atom; the repository, the container image and the name this service
%% answers to on the mesh are kebab-case. They describe one service.
mesh_name_matches_the_application_test() ->
    #{name := Wire} = ?SERVICE:info(),
    Snake = atom_to_binary(?APP, utf8),
    ?assertEqual(binary:replace(Snake, <<"_">>, <<"-">>, [global]), Wire).

%% The version in info/0 is what a peer reads off /health, so it disagreeing
%% with the application it describes is a lie that nothing else would catch.
info_version_matches_the_application_test() ->
    _ = application:load(?APP),
    {ok, Vsn} = application:get_key(?APP, vsn),
    #{version := Reported} = ?SERVICE:info(),
    ?assertEqual(list_to_binary(Vsn), Reported).

%% The service's health IS the health of its read path: degraded until the
%% division stores are up, ok with them. One test, in that order, so the
%% assertion never depends on another test's leftovers.
health_probes_the_division_stores_test() ->
    ?assertMatch({degraded, _}, ?SERVICE:health()),
    DataDir = tmp_dir(),
    os:putenv("MCL_DATA_DIR", DataDir),
    try
        {ok, Started} = application:ensure_all_started([project_bookclub, query_bookclub]),
        ?assertEqual(ok, ?SERVICE:health()),
        lists:foreach(fun(A) -> application:stop(A) end, lists:reverse(Started))
    after
        os:unsetenv("MCL_DATA_DIR"),
        file:del_dir_r(DataDir)
    end.

%% The list is a promise that something answers. One procedure exists today;
%% the assertion is here so that adding or removing a capability is a
%% deliberate act with a name written down.
announces_exactly_the_existing_capabilities_test() ->
    ?assertEqual([#{name => <<"get_bookclub_by_id">>,
                    version => 1,
                    handler => {mcl_bookclub_get_bookclub_by_id, []},
                    auth => open}],
                 ?SERVICE:capabilities()).

identity_spec_has_the_shape_mcl_om_expects_test() ->
    #{scope := Scope, actions := Actions,
      resources := Resources, ttl_days := Ttl} = ?SERVICE:identity_spec(),
    ?assert(is_binary(Scope)),
    ?assert(is_list(Actions)),
    ?assert(is_list(Resources)),
    ?assert(is_integer(Ttl) andalso Ttl > 0).

%% A resource this service is not authorised for is a publish the realm would
%% refuse once UCAN delegation lands. What is announced and what authority is
%% asked for must stay in step: one action per capability, one resource per
%% published topic, asserted together so they cannot drift apart silently.
authority_matches_what_is_announced_test() ->
    #{actions := Actions, resources := Resources} = ?SERVICE:identity_spec(),
    ?assertEqual([<<"get_bookclub_by_id">>], Actions),
    ?assertEqual([<<"bookclub/member/member_registered_v1">>,
                  <<"bookclub/book/book_procured_v1">>,
                  <<"bookclub/book/book_retired_v1">>], Resources),
    ?assertEqual(length(Actions), length(?SERVICE:capabilities())).

%% The supervisor starts and stops cleanly on its own, without mcl_om. Its
%% one child is the LAN admin listener, on an ephemeral port so the test
%% never collides with a box's real UI.
supervisor_starts_and_stops_test() ->
    load_app(mcl_bookclub),
    ok = application:set_env(mcl_bookclub, admin_port, 0),
    {ok, Started} = application:ensure_all_started([cowboy]),
    {ok, Pid} = mcl_bookclub_sup:start_link(),
    ?assert(is_process_alive(Pid)),
    ?assertMatch([{mcl_bookclub_admin_http, _, _, _}],
                 supervisor:which_children(Pid)),
    unlink(Pid),
    exit(Pid, shutdown),
    [application:stop(App) || App <- lists:reverse(Started)].

%% The advertised capability, exercised end to end without the mesh: the
%% handler reads the wire parameter (all three key/value shapes), the QRY
%% desk answers from the sqlite read model, and the reply's text comes back
%% as CBOR text. Nothing boots mcl_om.
the_capability_answers_from_the_read_model_test() ->
    DataDir = tmp_dir(),
    os:putenv("MCL_DATA_DIR", DataDir),
    try
        {ok, Started} = application:ensure_all_started([esqlite, query_bookclub]),
        {ok, Conn} = esqlite3:open(filename:join(DataDir, "bookclub.sqlite3")),
        [ok = esqlite3:exec(Conn, Sql) || Sql <- bookclub_read_model_store:schema()],
        ClubId = list_to_binary(
                   io_lib:format("bookclub-~32.16.0b", [erlang:unique_integer([positive])])),
        ok = seed_club(Conn, ClubId),
        {reply, Wire, undefined} =
            mcl_bookclub_get_bookclub_by_id:handle_request(
              #{<<"club_id">> => {text, ClubId}}, undefined),
        ?assertEqual({text, <<"The Crooked Shelf">>}, maps:get(name, Wire)),
        ?assertEqual({text, <<"active">>}, maps:get(status, Wire)),
        {error, not_found, undefined} =
            mcl_bookclub_get_bookclub_by_id:handle_request(
              #{club_id => <<"bookclub-", (binary:copy(<<"0">>, 32))/binary>>},
              undefined),
        lists:foreach(fun(A) -> application:stop(A) end, lists:reverse(Started))
    after
        os:unsetenv("MCL_DATA_DIR"),
        file:del_dir_r(DataDir)
    end.

seed_club(Conn, ClubId) ->
    {ok, Stmt} = esqlite3:prepare(
                   Conn,
                   "INSERT INTO clubs (club_id, name, status, initiated_by,"
                   " initiated_at, event_id, version)"
                   " VALUES (?, ?, 'active', ?, ?, ?, ?)"),
    ok = esqlite3:bind(Stmt, [ClubId, <<"The Crooked Shelf">>, <<"bea">>,
                              42, <<"evt-1">>, 0]),
    '$done' = esqlite3:step(Stmt),
    ok.

%%==============================================================================
%% The config the store cannot boot without
%%==============================================================================

%% ⚠ A SIBLING SERVICE'S FLEET CRASH-LOOPED ON TWO OF THREE NODES FOR WANT OF THE
%% `evoq' BLOCK.
%%
%% Exporting `store_id/0' makes `mcl_om:boot/1' start the store AND a per-store
%% evoq subscription. That subscription reads through evoq, which raises
%% `{not_configured, event_store_adapter}' unless sys.config names the adapter,
%% and evoq starts as a release-boot application before any service's `start/2'
%% runs, so nothing can inject it later.
%%
%% This reads the shipped config template, because the failure is a MISSING
%% BLOCK and no amount of exercising the code can notice something that is not
%% there.
the_evoq_adapter_is_configured_wherever_a_store_is_opened_test() ->
    {ok, Text} = file:read_file(alongside("config/sys.config.src")),
    ?assert(erlang:function_exported(?SERVICE, store_id, 0)),
    lists:foreach(
      fun(Needed) ->
              ?assertNotEqual(nomatch, binary:match(Text, Needed),
                              {missing_from_sys_config, Needed})
      end,
      [<<"{evoq,">>, <<"event_store_adapter">>, <<"subscription_adapter">>,
       <<"reckon_evoq_adapter">>]).

%% ⚠ AND THE STORE ID IS IN TWO PLACES, WHICH IS ONE MORE THAN IT SHOULD BE.
%% `store_id/0' is what mcl_om opens; the `{store_id, ...}' in the evoq block
%% is what evoq falls back to when it resolves a dispatch before knowing there
%% is none. Nothing makes them agree, and disagreeing opens one store and
%% addresses another. Same boundary guard, other side.
the_store_id_agrees_between_erlang_and_config_test() ->
    {ok, Text} = file:read_file(alongside("config/sys.config.src")),
    Declared = atom_to_binary(?SERVICE:store_id(), utf8),
    ?assertNotEqual(nomatch, binary:match(Text, Declared),
                    {store_id_not_in_sys_config, Declared}).

%% The data directory must be somewhere, and a laptop default is fine. What is
%% not fine is shipping that default to a node, which is why the generated
%% compose file mounts a volume and sets the variable this reads.
the_data_directory_is_answerable_test() ->
    ?assert(erlang:function_exported(?SERVICE, data_dir, 0)),
    ?assert(is_list(?SERVICE:data_dir())),
    ?assertNotEqual("", ?SERVICE:data_dir()).

%% THE SQLITE PATH IS A THIRD PLACE, shared by three modules: the facade's
%% data_dir/0 default and the two division supervisors that derive the sqlite
%% file from the same variable. Nothing makes them agree by themselves, so
%% this pins the default string into all three.
the_sqlite_default_matches_between_the_facade_and_the_divisions_test() ->
    os:unsetenv("MCL_DATA_DIR"),
    ?assertEqual("/tmp/mcl_bookclub", ?SERVICE:data_dir()),
    lists:foreach(
      fun(Rel) ->
              {ok, Text} = file:read_file(alongside(Rel)),
              ?assertNotEqual(nomatch, binary:match(Text, <<"/tmp/mcl_bookclub">>),
                              {default_not_pinned, Rel})
      end,
      ["apps/project_bookclub/src/project_bookclub_sup.erl",
       "apps/query_bookclub/src/query_bookclub_sup.erl"]).

%%==============================================================================
%% The runtime is pinned in four places and they must agree
%%==============================================================================

%% The builder image (by digest), the CI image's toolchain check, .tool-versions
%% and the VM running this test. A floating `erlang:28' once shipped OTP 28.5 to
%% the fleet while every check stayed green.
the_runtime_agrees_between_the_image_the_ci_and_this_vm_test() ->
    %% The team images' tags name a date, not a release, so the builder and
    %% lint each assert the release in a check step; this compares those, the
    %% .tool-versions pin and this VM, to the patch.
    Check = "\\{<<\"([0-9]+\\.[0-9]+\\.[0-9]+)\">>, true\\} -> halt\\(0\\);",
    Image = pinned("Containerfile", Check),
    Ci = pinned(".github/workflows/lint.yml", Check),
    Tools = pinned(".tool-versions", "^erlang ([0-9]+\\.[0-9]+\\.[0-9]+)$"),
    ?assertEqual([Image], lists:usort([Image, Ci, Tools, running_otp()])).

%% Build, CI and runtime are the team pair, named by dated tag AND digest, so a
%% re-pushed tag cannot change what builds or what runs. (The build image
%% carries rebar3 itself; the image build no longer downloads one.)
images_are_the_digest_pinned_team_pair_test() ->
    Digest = ":[0-9]{8}-[0-9]{4}@sha256:[0-9a-f]{64}",
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "^FROM (ghcr\\.io/macula-io/macula-ci-otp)" ++ Digest ++ " AS builder$")),
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "^FROM (ghcr\\.io/macula-io/macula-pq-runtime)" ++ Digest ++ "$")),
    %% The builder and lint are the same build image, digest for digest.
    ?assertEqual(pinned("Containerfile", "^FROM (ghcr\\.io/[^ ]+) AS builder$"),
                 pinned(".github/workflows/lint.yml", "^\\s+image: (ghcr\\.io/[^\\s]+)$")).

%% The image says which commit it was built from: build-push passes the sha,
%% the runtime stage labels the image with it.
the_image_carries_its_revision_test() ->
    ?assertEqual(<<"REVISION">>, pinned("Containerfile", "^ARG (REVISION)=unknown$")),
    ?assertMatch(<<_/binary>>,
                 pinned("Containerfile",
                        "LABEL (org\\.opencontainers\\.image\\.revision=\"\\$\\{REVISION\\}\")")).

%% The full release, 28.4.3 and not 28: `otp_release' names only the major.
running_otp() ->
    {ok, Version} = file:read_file(filename:join([code:root_dir(), "releases",
                                                  erlang:system_info(otp_release),
                                                  "OTP_VERSION"])),
    string:trim(Version).

pinned(Relative, Pattern) ->
    {ok, Text} = file:read_file(alongside(Relative)),
    {match, [Version]} = re:run(Text, Pattern,
                                [multiline, {capture, all_but_first, binary}]),
    Version.

%% Relative to the beam rather than the working directory, because eunit runs
%% from wherever the developer happens to be standing.
alongside(Name) -> climb(filename:dirname(code:which(?MODULE)), Name, 8).

climb(_Dir, Name, 0) -> Name;
climb(Dir, Name, Left) ->
    Candidate = filename:join(Dir, Name),
    found(filelib:is_regular(Candidate), Candidate, Dir, Name, Left).

found(true, Candidate, _Dir, _Name, _Left) -> Candidate;
found(false, _Candidate, Dir, Name, Left) ->
    climb(filename:dirname(Dir), Name, Left - 1).

tmp_dir() ->
    Dir = filename:join(["/tmp", "mcl_bookclub_service_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.

load_app(App) ->
    case application:load(App) of
        ok -> ok;
        {error, {already_loaded, App}} -> ok
    end.
