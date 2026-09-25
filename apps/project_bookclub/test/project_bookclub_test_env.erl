%% @doc Shared environment for the PRJ division's desk suites: a real
%% reckon-db store, the $all subscription, the division apps (sqlite store
%% + projections), and the helpers the suites share.
%%
%% This is the whole released pipeline -- dispatch, subscription, router,
%% projection, sqlite -- which is exactly what these suites exist to prove.
-module(project_bookclub_test_env).

-export([start/0, stop/1, store/0, stream/1, await_row/3, await_rows/3]).
-export([erl_sources/1, repo_file/1]).

-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-spec store() -> atom().
store() -> mcl_bookclub_store.

-spec start() -> {string(), [atom()], pid()}.
start() ->
    Dir = filename:join(["/tmp", "project_bookclub_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    %% evoq may already be loaded in the eunit VM; either way it must accept
    %% the env below.
    load_app(evoq),
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, store()}]],
    os:putenv("MCL_DATA_DIR", Dir),
    {ok, Started} = application:ensure_all_started(
                      [reckon_db, evoq, reckon_evoq, esqlite, project_bookclub]),
    {ok, _} = reckon_db_sup:start_store(#store_config{store_id = store(),
                                                      data_dir = filename:join(Dir, "store"),
                                                      mode = single}),
    {ok, Sub} = evoq_store_subscription:start_link(store()),
    unlink(Sub),
    {Dir, Started, Sub}.

-spec stop({string(), [atom()], pid()}) -> ok.
stop({Dir, Started, Sub}) ->
    exit(Sub, shutdown),
    [application:stop(App) || App <- lists:reverse(Started)],
    os:unsetenv("MCL_DATA_DIR"),
    file:del_dir_r(Dir).

-spec stream(binary()) -> [#event{}].
stream(StreamId) ->
    events(reckon_db_streams:read(store(), StreamId, 0, 1000, forward)).

events({ok, Events}) -> Events;
events({error, {stream_not_found, _}}) -> [];
events({error, _} = Error) -> error(Error).

%% @doc Poll the read model until one row answers the query, or give up.
-spec await_row(string(), list(), non_neg_integer()) -> list().
await_row(Sql, Args, Tries) ->
    [Row | _] = await_rows(Sql, Args, Tries),
    Row.

-spec await_rows(string(), list(), non_neg_integer()) -> [list()].
await_rows(_Sql, _Args, 0) -> error(not_projected);
await_rows(Sql, Args, Tries) ->
    case bookclub_read_model_store:q(Sql, Args) of
        [] -> timer:sleep(100), await_rows(Sql, Args, Tries - 1);
        {error, Reason} -> error({store_error, Reason});
        Rows when is_list(Rows) -> Rows
    end.

-spec erl_sources(string()) -> [string()].
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

%% @doc Relative to the beam rather than the working directory, because
%% eunit runs from wherever the developer happens to be standing.
-spec repo_file(string()) -> string().
repo_file(Rel) -> climb(filename:dirname(code:which(?MODULE)), Rel, 8).

climb(_Dir, Rel, 0) -> Rel;
climb(Dir, Rel, Left) ->
    Candidate = filename:join(Dir, Rel),
    found(filelib:is_regular(Candidate), Candidate, Dir, Rel, Left).

found(true, Candidate, _Dir, _Rel, _Left) -> Candidate;
found(false, _Candidate, Dir, Rel, Left) ->
    climb(filename:dirname(Dir), Rel, Left - 1).

load_app(App) ->
    case application:load(App) of
        ok -> ok;
        {error, {already_loaded, App}} -> ok
    end.
