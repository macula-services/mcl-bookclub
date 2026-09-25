%% @doc Supervises the CMD division's own processes.
%%
%% Aggregates are started on demand by evoq's own partition supervisors when
%% a command targets them -- they never appear in a service supervisor. What
%% lives here are the things that subscribe to events: the policy slice
%% (on_member_registered_v1_maybe_plan_party), and later the mesh emitters
%% (emit_*_v1_to_mesh), one evoq_event_handler child each.
-module(host_bookclub_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [
        #{id => on_member_registered_v1_maybe_plan_party,
          start => {evoq_event_handler, start_link,
                    [on_member_registered_v1_maybe_plan_party, #{}]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [evoq_event_handler]},
        #{id => emit_member_registered_v1_to_mesh,
          start => {evoq_event_handler, start_link,
                    [emit_member_registered_v1_to_mesh, #{}]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [evoq_event_handler]},
        #{id => emit_book_procured_v1_to_mesh,
          start => {evoq_event_handler, start_link,
                    [emit_book_procured_v1_to_mesh, #{}]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [evoq_event_handler]},
        #{id => emit_book_retired_v1_to_mesh,
          start => {evoq_event_handler, start_link,
                    [emit_book_retired_v1_to_mesh, #{}]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [evoq_event_handler]}
    ]}}.
