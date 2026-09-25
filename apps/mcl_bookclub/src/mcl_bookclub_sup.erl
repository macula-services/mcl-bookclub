%% @doc Supervises this service's own processes: the LAN admin listener.
%%
%% Every other process the service runs lives in a division: aggregates are
%% started on demand by evoq (CMD), the read-model store and projections
%% live in project_bookclub_sup (PRJ), the query store in
%% query_bookclub_sup (QRY). The facade owns the mesh-facing contract and
%% the LAN-facing admin UI -- the cowboy listener on MCL_ADMIN_PORT.
-module(mcl_bookclub_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [
        #{id => mcl_bookclub_admin_http,
          start => {mcl_bookclub_admin, start_listener, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [mcl_bookclub_admin]}
    ]}}.
