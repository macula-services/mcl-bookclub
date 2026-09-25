%% @doc Handler for `retire_book_v1'.
%%
%% The desk: one module that owns the business rule (a book retires only
%% once it is on the shelf), produces the matching `book_retired_v1' event,
%% and dispatches. The already-retired refusal is the aggregate's blanket
%% guard, not this desk's.
-module(maybe_retire_book).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% retire_book_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := retire_book_v1} = Payload) ->
    handled(State, retire_book_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a book can
%% only retire once it is on the shelf.
-spec handle(book_state:t(), retire_book_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    retire_when_on_shelf(book_state:is_on_shelf(State), State, Cmd).

retire_when_on_shelf(false, _State, _Cmd) ->
    {error, not_procured};
retire_when_on_shelf(true, State, Cmd) ->
    case retire_book_v1:validate(Cmd) of
        ok ->
            events(State, Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(State, Cmd) ->
    {ok, Event} = book_retired_v1:new(#{
        book_id => book_state:book_id(State),
        club_id => book_state:club_id(State),
        title => book_state:title(State),
        author => book_state:author(State),
        procured_at => book_state:procured_at(State),
        club_name => book_state:club_name(State),
        retired_by => retire_book_v1:get_retired_by(Cmd)}),
    {ok, [book_retired_v1:to_map(Event)]}.

%% @doc Retire the book on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(retire_book_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case retire_book_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(retire_book_v1, book_aggregate,
                               retire_book_v1:stream_id(Cmd),
                               retire_book_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
