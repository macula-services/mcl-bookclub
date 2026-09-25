%% @doc Projects member_unregistered_v1 into the members table.
%%
%% Self-contained like the club's archived projection: the event echoes the
%% member's club, name and registration time, so this write never depends
%% on the registered event having arrived first. The status string comes
%% from member_status:to_string/1 -- never a literal of this file's own.
-module(member_unregistered_v1_to_sqlite_members).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"member_unregistered_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO members"
           " (member_id, club_id, name, status, registered_at, event_id, version)"
           " VALUES (?, ?, ?, ?, ?, ?, ?)",
           [maps:get(member_id, Data),
            maps:get(club_id, Data),
            maps:get(name, Data),
            member_status:to_string(member_status:unregistered()),
            maps:get(registered_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
