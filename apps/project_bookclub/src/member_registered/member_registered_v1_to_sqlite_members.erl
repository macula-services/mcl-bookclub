%% @doc Projects member_registered_v1 into the members table.
%%
%% The same idempotent shape as the club projections: INSERT OR REPLACE
%% keyed on the stream id, status computed here as the readable string,
%% and the row carrying the applied position (event_id, version).
-module(member_registered_v1_to_sqlite_members).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"member_registered_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO members"
           " (member_id, club_id, name, status, registered_at, event_id, version)"
           " VALUES (?, ?, ?, 'active', ?, ?, ?)",
           [maps:get(member_id, Data),
            maps:get(club_id, Data),
            maps:get(name, Data),
            maps:get(registered_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
