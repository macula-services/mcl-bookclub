%% @doc archive_bookclub against a real reckon-db store through evoq.
%%
%% The same store host_bookclub_test_store opens for every CMD desk suite:
%% the dispatch, the aggregate, the event and its stream are the ones a
%% running node has.
-module(archive_bookclub_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun an_initiated_club_is_archived/0},
      {timeout, 60, fun a_second_archive_is_refused/0},
      {timeout, 60, fun an_unborn_club_cannot_be_archived/0},
      {timeout, 60, fun an_archived_club_refuses_initiation/0},
      {timeout, 60, fun a_rejected_stream_id_never_touches_the_store/0}]}.

pure_test_() ->
    [fun a_command_needs_every_field/0,
     fun the_state_folds_the_archived_event/0].

%% The archived event is self-contained: it echoes the club's birth details
%% from the aggregate state, so its projection can rebuild the whole row
%% from this event alone.
an_initiated_club_is_archived() ->
    {ok, ClubId} = initiated_club(),
    {ok, 1, _} = archive(ClubId),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(ClubId)),
    ?assertEqual(<<"bookclub_archived_v1">>, Stored#event.event_type),
    Data = Stored#event.data,
    ?assertEqual(<<"The Crooked Shelf">>, maps:get(name, Data)),
    ?assertEqual(<<"bea">>, maps:get(initiated_by, Data)),
    ?assert(is_integer(maps:get(initiated_at, Data))),
    ?assertEqual(<<"raf">>, maps:get(archived_by, Data)).

%% A second archive is refused by the aggregate's blanket lifecycle guard,
%% which owns every refusal on an archived stream: `{error, archived}',
%% the same answer any other command would get.
a_second_archive_is_refused() ->
    {ok, ClubId} = initiated_club(),
    {ok, 1, _} = archive(ClubId),
    ?assertEqual({error, archived}, archive(ClubId)).

%% The desk's rule, distinct from the aggregate's blanket guard: a club
%% that was never initiated cannot be archived either.
an_unborn_club_cannot_be_archived() ->
    ClubId = initiate_bookclub_v1:mint_club_id(),
    ?assertEqual({error, not_initiated}, archive(ClubId)).

%% The aggregate's blanket lifecycle guard: once archived, EVERY command on
%% the stream is refused -- even the one that would otherwise be fine.
an_archived_club_refuses_initiation() ->
    {ok, ClubId} = initiated_club(),
    {ok, 1, _} = archive(ClubId),
    ?assertEqual({error, archived}, initiate_again(ClubId)).

a_rejected_stream_id_never_touches_the_store() ->
    {ok, Cmd} = archive_bookclub_v1:new(
                  #{club_id => <<"the-crooked-shelf">>, archived_by => <<"raf">>}),
    ?assertMatch({error, _}, maybe_archive_bookclub:dispatch(Cmd)),
    ?assertError({invalid_stream_id, _},
                 host_bookclub_test_store:stream(<<"the-crooked-shelf">>)).

a_command_needs_every_field() ->
    ?assertEqual({error, missing_required_fields},
                 archive_bookclub_v1:new(#{club_id => <<"bookclub-x">>})),
    ?assertEqual({error, invalid_params},
                 archive_bookclub_v1:new(#{club_id => <<"bookclub-x">>,
                                           archived_by => <<>>})).

the_state_folds_the_archived_event() ->
    S0 = bookclub_state:apply_event(bookclub_state:new(<<"bookclub-10">>),
                                    #{event_type => <<"bookclub_initiated_v1">>,
                                      name => <<"N">>, initiated_by => <<"bea">>,
                                      initiated_at => 5}),
    ?assertNot(bookclub_state:is_archived(S0)),
    S1 = bookclub_state:apply_event(S0, #{event_type => <<"bookclub_archived_v1">>}),
    ?assert(bookclub_state:is_archived(S1)),
    ?assert(bookclub_state:is_initiated(S1)),
    %% The archive changes the flag, nothing else: the birth details survive
    %% so a later event can still echo them.
    ?assertEqual(<<"N">>, bookclub_state:name(S1)),
    ?assertEqual(<<"bea">>, bookclub_state:initiated_by(S1)),
    ?assertEqual(5, bookclub_state:initiated_at(S1)).

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

archive(ClubId) ->
    {ok, Cmd} = archive_bookclub_v1:new(#{club_id => ClubId, archived_by => <<"raf">>}),
    maybe_archive_bookclub:dispatch(Cmd).

initiate_again(ClubId) ->
    {ok, Cmd} = initiate_bookclub_v1:new(
                  #{club_id => ClubId, name => <<"Again">>, initiated_by => <<"bea">>}),
    maybe_initiate_bookclub:dispatch(Cmd).
