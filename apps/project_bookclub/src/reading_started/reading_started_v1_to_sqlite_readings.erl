%% @doc Projects reading_started_v1 into the readings table.
%%
%% The same idempotent shape as every projection here: INSERT OR REPLACE
%% keyed on the stream id, the applied position in the row, and the status
%% string taken from reading_status:to_string/1 -- never a literal of this
%% file's own. A reading born in progress has zero pages read and no finish
%% time -- the finished event fills both in.
-module(reading_started_v1_to_sqlite_readings).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"reading_started_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO readings"
           " (reading_id, member_id, book_id, status, started_at, pages_read,"
           "  finished_at, event_id, version)"
           " VALUES (?, ?, ?, ?, ?, 0, NULL, ?, ?)",
           [maps:get(reading_id, Data),
            maps:get(member_id, Data),
            maps:get(book_id, Data),
            reading_status:to_string(reading_status:in_progress()),
            maps:get(started_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
