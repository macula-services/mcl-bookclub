%% @doc Emitter: each `member_registered_v1' becomes one
%% `member_registered_v1' fact on the mesh.
%%
%% The only place this desk's event touches the mesh. The dispatch path
%% never waits for it: the fact goes out on the router's delivery, not the
%% caller's.
%%
%% TWO DELIBERATE CHOICES, each worth understanding before copying:
%%
%% - replay_policy/0 is `skip': a restart's replay of the store's history
%%   must not re-publish facts that already went out.
%%
%% - A failed publish is an ERROR RETURN, so evoq's retry machinery owns
%%   redelivery: lifecycle facts (unlike telemetry) are worth retrying --
%%   a consumer that missed "member registered" is missing state, not a
%%   sample. mcl-victron's emitter takes the other fork (live drops,
%%   counted) because a replayed telemetry reading misrepresents the now;
%%   a replayed registration does not misrepresent anything.
-module(emit_member_registered_v1_to_mesh).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"member_registered_v1">>].

replay_policy() -> skip.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    publish(mcl_bookclub_facts:to_wire(mcl_bookclub_facts:member_registered(Data)),
            State).

publish(Fact, State) ->
    case mcl_om:mesh_handles() of
        {ok, Pool, Realm} -> publish_on(Pool, Realm, Fact, State);
        {error, _} = Error -> Error
    end.

publish_on(Pool, Realm, Fact, State) ->
    case macula:publish(Pool, Realm,
                        mcl_bookclub_facts:topic(mcl_bookclub_facts:realm_name(),
                                                 member_registered),
                        Fact) of
        ok -> {ok, State};
        {error, _} = Error -> Error
    end.
