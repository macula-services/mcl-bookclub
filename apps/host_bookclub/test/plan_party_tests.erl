%% @doc plan_party against a real reckon-db store through evoq.
%%
%% The count lives in the club's aggregate state, incremented there and
%% echoed into the event as the new absolute value -- a consumer folds the
%% count by assignment, never by increment.
-module(plan_party_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun a_party_is_planned_with_the_incremented_count/0},
      {timeout, 60, fun an_unborn_club_cannot_plan_a_party/0},
      {timeout, 60, fun an_archived_club_cannot_plan_a_party/0}]}.

pure_test_() ->
    [fun the_state_folds_the_party_event/0].

a_party_is_planned_with_the_incremented_count() ->
    {ok, ClubId} = initiated_club(),
    {ok, 1, [First]} = plan(ClubId),
    ?assertMatch(#{parties_planned := 1}, First),
    {ok, 2, [Second]} = plan(ClubId),
    ?assertMatch(#{parties_planned := 2}, Second),
    %% Reversed, the stream reads newest first: the two parties, then the
    %% initiation.
    [Party2, Party1 | _] = lists:reverse(host_bookclub_test_store:stream(ClubId)),
    ?assertEqual(1, maps:get(parties_planned, Party1#event.data)),
    ?assertEqual(2, maps:get(parties_planned, Party2#event.data)).

an_unborn_club_cannot_plan_a_party() ->
    ?assertEqual({error, not_initiated}, plan(initiate_bookclub_v1:mint_club_id())).

%% The aggregate's blanket lifecycle guard owns this refusal, like every
%% other command on an archived stream.
an_archived_club_cannot_plan_a_party() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = archive_bookclub_v1:new(#{club_id => ClubId, archived_by => <<"raf">>}),
    {ok, 1, _} = maybe_archive_bookclub:dispatch(Cmd),
    ?assertEqual({error, archived}, plan(ClubId)).

the_state_folds_the_party_event() ->
    S0 = bookclub_state:apply_event(bookclub_state:new(<<"bookclub-20">>),
                                    #{event_type => <<"bookclub_initiated_v1">>,
                                      name => <<"N">>, initiated_by => <<"bea">>,
                                      initiated_at => 5}),
    ?assertEqual(0, bookclub_state:parties_planned(S0)),
    S1 = bookclub_state:apply_event(S0, #{event_type => <<"party_planned_v1">>,
                                          parties_planned => 3}),
    ?assertEqual(3, bookclub_state:parties_planned(S1)),
    %% The fold is an absolute assignment: applying the same event twice
    %% still says 3.
    S2 = bookclub_state:apply_event(S1, #{event_type => <<"party_planned_v1">>,
                                          parties_planned => 3}),
    ?assertEqual(3, bookclub_state:parties_planned(S2)).

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

plan(ClubId) ->
    {ok, Cmd} = plan_party_v1:new(#{club_id => ClubId}),
    maybe_plan_party:dispatch(Cmd).
