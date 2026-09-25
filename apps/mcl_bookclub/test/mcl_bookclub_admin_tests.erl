%% @doc The LAN admin UI, end to end over real HTTP.
%%
%% The cowboy listener starts on an ephemeral port (admin_port 0), the
%% writes go through the desk entry points against a real reckon-db store,
%% and the reads come back from the sqlite read model -- the whole path the
%% operator's browser takes, minus the browser.
-module(mcl_bookclub_admin_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").

store_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [{timeout, 60, fun the_static_ui_is_served/0},
      {timeout, 60, fun a_club_is_initiated_over_http/0},
      {timeout, 60, fun a_member_registers_and_answers_by_id/0},
      {timeout, 60, fun a_reading_starts_and_finishes_over_http/0},
      {timeout, 60, fun a_missing_field_is_a_400/0},
      {timeout, 60, fun an_unknown_id_is_a_404/0}]}.

the_static_ui_is_served() ->
    {ok, {{_, 200, _}, _, Body}} = httpc:request(get, {url([<<"/">>]), []},
                                                  [], [{body_format, binary}]),
    ?assertNotEqual(nomatch, binary:match(Body, <<"mcl-bookclub">>)),
    {ok, {{_, 200, _}, _, Js}} = httpc:request(get, {url([<<"/app.js">>]), []},
                                                [], [{body_format, binary}]),
    ?assertNotEqual(nomatch, binary:match(Js, <<"Run">>)).

a_club_is_initiated_over_http() ->
    {200, Reply} = http_post("/api/clubs/initiate",
                        #{<<"name">> => <<"The Crooked Shelf">>,
                          <<"initiated_by">> => <<"raf">>}),
    ?assertEqual(true, maps:get(<<"ok">>, Reply)),
    ?assertEqual(0, maps:get(<<"version">>, Reply)),
    ClubId = maps:get(<<"club_id">>, hd(maps:get(<<"events">>, Reply))),
    {200, Club} = await_http_get(["/api/clubs/", ClubId], 50),
    ?assertEqual(<<"The Crooked Shelf">>, maps:get(<<"name">>, Club)),
    ?assertEqual(<<"active">>, maps:get(<<"status">>, Club)).

a_member_registers_and_answers_by_id() ->
    {200, ClubReply} = http_post("/api/clubs/initiate",
                            #{<<"name">> => <<"The Crooked Shelf">>,
                              <<"initiated_by">> => <<"raf">>}),
    ClubId = maps:get(<<"club_id">>, hd(maps:get(<<"events">>, ClubReply))),
    {200, MemberReply} = http_post("/api/members/register",
                              #{<<"club_id">> => ClubId,
                                <<"name">> => <<"Bea">>}),
    MemberId = maps:get(<<"member_id">>, hd(maps:get(<<"events">>, MemberReply))),
    {200, Member} = await_http_get(["/api/members/", MemberId], 50),
    ?assertEqual(<<"Bea">>, maps:get(<<"name">>, Member)).

