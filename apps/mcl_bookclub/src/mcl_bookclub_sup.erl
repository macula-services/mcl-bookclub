%% @doc Supervises this service's own processes.
%%
%% NO CHILDREN, ON PURPOSE. Every process the service runs lives in a
%% division: aggregates are started on demand by evoq (CMD), the read-model
%% store and projections live in project_bookclub_sup (PRJ), the query store
%% in query_bookclub_sup (QRY). The facade owns the mesh-facing contract, not
%% processes, and an empty child list is the honest scaffold rather than a
%% placeholder.
-module(mcl_bookclub_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, []}}.
