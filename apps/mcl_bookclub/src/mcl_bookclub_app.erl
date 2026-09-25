%% @doc OTP application entry for the facade.
%%
%% mcl_om:boot/1 wires the mesh, the realm identity, capabilities and health,
%% then starts this service. Because the service exports store_id/0 and
%% data_dir/0, boot/1 also opens the reckon-db store AND its evoq subscription
%% BEFORE start/1 fires -- so this code never calls reckon_db_sup:start_store/1
%% itself.
%%
%% The three divisions start before this app does (they are listed in the
%% .app.src applications tuple), so by the time the store subscription starts
%% its catch-up replay here, every projection and query store is already
%% registered and listening.
-module(mcl_bookclub_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> mcl_om:boot(mcl_bookclub_service).

stop(_State) -> ok.
