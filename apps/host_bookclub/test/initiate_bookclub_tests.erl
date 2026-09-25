%% @doc initiate_bookclub against a real reckon-db store through evoq.
%%
%% The store is opened with reckon_db_sup:start_store/1, the same call the
%% facade's boot makes for this service, so the dispatch, the aggregate, the
%% event and its stream are the ones a running node has. The CMD division
%% touches no mesh code -- not even in tests -- so the store is opened
%% directly rather than through mcl_om.
-module(initiate_bookclub_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(STORE, mcl_bookclub_store).

store_test_() ->
    {setup,
     fun start_store/0,
     fun stop_store/1,
     [{timeout, 60, fun a_club_is_initiated_on_its_own_stream/0},
      {timeout, 60, fun a_second_initiation_is_refused/0},
      {timeout, 60, fun a_rejected_stream_id_never_touches_the_store/0}]}.

pure_test_() ->
    [fun a_command_needs_every_field/0,
     fun a_minted_club_id_satisfies_the_stream_contract/0,
     fun the_state_folds_both_event_shapes/0,
     fun the_state_round_trips_through_a_map/0,
     fun the_cmd_division_imports_no_mesh_or_sqlite_module/0].

a_club_is_initiated_on_its_own_stream() ->
    {ok, Cmd} = club(),
    {ok, 0, [Event]} = maybe_initiate_bookclub:dispatch(Cmd),
    ?assertMatch(#{name := <<"The Crooked Shelf">>,
                   initiated_by := <<"bea">>}, Event),
    [Stored | _] = lists:reverse(stream(initiate_bookclub_v1:stream_id(Cmd))),
    ?assertEqual(<<"bookclub_initiated_v1">>, Stored#event.event_type),
    ?assertMatch(#{name := <<"The Crooked Shelf">>}, Stored#event.data).

%% The aggregate is the consistency boundary: the same club, asked twice,
%% is initiated once. The second dispatch's error IS the answer -- nothing
%% logged it, nothing retried it, the caller sees exactly this term.
a_second_initiation_is_refused() ->
    {ok, Cmd} = club(),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    ?assertEqual({error, already_initiated}, maybe_initiate_bookclub:dispatch(Cmd)).

%% A human-readable id fails the stream contract, and the rejection happens
%% in the desk's validate/1 -- at the dispatch boundary -- before anything
%% is appended. The store client RAISES `{invalid_stream_id, _}' on a bad id,
%% even just reading it; the raise asserted below is the alternative the
%% desk's validate/1 prevents, which is why validation must live in dispatch
%% and not only inside the aggregate.
a_rejected_stream_id_never_touches_the_store() ->
    {ok, Cmd} = initiate_bookclub_v1:new(
                  #{club_id => <<"the-crooked-shelf">>,
                    name => <<"N">>, initiated_by => <<"bea">>}),
    ?assertMatch({error, _}, maybe_initiate_bookclub:dispatch(Cmd)),
    ?assertError({invalid_stream_id, _}, stream(<<"the-crooked-shelf">>)).

a_command_needs_every_field() ->
    ?assertEqual({error, missing_required_fields},
                 initiate_bookclub_v1:new(
                   #{name => <<"N">>, initiated_by => <<"bea">>})),
    ?assertEqual({error, invalid_params},
                 initiate_bookclub_v1:new(
                   #{club_id => <<"bookclub-x">>, name => <<>>,
                     initiated_by => <<"bea">>})).

a_minted_club_id_satisfies_the_stream_contract() ->
    ClubId = initiate_bookclub_v1:mint_club_id(),
    ?assertEqual(ok, reckon_gater_stream_id:validate(ClubId)),
    {ok, Cmd} = club_with(ClubId),
    ?assertEqual(ok, initiate_bookclub_v1:validate(Cmd)).

%% evoq hands apply/2 two shapes for the same event: the raw event right
%% after execute/2 (business fields inline), and the stored envelope on
%% reload (business fields under `data'). A fold that matches one shape only
%% works in memory and silently no-ops on replay -- the bug shows on the
%% SECOND command, never the first.
the_state_folds_both_event_shapes() ->
    S0 = bookclub_state:new(<<"bookclub-00">>),
    ?assertNot(bookclub_state:is_initiated(S0)),
    S1 = bookclub_state:apply_event(S0, #{event_type => <<"bookclub_initiated_v1">>,
                                          name => <<"Inline">>}),
    ?assert(bookclub_state:is_initiated(S1)),
    ?assertEqual(<<"Inline">>, bookclub_state:name(S1)),
    S2 = bookclub_state:apply_event(bookclub_state:new(<<"bookclub-01">>),
                                    #{event_type => <<"bookclub_initiated_v1">>,
                                      data => #{name => <<"Enveloped">>}}),
    ?assert(bookclub_state:is_initiated(S2)),
    ?assertEqual(<<"Enveloped">>, bookclub_state:name(S2)).

the_state_round_trips_through_a_map() ->
    S = bookclub_state:apply_event(bookclub_state:new(<<"bookclub-02">>),
                                   #{event_type => <<"bookclub_initiated_v1">>,
                                     data => #{name => <<"Round Trip">>}}),
    {ok, S2} = bookclub_state:from_map(bookclub_state:to_map(S)),
    ?assertEqual(<<"Round Trip">>, bookclub_state:name(S2)),
    ?assert(bookclub_state:is_initiated(S2)).

%% The division boundary, as a mechanism rather than a convention: the CMD
%% sources must not name a mesh or read-model module. Comments count --
%% naming the thing in prose is how the drift starts.
the_cmd_division_imports_no_mesh_or_sqlite_module() ->
    lists:foreach(
      fun(Forbidden) ->
              lists:foreach(
                fun(Src) ->
                        {ok, Text} = file:read_file(Src),
                        ?assertEqual(nomatch, binary:match(Text, Forbidden),
                                     {forbidden_reference, Forbidden, Src})
                end, erl_sources(repo_file("apps/host_bookclub/src")))
      end,
      [<<"macula">>, <<"mcl_om">>, <<"esqlite">>]).

%%============================================================================
%% Helpers
%%============================================================================

club() -> club_with(initiate_bookclub_v1:mint_club_id()).

club_with(ClubId) ->
    initiate_bookclub_v1:new(#{club_id => ClubId,
                               name => <<"The Crooked Shelf">>,
                               initiated_by => <<"bea">>}).

stream(ClubId) ->
    events(reckon_db_streams:read(?STORE, ClubId, 0, 1000, forward)).

events({ok, Events}) -> Events;
events({error, {stream_not_found, _}}) -> [];
events({error, _} = Error) -> error(Error).

start_store() ->
    Dir = filename:join(["/tmp", "initiate_bookclub_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    %% evoq may already be loaded in the eunit VM; either way it must accept
    %% the env below.
    load_app(evoq),
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, ?STORE}]],
    {ok, Started} = application:ensure_all_started([reckon_db, evoq, reckon_evoq]),
    {ok, _} = reckon_db_sup:start_store(#store_config{store_id = ?STORE,
                                                      data_dir = filename:join(Dir, "store"),
                                                      mode = single}),
    {Dir, Started}.

stop_store({Dir, Started}) ->
    [application:stop(App) || App <- lists:reverse(Started)],
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