a_reading_starts_and_finishes_over_http() ->
    {200, ClubReply} = http_post("/api/clubs/initiate",
                            #{<<"name">> => <<"The Crooked Shelf">>,
                              <<"initiated_by">> => <<"raf">>}),
    ClubId = maps:get(<<"club_id">>, hd(maps:get(<<"events">>, ClubReply))),
    {200, MemberReply} = http_post("/api/members/register",
                              #{<<"club_id">> => ClubId, <<"name">> => <<"Bea">>}),
    MemberId = maps:get(<<"member_id">>, hd(maps:get(<<"events">>, MemberReply))),
    {200, BookReply} = http_post("/api/books/procure",
                            #{<<"club_id">> => ClubId,
                              <<"title">> => <<"Project Hail Mary">>,
                              <<"author">> => <<"Andy Weir">>}),
    BookId = maps:get(<<"book_id">>, hd(maps:get(<<"events">>, BookReply))),
    {200, StartReply} = http_post("/api/readings/start",
                             #{<<"member_id">> => MemberId, <<"book_id">> => BookId}),
    ReadingId = maps:get(<<"reading_id">>, hd(maps:get(<<"events">>, StartReply))),
    {200, _} = http_post("/api/readings/finish",
                    #{<<"reading_id">> => ReadingId, <<"pages_read">> => 476}),
    {200, Reading} = await_http_get(["/api/readings/", ReadingId], 50),
    ?assertEqual(<<"finished">>, maps:get(<<"status">>, Reading)),
    ?assertEqual(476, maps:get(<<"pages_read">>, Reading)),
    {200, Readings} = http_get(["/api/members/", MemberId, "/readings"]),
    ?assertEqual(1, length(Readings)).

a_missing_field_is_a_400() ->
    {400, Reply} = http_post("/api/clubs/archive", #{}),
    ?assertEqual(false, maps:get(<<"ok">>, Reply)),
    ?assert(maps:is_key(<<"error">>, Reply)).

an_unknown_id_is_a_404() ->
    {404, Reply} = http_get(["/api/clubs/", <<"bookclub-", (binary:copy(<<"0">>, 32))/binary>>]),
    ?assertEqual(false, maps:get(<<"ok">>, Reply)).

%%============================================================================
%% Helpers
%%============================================================================

http_get(Path) ->
    {ok, {{_, Status, _}, _, Body}} =
        httpc:request(get, {url(Path), []}, [], [{body_format, binary}]),
    {Status, decode(Body)}.

http_post(Path, Body) ->
    {ok, {{_, Status, _}, _, RespBody}} =
        httpc:request(post, {url(Path), [], "application/json",
                             jsx:encode(Body)},
                      [], [{body_format, binary}]),
    {Status, decode(RespBody)}.

await_http_get(_Path, 0) -> error(not_projected);
await_http_get(Path, Tries) ->
    case http_get(Path) of
        {200, _} = Ok -> Ok;
        _ -> timer:sleep(100), await_http_get(Path, Tries - 1)
    end.

decode(Body) ->
    case jsx:decode(Body, [{labels, binary}]) of
        [] -> [];
        Decoded -> Decoded
    end.

url([C | _] = Path) when is_integer(C) ->
    %% A flat string: use it as-is.
    base() ++ Path;
url(Path) ->
    %% A list of string/binary parts.
    base() ++ lists:append([part(P) || P <- Path]).

part(P) when is_binary(P) -> binary_to_list(P);
part(P) when is_list(P) -> P.

base() ->
    Port = ranch:get_port(mcl_bookclub_admin_http),
    "http://127.0.0.1:" ++ integer_to_list(Port).

setup() ->
    Dir = filename:join(["/tmp", "mcl_bookclub_admin_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    load_app(mcl_bookclub),
    ok = application:set_env(mcl_bookclub, admin_port, 0),
    load_app(evoq),
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, mcl_bookclub_store}]],
    os:putenv("MCL_DATA_DIR", Dir),
    {ok, Started} = application:ensure_all_started(
                      [reckon_db, evoq, reckon_evoq, esqlite, inets, cowboy,
                       project_bookclub, query_bookclub]),
    {ok, _} = reckon_db_sup:start_store(#store_config{store_id = mcl_bookclub_store,
                                                      data_dir = filename:join(Dir, "store"),
                                                      mode = single}),
    {ok, Sub} = evoq_store_subscription:start_link(mcl_bookclub_store),
    unlink(Sub),
    {ok, Sup} = mcl_bookclub_sup:start_link(),
    unlink(Sup),
    {Dir, Started, Sub, Sup}.

cleanup({Dir, Started, Sub, Sup}) ->
    exit(Sup, shutdown),
    exit(Sub, shutdown),
    [application:stop(App) || App <- lists:reverse(Started)],
    os:unsetenv("MCL_DATA_DIR"),
    file:del_dir_r(Dir).

load_app(App) ->
    case application:load(App) of
        ok -> ok;
        {error, {already_loaded, App}} -> ok
    end.
