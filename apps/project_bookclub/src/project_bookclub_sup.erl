%% @doc Supervises the PRJ division: the sqlite read-model store and one
%% evoq_event_handler child per projection desk.
%%
%% The projection registers itself with evoq's event-type registry when it
%% starts; delivery comes from the store subscription the facade boots, so
%% this supervisor never touches the store or the adapter.
-module(project_bookclub_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SqlitePath = filename:join(data_dir(), "bookclub.sqlite3"),
    %% The store FIRST: a projection child crashing is restarted against
    %% a store that exists.
    Store = #{id => bookclub_read_model_store,
              start => {bookclub_read_model_store, start_link, [SqlitePath]},
              restart => permanent,
              shutdown => 5000,
              type => worker,
              modules => [bookclub_read_model_store]},
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10},
          [Store | [projection_child(P) || P <- projections()]]}}.

projections() ->
    [bookclub_initiated_v1_to_sqlite_clubs,
     bookclub_archived_v1_to_sqlite_clubs,
     member_registered_v1_to_sqlite_members,
     member_unregistered_v1_to_sqlite_members,
     book_procured_v1_to_sqlite_books,
     book_retired_v1_to_sqlite_books,
     reading_started_v1_to_sqlite_readings,
     reading_finished_v1_to_sqlite_readings].

%% One evoq_event_handler per projection desk, its id the projection module.
projection_child(Projection) ->
    #{id => Projection,
      start => {evoq_event_handler, start_link, [Projection, #{}]},
      restart => permanent,
      shutdown => 5000,
      type => worker,
      modules => [evoq_event_handler]}.

%% The same variable the facade's data_dir/0 reads, with the same default;
%% a test in the facade pins the three together so they cannot drift.
data_dir() ->
    chosen(os:getenv("MCL_DATA_DIR")).

chosen(false) -> "/tmp/mcl_bookclub";
chosen("")    -> "/tmp/mcl_bookclub";
chosen(Path)  -> Path.
