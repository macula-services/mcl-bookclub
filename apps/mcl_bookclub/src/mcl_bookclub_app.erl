%% @doc OTP application entry for the facade.
%%
%% Opens this service's own reckon-db store and its evoq subscription
%% (mcl_bookclub_store, from mcl_bookclub_service:event_store/0), THEN lets
%% mcl_om:boot/1 wire the mesh, the realm identity, capabilities and health and
%% start the service. mcl_om opens no store (0.35, mcl-om#10).
%%
%% The three divisions start before this app does (they are listed in the
%% .app.src applications tuple), so by the time the store subscription starts
%% its catch-up replay here, every projection and query store is already
%% registered and listening.
-module(mcl_bookclub_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    ok = mcl_bookclub_store:open(mcl_bookclub_service:event_store()),
    mcl_om:boot(mcl_bookclub_service).

stop(_State) -> ok.
