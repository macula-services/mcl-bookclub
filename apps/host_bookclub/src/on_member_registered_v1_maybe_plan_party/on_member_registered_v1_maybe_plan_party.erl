%% @doc Policy: every fifth member registration plans a club party.
%%
%% A policy is a sibling slice of the target CMD app, reacting to a domain
%% event and dispatching a command to another aggregate -- here, from a
%% member's stream to the club's. It is an evoq_event_handler with its own
%% small state, NOT an evoq_process_manager: the rule has no per-process
%% instance to correlate (see the corpus's behaviour decision guide).
%%
%% TWO DELIBERATE CHOICES, each worth understanding before copying:
%%
%% - replay_policy/0 is `skip': this handler's effect is a command
%%   dispatch, and repeating it on replay would plan duplicate parties. A
%%   handler with side effects must declare skip; a projection whose write
%%   is idempotent declares deliver.
%%
%% - The counter lives in the handler's in-memory state. A restart resets
%%   it, so the party cadence is best-effort entertainment, not a business
%%   invariant. The honest home for a durable counter is the club's own
%%   stream (a tally event) -- the shape the corpus prefers for anything
%%   that must survive a restart.
-module(on_member_registered_v1_maybe_plan_party).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

-define(PARTY_EVERY, 5).

interested_in() -> [<<"member_registered_v1">>].

replay_policy() -> skip.

init(_Config) ->
    {ok, #{registrations => 0}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    Count = maps:get(registrations, State) + 1,
    case Count rem ?PARTY_EVERY of
        0 ->
            plan_party(maps:get(club_id, Data));
        _ ->
            ok
    end,
    {ok, State#{registrations => Count}}.

%% The dispatch result is the only error channel. A party that cannot be
%% planned (an archived club, a race with archive) is logged, not thrown:
%% the policy must never take the delivery of every later event down with
%% it, and the club's own stream is the authority on whether a party
%% exists, not this handler.
plan_party(ClubId) ->
    case plan_party_v1:new(#{club_id => ClubId}) of
        {ok, Cmd} -> dispatch_party(Cmd);
        {error, Reason} -> warn_party(ClubId, Reason)
    end.

dispatch_party(Cmd) ->
    case maybe_plan_party:dispatch(Cmd) of
        {ok, _, _} -> ok;
        {error, Reason} -> warn_party(plan_party_v1:stream_id(Cmd), Reason)
    end.

warn_party(ClubId, Reason) ->
    logger:warning(#{what => party_not_planned,
                     club_id => ClubId,
                     reason => Reason}).
