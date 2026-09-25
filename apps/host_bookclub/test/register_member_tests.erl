%% @doc register_member and unregister_member against a real reckon-db
%% store through evoq.
%%
%% The store is opened by host_bookclub_test_store with the same call the
%% facade's boot makes for this service.
-module(register_member_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun a_member_is_registered_on_its_own_stream/0},
      {timeout, 60, fun a_second_registration_is_refused/0},
      {timeout, 60, fun a_registered_member_is_unregistered/0},
      {timeout, 60, fun an_unregistered_member_refuses_every_command/0},
      {timeout, 60, fun an_unborn_member_cannot_be_unregistered/0},
      {timeout, 60, fun a_rejected_stream_id_never_touches_the_store/0}]}.

pure_test_() ->
    [fun a_command_needs_every_field/0,
     fun the_state_folds_both_events/0].

a_member_is_registered_on_its_own_stream() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, [Event]} = maybe_register_member:dispatch(Cmd),
    ?assertMatch(#{name := <<"Bea">>, club_id := ClubId}, Event),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(register_member_v1:stream_id(Cmd))),
    ?assertEqual(<<"member_registered_v1">>, Stored#event.event_type),
    ?assertEqual(<<"Bea">>, maps:get(name, Stored#event.data)).

a_second_registration_is_refused() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    ?assertEqual({error, already_registered}, maybe_register_member:dispatch(Cmd)).

%% The unregistered event is self-contained: it echoes the member's club,
%% name and registration time from the aggregate state.
a_registered_member_is_unregistered() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    MemberId = register_member_v1:stream_id(Cmd),
    {ok, 1, _} = unregister_m(MemberId),
    [Stored | _] = lists:reverse(host_bookclub_test_store:stream(MemberId)),
    ?assertEqual(<<"member_unregistered_v1">>, Stored#event.event_type),
    Data = Stored#event.data,
    ?assertEqual(<<"Bea">>, maps:get(name, Data)),
    ?assertEqual(ClubId, maps:get(club_id, Data)),
    ?assertEqual(<<"raf">>, maps:get(unregistered_by, Data)).

%% The aggregate's blanket lifecycle guard: once unregistered, EVERY
%% command on the stream is refused -- registering again included.
an_unregistered_member_refuses_every_command() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    MemberId = register_member_v1:stream_id(Cmd),
    {ok, 1, _} = unregister_m(MemberId),
    ?assertEqual({error, unregistered}, maybe_register_member:dispatch(Cmd)),
    ?assertEqual({error, unregistered}, unregister_m(MemberId)).

an_unborn_member_cannot_be_unregistered() ->
    ?assertEqual({error, not_registered},
                 unregister_m(register_member_v1:mint_member_id())).

a_rejected_stream_id_never_touches_the_store() ->
    {ok, Cmd} = register_member_v1:new(
                  #{member_id => <<"bea-the-member">>,
                    club_id => initiate_bookclub_v1:mint_club_id(),
                    name => <<"Bea">>}),
    ?assertMatch({error, _}, maybe_register_member:dispatch(Cmd)),
    ?assertError({invalid_stream_id, _},
                 host_bookclub_test_store:stream(<<"bea-the-member">>)).

a_command_needs_every_field() ->
    ?assertEqual({error, missing_required_fields},
                 register_member_v1:new(#{member_id => <<"member-x">>,
                                          club_id => <<"bookclub-x">>})),
    ?assertEqual({error, invalid_params},
                 register_member_v1:new(#{member_id => <<"member-x">>,
                                          club_id => <<"bookclub-x">>,
                                          name => <<>>})).

the_state_folds_both_events() ->
    S0 = member_state:new(<<"member-10">>),
    ?assertNot(member_state:is_registered(S0)),
    S1 = member_state:apply_event(S0, #{event_type => <<"member_registered_v1">>,
                                        club_id => <<"bookclub-10">>,
                                        name => <<"Bea">>,
                                        registered_at => 5}),
    ?assert(member_state:is_registered(S1)),
    ?assertEqual(<<"Bea">>, member_state:name(S1)),
    S2 = member_state:apply_event(S1, #{event_type => <<"member_unregistered_v1">>}),
    ?assert(member_state:is_unregistered(S2)),
    ?assert(member_state:is_registered(S2)),
    %% The unregister changes the flag, nothing else: the birth details
    %% survive so a later event can still echo them.
    ?assertEqual(<<"Bea">>, member_state:name(S2)),
    ?assertEqual(<<"bookclub-10">>, member_state:club_id(S2)),
    ?assertEqual(5, member_state:registered_at(S2)).

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

member(ClubId, Name) ->
    register_member_v1:new(#{member_id => register_member_v1:mint_member_id(),
                             club_id => ClubId,
                             name => Name}).

unregister_m(MemberId) ->
    {ok, Cmd} = unregister_member_v1:new(#{member_id => MemberId,
                                           unregistered_by => <<"raf">>}),
    maybe_unregister_member:dispatch(Cmd).
