%% @doc start_reading and finish_reading against a real reckon-db store
%% through evoq.
%%
%% The reading is the child aggregate: the reading id is minted on the
%% member's side, the reading initiates itself, and the finished event
%% echoes the fold (member, book, start time) so its projection stays
%% self-contained.
-module(start_reading_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun a_reading_is_started_on_its_own_stream/0},
      {timeout, 60, fun a_second_start_is_refused/0},
      {timeout, 60, fun a_finished_reading_carries_the_fold/0},
      {timeout, 60, fun a_finished_reading_refuses_every_command/0},
      {timeout, 60, fun an_unstarted_reading_cannot_be_finished/0},
      {timeout, 60, fun a_rejected_stream_id_never_touches_the_store/0}]}.

pure_test_() ->
    [fun a_command_needs_every_field/0,
     fun the_state_folds_both_events/0].

a_reading_is_started_on_its_own_stream() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, Cmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                       member_id => MemberId,
                                       book_id => BookId}),
    {ok, 0, [Event]} = maybe_start_reading:dispatch(Cmd),
    ?assertMatch(#{member_id := MemberId, book_id := BookId}, Event),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(ReadingId)),
    ?assertEqual(<<"reading_started_v1">>, Stored#event.event_type).

a_second_start_is_refused() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, Cmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                       member_id => MemberId,
                                       book_id => BookId}),
    {ok, 0, _} = maybe_start_reading:dispatch(Cmd),
    ?assertEqual({error, already_started}, maybe_start_reading:dispatch(Cmd)).

%% The finished event echoes the fold -- member, book, start time -- so its
%% projection rebuilds the row from this event alone.
a_finished_reading_carries_the_fold() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, StartCmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                            member_id => MemberId,
                                            book_id => BookId}),
    {ok, 0, _} = maybe_start_reading:dispatch(StartCmd),
    {ok, 1, _} = finish(ReadingId, 476),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(ReadingId)),
    ?assertEqual(<<"reading_finished_v1">>, Stored#event.event_type),
    Data = Stored#event.data,
    ?assertEqual(MemberId, maps:get(member_id, Data)),
    ?assertEqual(BookId, maps:get(book_id, Data)),
    ?assertEqual(476, maps:get(pages_read, Data)),
    ?assert(is_integer(maps:get(started_at, Data))).

%% The aggregate's blanket lifecycle guard: once finished, EVERY command on
%% the stream is refused -- starting again included.
a_finished_reading_refuses_every_command() ->
    {ok, ReadingId, MemberId, BookId} = reading_ids(),
    {ok, StartCmd} = start_reading_v1:new(#{reading_id => ReadingId,
                                            member_id => MemberId,
                                            book_id => BookId}),
    {ok, 0, _} = maybe_start_reading:dispatch(StartCmd),
    {ok, 1, _} = finish(ReadingId, 100),
    ?assertEqual({error, finished}, maybe_start_reading:dispatch(StartCmd)),
    ?assertEqual({error, finished}, finish(ReadingId, 100)).

an_unstarted_reading_cannot_be_finished() ->
    ?assertEqual({error, not_started},
                 finish(start_reading_v1:mint_reading_id(), 100)).

a_rejected_stream_id_never_touches_the_store() ->
    {ok, Cmd} = start_reading_v1:new(
                  #{reading_id => <<"the-reading">>,
                    member_id => register_member_v1:mint_member_id(),
                    book_id => procure_book_v1:mint_book_id()}),
    ?assertMatch({error, _}, maybe_start_reading:dispatch(Cmd)),
    ?assertError({invalid_stream_id, _},
                 host_bookclub_test_store:stream(<<"the-reading">>)).

a_command_needs_every_field() ->
    ?assertEqual({error, missing_required_fields},
                 start_reading_v1:new(#{reading_id => <<"reading-x">>,
                                        member_id => <<"member-x">>})),
    ?assertEqual({error, invalid_params},
                 finish_reading_v1:new(#{reading_id => <<"reading-x">>,
                                         pages_read => -1})).

the_state_folds_both_events() ->
    S0 = reading_state:new(<<"reading-40">>),
    ?assertNot(reading_state:is_in_progress(S0)),
    S1 = reading_state:apply_event(S0, #{event_type => <<"reading_started_v1">>,
                                         member_id => <<"member-40">>,
                                         book_id => <<"book-40">>,
                                         started_at => 5}),
    ?assert(reading_state:is_in_progress(S1)),
    S2 = reading_state:apply_event(S1, #{event_type => <<"reading_finished_v1">>,
                                         pages_read => 476}),
    ?assert(reading_state:is_finished(S2)),
    ?assertEqual(476, reading_state:pages_read(S2)),
    %% The finish changes the pages and the flag, nothing else: the fold
    %% details survive for any later event to echo.
    ?assertEqual(<<"member-40">>, reading_state:member_id(S2)),
    ?assertEqual(<<"book-40">>, reading_state:book_id(S2)),
    ?assertEqual(5, reading_state:started_at(S2)).

%%============================================================================
%% Helpers
%%============================================================================

reading_ids() ->
    {ok, start_reading_v1:mint_reading_id(),
     register_member_v1:mint_member_id(),
     procure_book_v1:mint_book_id()}.

finish(ReadingId, Pages) ->
    {ok, Cmd} = finish_reading_v1:new(#{reading_id => ReadingId,
                                        pages_read => Pages}),
    maybe_finish_reading:dispatch(Cmd).
