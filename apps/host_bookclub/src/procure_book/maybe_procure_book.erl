%% @doc Handler for `procure_book_v1'.
%%
%% The desk: one module that owns the business rule (a book is procured
%% once), produces the matching `book_procured_v1' event, and dispatches.
%% The aggregate calls handle_from_map/2; callers dispatch/1.
-module(maybe_procure_book).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% procure_book_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := procure_book_v1} = Payload) ->
    handled(State, procure_book_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a book is
%% procured exactly once. The already-retired refusal is the aggregate's
%% blanket guard, not this desk's.
-spec handle(book_state:t(), procure_book_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    procure_when_fresh(book_state:is_on_shelf(State), Cmd).

procure_when_fresh(true, _Cmd) ->
    {error, already_procured};
procure_when_fresh(false, Cmd) ->
    case procure_book_v1:validate(Cmd) of
        ok ->
            events(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(Cmd) ->
    {ok, Event} = book_procured_v1:new(#{
        book_id => procure_book_v1:get_book_id(Cmd),
        club_id => procure_book_v1:get_club_id(Cmd),
        title => procure_book_v1:get_title(Cmd),
        author => procure_book_v1:get_author(Cmd)}),
    {ok, [book_procured_v1:to_map(Event)]}.

%% @doc Procure the book on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(procure_book_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case procure_book_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(procure_book_v1, book_aggregate,
                               procure_book_v1:stream_id(Cmd),
                               procure_book_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
