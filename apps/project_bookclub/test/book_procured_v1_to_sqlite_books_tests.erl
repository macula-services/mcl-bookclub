%% @doc The book projections, end to end: procurement and retirement flow
%% through the real $all subscription into the books table, with the row
%% carrying the applied position at each step.
-module(book_procured_v1_to_sqlite_books_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(SELECT,
        "SELECT book_id, club_id, title, author, status, procured_at, event_id, version"
        " FROM books WHERE book_id = ?").

store_test_() ->
    {setup,
     fun project_bookclub_test_env:start/0,
     fun project_bookclub_test_env:stop/1,
     [{timeout, 60, fun a_procured_book_is_projected/0},
      {timeout, 60, fun a_retired_book_moves_the_row/0}]}.

a_procured_book_is_projected() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    BookId = procure_book_v1:stream_id(Cmd),
    [BookId, ClubId, <<"Project Hail Mary">>, <<"Andy Weir">>, <<"on_shelf">>,
     At, _EventId, 0] =
        project_bookclub_test_env:await_row(?SELECT, [BookId], 100),
    ?assert(is_integer(At)).

%% The retired event rewrites the row from its own self-contained payload:
%% the status flips and the applied position moves to the NEW event.
a_retired_book_moves_the_row() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    BookId = procure_book_v1:stream_id(Cmd),
    project_bookclub_test_env:await_row(?SELECT, [BookId], 100),
    {ok, RetireCmd} = retire_book_v1:new(#{book_id => BookId, retired_by => <<"raf">>}),
    {ok, 1, _} = maybe_retire_book:dispatch(RetireCmd),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(BookId)),
    [BookId, ClubId, <<"Project Hail Mary">>, <<"Andy Weir">>, <<"retired">>,
     _At, EventId, 1] =
        project_bookclub_test_env:await_row(?SELECT, [BookId], 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(<<"book_retired_v1">>, Stored#event.event_type).

%%============================================================================
%% Helpers
%%============================================================================

initiated_club() ->
    {ok, Cmd} = initiate_bookclub_v1:new(
                  #{club_id => initiate_bookclub_v1:mint_club_id(),
                    name => <<"The Crooked Shelf">>,
                    initiated_by => <<"bea">>}),
    {ok, 0, _} = maybe_initiate_bookclub:dispatch(Cmd),
    {ok, initiate_bookclub_v1:stream_id(Cmd)}.

book(ClubId) ->
    procure_book_v1:new(#{book_id => procure_book_v1:mint_book_id(),
                          club_id => ClubId,
                          title => <<"Project Hail Mary">>,
                          author => <<"Andy Weir">>}).
