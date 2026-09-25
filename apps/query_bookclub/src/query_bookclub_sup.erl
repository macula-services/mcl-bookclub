%% @doc Supervises the QRY division: the sqlite query store.
%%
%% One child today. Every later query desk is a pure module answered by the
%% store, not a process -- the desks hold no state of their own.
-module(query_bookclub_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SqlitePath = filename:join(data_dir(), "bookclub.sqlite3"),
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [
        #{id => bookclub_query_store,
          start => {bookclub_query_store, start_link, [SqlitePath]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [bookclub_query_store]}
    ]}}.

%% The same variable the facade's data_dir/0 reads, with the same default;
%% a test in the facade pins the three together so they cannot drift.
data_dir() ->
    chosen(os:getenv("MCL_DATA_DIR")).

chosen(false) -> "/tmp/mcl_bookclub";
chosen("")    -> "/tmp/mcl_bookclub";
chosen(Path)  -> Path.
