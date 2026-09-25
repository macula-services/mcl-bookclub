%% @doc Projects reading_finished_v1 into the readings table.
%%
%% The fold, made safe: the finished event echoes the member, the book and
%% the start time, so this write rebuilds the whole row from its own
%% payload -- an absolute, idempotent write that never depends on the
%% started event having arrived first.
-module(reading_finished_v1_to_sqlite_readings).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"reading_finished_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO readings"
           " (reading_id, member_id, book_id, status, started_at, pages_read,"
           "  finished_at, event_id, version)"
           " VALUES (?, ?, ?, 'finished', ?, ?, ?, ?, ?)",
           [maps:get(reading_id, Data),
            maps:get(member_id, Data),
            maps:get(book_id, Data),
            maps:get(started_at, Data),
            maps:get(pages_read, Data),
            maps:get(finished_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
