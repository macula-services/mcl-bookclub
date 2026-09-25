%% @doc OTP application entry for the CMD division.
-module(host_bookclub_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> host_bookclub_sup:start_link().

stop(_State) -> ok.
