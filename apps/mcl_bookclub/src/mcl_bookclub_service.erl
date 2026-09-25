%% @doc The mcl_om service contract: what this service is and may do.
%%
%% SIX CALLBACKS, ALL REQUIRED, plus the two optional ones that turn the store
%% on. mcl_om resolves them BY NAME at startup, on a live node, so a service
%% that forgets one dies with `undef' where nobody is watching. The
%% `-behaviour' attribute below is what turns that into a compile error
%% instead, and the test suite guards the attribute itself.
%%
%% The facade is the only app in this repository that knows the mesh exists:
%% capabilities/0 will name QRY's query modules as procedures once those
%% procedures exist, and health/0 probes the division stores. The three
%% division apps import neither macula nor mcl_om.
-module(mcl_bookclub_service).

-behaviour(mcl_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
-export([store_id/0, data_dir/0]).

info() ->
    #{name => <<"mcl-bookclub">>,
      version => <<"0.1.0">>,
      description => <<"A book club kept as a reckon-db event store, with projections into sqlite.">>}.

start(_Opts) -> mcl_bookclub_sup:start_link().

stop(_State) -> ok.

%% The service's health IS the health of its read path: the two sqlite store
%% processes the divisions run. Their absence or silence means the club's
%% record is unreachable, however healthy the rest of the node looks.
health() ->
    case {ping(bookclub_read_model_store), ping(bookclub_query_store)} of
        {ok, ok} ->
            ok;
        {ReadModel, Query} ->
            {degraded, #{read_model_store => ReadModel, query_store => Query}}
    end.

ping(Name) ->
    try gen_server:call(Name, ping, 1000) of
        Reply -> Reply
    catch
        exit:{noproc, _} -> missing;
        exit:Reason -> {down, Reason}
    end.

%% WHAT THIS SERVICE ANNOUNCES IT CAN DO. Empty on purpose: the walking
%% skeleton's queries are not yet advertised as mesh procedures, and
%% advertising a capability before it exists puts a lie on the mesh that
%% another service can find and call. This list grows when the thing it names
%% exists, and a test fails when it changes, so growing it is a deliberate act.
capabilities() -> [].

%% THE AUTHORITY THIS SERVICE ASKS THE REALM FOR, and deliberately nothing more.
%% Empty until the emitters land: publishing a fact needs a topic, and asking
%% for nothing while publishing something is the mismatch this list exists to
%% prevent.
identity_spec() ->
    #{scope => <<"mcl-bookclub">>,
      actions => [],
      resources => [],
      ttl_days => 30}.

%% ==========================================================================
%% The store
%% ==========================================================================

%% @doc The reckon-db store this service owns.
%%
%% IT IS NAMED IN TWO PLACES, here and in the `evoq' block of
%% `config/sys.config.src', and nothing makes them agree by itself.
%% Disagreeing opens one store and addresses another. A test compares the two.
%% The CMD division names the same store when it dispatches -- see
%% maybe_initiate_bookclub:dispatch/1.
-spec store_id() -> atom().
store_id() -> mcl_bookclub_store.

%% @doc Where the record lives on disk: the reckon-db store at
%% <data_dir>/mcl_bookclub_store and the sqlite read model at
%% <data_dir>/bookclub.sqlite3. Both division stores derive their paths from
%% the same variable, with the same default as here; a test pins the three
%% defaults together.
%%
%% DEFAULTS TO /tmp/mcl_bookclub, which is what a laptop wants. A container
%% without the compose volume loses the club's record on every recreate, which
%% is the same as not keeping one.
-spec data_dir() -> string().
data_dir() -> chosen(os:getenv("MCL_DATA_DIR")).

chosen(false) -> "/tmp/mcl_bookclub";
chosen("")    -> "/tmp/mcl_bookclub";
chosen(Path)  -> Path.
