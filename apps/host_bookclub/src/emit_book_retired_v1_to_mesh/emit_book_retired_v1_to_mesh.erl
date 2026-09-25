%% @doc Emitter: each `book_retired_v1' becomes one `book_retired_v1'
%% fact on the mesh.
%%
%% Same choices as emit_member_registered_v1_to_mesh: replay_policy skip
%% (a replay must not re-publish), and a failed publish is an error return
%% so evoq's retry machinery owns redelivery of this lifecycle fact.
-module(emit_book_retired_v1_to_mesh).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4, replay_policy/0]).

interested_in() -> [<<"book_retired_v1">>].

replay_policy() -> skip.

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    publish(mcl_bookclub_facts:to_wire(mcl_bookclub_facts:book_retired(Data)),
            State).

publish(Fact, State) ->
    case mcl_om:mesh_handles() of
        {ok, Pool, Realm} -> publish_on(Pool, Realm, Fact, State);
        {error, _} = Error -> Error
    end.

publish_on(Pool, Realm, Fact, State) ->
    case macula:publish(Pool, Realm,
                        mcl_bookclub_facts:topic(mcl_bookclub_facts:realm_name(),
                                                 book_retired),
                        Fact) of
        ok -> {ok, State};
        {error, _} = Error -> Error
    end.
