%% @doc Projects book_procured_v1 into the books table.
%%
%% The same idempotent shape as the other projections: INSERT OR REPLACE
%% keyed on the stream id, status computed here, and the row carrying the
%% applied position (event_id, version).
-module(book_procured_v1_to_sqlite_books).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"book_procured_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO books"
           " (book_id, club_id, title, author, status, procured_at, event_id, version)"
           " VALUES (?, ?, ?, ?, 'on_shelf', ?, ?, ?)",
           [maps:get(book_id, Data),
            maps:get(club_id, Data),
            maps:get(title, Data),
            maps:get(author, Data),
            maps:get(procured_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
