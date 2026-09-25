%% @doc The member projections, end to end: registration and unregistration
%% flow through the real $all subscription into the members table, with the
%% row carrying the applied position at each step.
-module(member_registered_v1_to_sqlite_members_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

-define(SELECT,
        "SELECT member_id, club_id, name, status, registered_at, event_id, version"
        " FROM members WHERE member_id = ?").

store_test_() ->
    {setup,
     fun project_bookclub_test_env:start/0,
     fun project_bookclub_test_env:stop/1,
     [{timeout, 60, fun a_registered_member_is_projected/0},
      {timeout, 60, fun an_unregistered_member_moves_the_row/0}]}.

a_registered_member_is_projected() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    MemberId = register_member_v1:stream_id(Cmd),
    [MemberId, ClubId, <<"Bea">>, <<"active">>, At, _EventId, 0] =
        project_bookclub_test_env:await_row(?SELECT, [MemberId], 100),
    ?assert(is_integer(At)).

%% The unregistered event rewrites the row from its own self-contained
%% payload: the status flips and the applied position moves to the NEW
%% event, without the projection ever needing the registered event's data.
an_unregistered_member_moves_the_row() ->
    {ok, ClubId} = initiated_club(),
    {ok, Cmd} = member(ClubId, <<"Bea">>),
    {ok, 0, _} = maybe_register_member:dispatch(Cmd),
    MemberId = register_member_v1:stream_id(Cmd),
    project_bookclub_test_env:await_row(?SELECT, [MemberId], 100),
    {ok, UnregisterCmd} = unregister_member_v1:new(#{member_id => MemberId,
                                                    unregistered_by => <<"raf">>}),
    {ok, 1, _} = maybe_unregister_member:dispatch(UnregisterCmd),
    [Stored | _] = lists:reverse(project_bookclub_test_env:stream(MemberId)),
    [MemberId, ClubId, <<"Bea">>, <<"unregistered">>, _At, EventId, 1] =
        project_bookclub_test_env:await_row(?SELECT, [MemberId], 100),
    ?assertEqual(Stored#event.event_id, EventId),
    ?assertEqual(<<"member_unregistered_v1">>, Stored#event.event_type).

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
