%% @doc OTP application entry for the PRJ division.
%%
%% Starting this app opens the sqlite read model and registers the
%% projections with evoq's event-type registry. The store subscription that
%% feeds them is started later, by the facade's boot, so by the time its
%% catch-up replay runs, every projection is listening.
-module(project_bookclub_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> project_bookclub_sup:start_link().

stop(_State) -> ok.
