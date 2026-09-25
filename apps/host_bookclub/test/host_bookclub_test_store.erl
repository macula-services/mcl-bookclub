%% @doc Shared store boot for the CMD division's desk suites.
%%
%% Opens the same store a running node has, through the same call the
%% facade's boot makes (reckon_db_sup:start_store/1 with the service's
%% store config), so a desk test's dispatch, aggregate, event and stream
%% are the ones production sees. The CMD division touches no mesh code --
%% not even in tests -- so the store is opened directly.
-module(host_bookclub_test_store).

-export([start/0, stop/1, store/0, stream/1]).

-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-spec store() -> atom().
store() -> mcl_bookclub_store.

-spec start() -> {string(), [atom()]}.
start() ->
    Dir = filename:join(["/tmp", "host_bookclub_tests",
                         integer_to_list(erlang:unique_integer([positive]))]),
    %% evoq may already be loaded in the eunit VM; either way it must accept
    %% the env below.
    load_app(evoq),
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, store()}]],
    {ok, Started} = application:ensure_all_started([reckon_db, evoq, reckon_evoq]),
    {ok, _} = reckon_db_sup:start_store(#store_config{store_id = store(),
                                                      data_dir = filename:join(Dir, "store"),
                                                      mode = single}),
    {Dir, Started}.

-spec stop({string(), [atom()]}) -> ok.
stop({Dir, Started}) ->
    [application:stop(App) || App <- lists:reverse(Started)],
    file:del_dir_r(Dir).

-spec stream(binary()) -> [#event{}].
stream(ClubId) ->
    events(reckon_db_streams:read(store(), ClubId, 0, 1000, forward)).

events({ok, Events}) -> Events;
events({error, {stream_not_found, _}}) -> [];
events({error, _} = Error) -> error(Error).

load_app(App) ->
    case application:load(App) of
        ok -> ok;
        {error, {already_loaded, App}} -> ok
    end.
