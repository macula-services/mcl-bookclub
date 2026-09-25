%% @doc The emitters, end to end: a domain event flows through the real
%% $all subscription to the emitter, and one fact goes out on the mesh --
%% meck stands in for the mesh itself, like every fleet emitter suite.
%%
%% This is also where the facts module's wire contract is pinned: text as
%% CBOR text, ids in the payload, one topic per fact kind.
-module(emit_member_registered_v1_to_mesh_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [{timeout, 60, fun a_registered_member_is_published_as_a_fact/0},
      {timeout, 60, fun a_procured_book_is_published_as_a_fact/0},
      {timeout, 60, fun a_retired_book_is_published_as_a_fact/0}]}.

pure_test_() ->
    [fun the_emitters_declare_skip_on_replay/0].

a_registered_member_is_published_as_a_fact() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = register_member_v1:new(
                  #{member_id => register_member_v1:mint_member_id(),
                    club_id => ClubId,
                    name => <<"Bea">>,
                    club_name => <<"The Crooked Shelf">>}),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    {Topic, Fact} = await_publish(<<"member_registered">>, 100),
    ?assertEqual(<<"io.macula/mcl-bookclub/bookclub/member/member_registered_v1">>,
                 Topic),
    ?assertEqual({text, ClubId}, maps:get(club_id, Fact)),
    %% The fact names its club: one topic, a thousand clubs, each fact
    %% saying which one it belongs to.
    ?assertEqual({text, <<"The Crooked Shelf">>}, maps:get(club_name, Fact)),
    ?assertEqual({text, <<"Bea">>}, maps:get(name, Fact)),
    ?assertMatch({text, _}, maps:get(member_id, Fact)).

a_procured_book_is_published_as_a_fact() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = procure_book_v1:new(
                  #{book_id => procure_book_v1:mint_book_id(),
                    club_id => ClubId,
                    title => <<"Project Hail Mary">>,
                    author => <<"Andy Weir">>}),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    {Topic, Fact} = await_publish(<<"book_procured">>, 100),
    ?assertEqual(<<"io.macula/mcl-bookclub/bookclub/book/book_procured_v1">>,
                 Topic),
    ?assertEqual({text, <<"Project Hail Mary">>}, maps:get(title, Fact)),
    ?assertEqual({text, <<"Andy Weir">>}, maps:get(author, Fact)).

a_retired_book_is_published_as_a_fact() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = procure_book_v1:new(
                  #{book_id => procure_book_v1:mint_book_id(),
                    club_id => ClubId,
                    title => <<"Project Hail Mary">>,
                    author => <<"Andy Weir">>}),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    {ok, RetireCmd} = retire_book_v1:new(#{book_id => procure_book_v1:stream_id(Cmd),
                                           retired_by => <<"raf">>}),
    {ok, 1, _} = maybe_retire_book:dispatch(RetireCmd),
    {Topic, Fact} = await_publish(<<"book_retired">>, 100),
    ?assertEqual(<<"io.macula/mcl-bookclub/bookclub/book/book_retired_v1">>,
                 Topic),
    ?assertEqual({text, <<"raf">>}, maps:get(retired_by, Fact)),
    ?assertEqual({text, <<"Project Hail Mary">>}, maps:get(title, Fact)),
    %% The retired fact echoes procured_at, so a consumer's retire write can
    %% be an absolute REPLACE of the whole row, never a partial UPDATE that
    %% assumes the procured fact arrived first.
    ?assert(is_integer(maps:get(procured_at, Fact))).

%% A side-effect handler must refuse replays, or a restart re-publishes the
%% whole history. The mechanism is the declared policy, asserted here so a
%% dropped declaration breaks a test.
the_emitters_declare_skip_on_replay() ->
    ?assertEqual(skip, emit_member_registered_v1_to_mesh:replay_policy()),
    ?assertEqual(skip, emit_book_procured_v1_to_mesh:replay_policy()),
    ?assertEqual(skip, emit_book_retired_v1_to_mesh:replay_policy()).

%%============================================================================
%% Helpers
%%============================================================================

initiated_club() ->
    {ok, Cmd} = initiate_bookclub_v1:new(
                  #{club_id => initiate_bookclub_v1:mint_club_id(),
                    name => <<"The Crooked Shelf">>,
                    initiated_by => <<"bea">>}),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    {ok, initiate_bookclub_v1:stream_id(Cmd)}.

await_publish(_Name, 0) -> error(no_publish);
await_publish(Name, Tries) ->
    found([{T, F} || {_, {macula, publish, [_, _, T, F]}, _} <- meck:history(macula),
                     binary:match(T, Name) =/= nomatch],
          Name, Tries).

found([Hit | _], _Name, _Tries) -> Hit;
found([], Name, Tries) -> timer:sleep(100), await_publish(Name, Tries - 1).

setup() ->
    {Dir, Started} = host_bookclub_test_store:start(),
    meck:new(mcl_om, [passthrough]),
    meck:new(macula, [passthrough]),
    meck:expect(mcl_om, mesh_handles,
                fun() -> {ok, pool, crypto:hash(sha256, <<"io.macula">>)} end),
    meck:expect(macula, publish, fun(_Pool, _Realm, _Topic, _Fact) -> ok end),
    {ok, Sub} = evoq_store_subscription:start_link(host_bookclub_test_store:store()),
    unlink(Sub),
    Emitters = [start_emitter(M) || M <- [emit_member_registered_v1_to_mesh,
                                          emit_book_procured_v1_to_mesh,
                                          emit_book_retired_v1_to_mesh]],
    {Dir, Started, Sub, Emitters}.

start_emitter(Module) ->
    {ok, Emitter} = evoq_event_handler:start_link(Module, #{}),
    unlink(Emitter),
    Emitter.

cleanup({Dir, Started, Sub, Emitters}) ->
    lists:foreach(fun(P) -> exit(P, shutdown) end, Emitters),
    exit(Sub, shutdown),
    meck:unload(macula),
    meck:unload(mcl_om),
    host_bookclub_test_store:stop({Dir, Started}).
