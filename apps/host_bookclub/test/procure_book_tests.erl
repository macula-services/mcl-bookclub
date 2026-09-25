%% @doc procure_book and retire_book against a real reckon-db store through
%% evoq.
%%
%% The store is opened by host_bookclub_test_store with the same call the
%% facade's boot makes for this service.
-module(procure_book_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun a_book_is_procured_on_its_own_stream/0},
      {timeout, 60, fun a_second_procurement_is_refused/0},
      {timeout, 60, fun a_procured_book_is_retired/0},
      {timeout, 60, fun a_retired_book_refuses_every_command/0},
      {timeout, 60, fun an_unprocured_book_cannot_be_retired/0},
      {timeout, 60, fun a_rejected_stream_id_never_touches_the_store/0}]}.

pure_test_() ->
    [fun a_command_needs_every_field/0,
     fun the_state_folds_both_events/0].

a_book_is_procured_on_its_own_stream() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, [Event]} = maybe_procure_book:dispatch(Cmd),
    ?assertMatch(#{title := <<"Project Hail Mary">>, author := <<"Andy Weir">>}, Event),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(procure_book_v1:stream_id(Cmd))),
    ?assertEqual(<<"book_procured_v1">>, Stored#event.event_type),
    ?assertEqual(<<"Project Hail Mary">>, maps:get(title, Stored#event.data)).

a_second_procurement_is_refused() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    ?assertEqual({error, already_procured}, maybe_procure_book:dispatch(Cmd)).

%% The retired event is self-contained: it echoes the bibliographic facts
%% from the aggregate state.
a_procured_book_is_retired() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    BookId = procure_book_v1:stream_id(Cmd),
    {ok, 1, _} = retire(BookId),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(BookId)),
    ?assertEqual(<<"book_retired_v1">>, Stored#event.event_type),
    Data = Stored#event.data,
    ?assertEqual(<<"Project Hail Mary">>, maps:get(title, Data)),
    ?assertEqual(ClubId, maps:get(club_id, Data)),
    ?assertEqual(<<"raf">>, maps:get(retired_by, Data)).

%% The aggregate's blanket lifecycle guard: once retired, EVERY command on
%% the stream is refused -- procuring again included.
a_retired_book_refuses_every_command() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = book(ClubId),
    {ok, 0, _} = maybe_procure_book:dispatch(Cmd),
    BookId = procure_book_v1:stream_id(Cmd),
    {ok, 1, _} = retire(BookId),
    ?assertEqual({error, retired}, maybe_procure_book:dispatch(Cmd)),
    ?assertEqual({error, retired}, retire(BookId)).

an_unprocured_book_cannot_be_retired() ->
    ?assertEqual({error, not_procured},
                 retire(procure_book_v1:mint_book_id())).

a_rejected_stream_id_never_touches_the_store() ->
    {ok, Cmd} = procure_book_v1:new(
                  #{book_id => <<"project-hail-mary">>,
                    club_id => initiate_bookclub_v1:mint_club_id(),
                    title => <<"Project Hail Mary">>,
                    author => <<"Andy Weir">>}),
    ?assertMatch({error, _}, maybe_procure_book:dispatch(Cmd)),
    ?assertError({invalid_stream_id, _},
                 host_bookclub_test_store:stream(<<"project-hail-mary">>)).

a_command_needs_every_field() ->
    ?assertEqual({error, missing_required_fields},
                 procure_book_v1:new(#{book_id => <<"book-x">>,
                                       club_id => <<"bookclub-x">>,
                                       title => <<"T">>})),
    ?assertEqual({error, invalid_params},
                 procure_book_v1:new(#{book_id => <<"book-x">>,
                                       club_id => <<"bookclub-x">>,
                                       title => <<>>,
                                       author => <<"A">>})).

the_state_folds_both_events() ->
    S0 = book_state:new(<<"book-30">>),
    ?assertNot(book_state:is_on_shelf(S0)),
    S1 = book_state:apply_event(S0, #{event_type => <<"book_procured_v1">>,
                                      club_id => <<"bookclub-30">>,
                                      title => <<"Project Hail Mary">>,
                                      author => <<"Andy Weir">>,
                                      procured_at => 5}),
    ?assert(book_state:is_on_shelf(S1)),
    S2 = book_state:apply_event(S1, #{event_type => <<"book_retired_v1">>}),
    ?assert(book_state:is_retired(S2)),
    %% The retire changes the flag, nothing else: the birth details survive
    %% so a later event can still echo them.
    ?assertEqual(<<"Project Hail Mary">>, book_state:title(S2)),
    ?assertEqual(5, book_state:procured_at(S2)).

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

retire(BookId) ->
    {ok, Cmd} = retire_book_v1:new(#{book_id => BookId, retired_by => <<"raf">>}),
    maybe_retire_book:dispatch(Cmd).
