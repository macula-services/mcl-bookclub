%% @doc Projects bookclub_archived_v1 into the clubs table.
%%
%% The same idempotent shape as the initiated projection: INSERT OR REPLACE
%% keyed on the stream id, the row carrying the applied position (event_id,
%% version), and the status string taken from bookclub_status:to_string/1 --
%% never a literal of this file's own. Because the archived event is
%% self-contained -- it echoes name, initiated_by and initiated_at -- this
%% write does not depend on the initiated event having arrived first, in
%% this process's history or at all.
-module(bookclub_archived_v1_to_sqlite_clubs).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"bookclub_archived_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO clubs"
           " (club_id, name, status, initiated_by, initiated_at, event_id, version)"
           " VALUES (?, ?, ?, ?, ?, ?, ?)",
           [maps:get(club_id, Data),
            maps:get(name, Data),
            bookclub_status:to_string(bookclub_status:archived()),
            maps:get(initiated_by, Data),
            maps:get(initiated_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
