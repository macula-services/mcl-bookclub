%% @doc Projects bookclub_initiated_v1 into the clubs table.
%%
%% A projection in this service is an evoq_event_handler writing idempotent
%% sqlite rows -- the shape the house rules recommend over evoq_projection
%% for multi-stream tables (a single integer checkpoint cannot order across
%% streams; see guides/event_delivery.md).
%%
%% Three deliberate choices, each worth understanding before copying:
%%
%% - replay_policy/0 is `deliver': the write is INSERT OR REPLACE keyed on the
%%   stream id, so applying an event twice is the same write twice. Skipping
%%   replays would leave rows missing after a restart that resumes before
%%   this event.
%% - The row carries event_id and version, the applied position, saved WITH
%%   the projected data in the same statement.
%% - The status string is NOT a literal of this file's own: it comes from
%%   bookclub_status:to_string/1, the flag map the status module owns --
%%   the raw bit flags never leave the CMD division, and neither do the
%%   names (Demon 68).
-module(bookclub_initiated_v1_to_sqlite_clubs).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"bookclub_initiated_v1">>].

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
            bookclub_status:to_string(bookclub_status:initiated()),
            maps:get(initiated_by, Data),
            maps:get(initiated_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
