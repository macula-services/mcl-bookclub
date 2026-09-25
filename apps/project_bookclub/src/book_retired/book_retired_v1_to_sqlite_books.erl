%% @doc Projects book_retired_v1 into the books table.
%%
%% Self-contained like the other soft-delete projections: the event echoes
%% the bibliographic facts, so this write never depends on the procured
%% event having arrived first. The status string comes from
%% book_status:to_string/1 -- never a literal of this file's own.
-module(book_retired_v1_to_sqlite_books).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"book_retired_v1">>].

replay_policy() -> deliver.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case bookclub_read_model_store:exec(
           "INSERT OR REPLACE INTO books"
           " (book_id, club_id, title, author, status, procured_at, event_id, version)"
           " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
           [maps:get(book_id, Data),
            maps:get(club_id, Data),
            maps:get(title, Data),
            maps:get(author, Data),
            book_status:to_string(book_status:retired()),
            maps:get(procured_at, Data),
            maps:get(event_id, Event),
            maps:get(version, Event, 0)]) of
        ok ->
            {ok, State};
        {error, Reason} ->
            {error, {store_error, Reason}}
    end.
