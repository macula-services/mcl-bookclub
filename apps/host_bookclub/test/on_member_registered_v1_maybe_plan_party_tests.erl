%% @doc The plan_party policy, end to end: member registrations flow through
%% the real $all subscription to the policy handler, and every fifth one
%% dispatches plan_party_v1 to the club's stream.
%%
%% The policy is an evoq_event_handler with a counter in its own state --
%% the shape the house rules give a cross-aggregate reaction that has no
%% per-process instance to correlate.
-module(on_member_registered_v1_maybe_plan_party_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

store_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [{timeout, 60, fun every_fifth_registration_plans_a_party/0},
      {timeout, 60, fun four_registrations_plan_nothing/0}]}.

every_fifth_registration_plans_a_party() ->
    {ok, ClubId} = initiated_club(),
    register_members(ClubId, 5),
    [Party | _] = await_party(ClubId, 100),
    ?assertEqual(1, maps:get(parties_planned, Party#event.data)).

four_registrations_plan_nothing() ->
    {ok, ClubId} = initiated_club(),
    register_members(ClubId, 4),
    timer:sleep(300),
    ?assertEqual([], parties_on(ClubId)).

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

register_members(ClubId, Count) ->
    lists:foreach(
      fun(_) ->
              {ok, Cmd} = register_member_v1:new(
                            #{member_id => register_member_v1:mint_member_id(),
                              club_id => ClubId,
                              name => <<"Bea">>}),
              {ok, 0, _} = maybe_register_member:dispatch(Cmd)
      end, lists:seq(1, Count)).

await_party(_ClubId, 0) -> error(no_party_planned);
await_party(ClubId, Tries) ->
    case parties_on(ClubId) of
        [Party | _] -> [Party];
        [] -> timer:sleep(100), await_party(ClubId, Tries - 1)
    end.

parties_on(ClubId) ->
    [E || E <- host_bookclub_test_store:stream(ClubId),
          E#event.event_type =:= <<"party_planned_v1">>].

setup() ->
    {Dir, Started} = host_bookclub_test_store:start(),
    {ok, Sub} = evoq_store_subscription:start_link(host_bookclub_test_store:store()),
    unlink(Sub),
    {ok, Pm} = evoq_event_handler:start_link(on_member_registered_v1_maybe_plan_party, #{}),
    unlink(Pm),
    {Dir, Started, Sub, Pm}.

cleanup({Dir, Started, Sub, Pm}) ->
    exit(Pm, shutdown),
    exit(Sub, shutdown),
    host_bookclub_test_store:stop({Dir, Started}).
