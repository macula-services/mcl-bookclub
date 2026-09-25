%% @doc mcl-bookclub's public contract on the mesh: three facts.
%%
%%   member_registered_v1 on `<realm>/mcl-bookclub/bookclub/member/member_registered_v1'
%%   book_procured_v1    on `<realm>/mcl-bookclub/bookclub/book/book_procured_v1'
%%   book_retired_v1     on `<realm>/mcl-bookclub/bookclub/book/book_retired_v1'
%%
%% One topic per fact kind; the ids and names are in the payload, not the
%% topic name: a consumer subscribes once and filters.
%%
%% The domain event stays internal; what leaves is a FACT on the mesh, and
%% this module is the only place the two shapes meet (the emitter desks
%% translate, nobody else). Text travels as CBOR text, booleans as 1/0.
%%
%% This module and the emit_* desks are the ONLY host_bookclub modules that
%% may name the mesh SDK; the division-boundary test enforces it.
-module(mcl_bookclub_facts).

-export([member_registered/1, book_procured/1, book_retired/1,
         to_wire/1, topic/2, realm_name/0]).

-define(ORG, <<"mcl-bookclub">>).
-define(DOMAIN, <<"bookclub">>).
-define(VERSION, 1).

-define(MEMBER_FIELDS, [member_id, club_id, name, registered_at]).
-define(BOOK_FIELDS, [book_id, club_id, title, author, procured_at]).
-define(RETIRED_FIELDS, [book_id, club_id, title, author, retired_by, retired_at]).

%% @doc The fact for a registered event, whose keys may be atoms or binaries
%% (an event read back from the store is binary-keyed).
-spec member_registered(map()) -> map().
member_registered(Event) ->
    maps:from_list([{Field, field(Field, Event)} || Field <- ?MEMBER_FIELDS]).

-spec book_procured(map()) -> map().
book_procured(Event) ->
    maps:from_list([{Field, field(Field, Event)} || Field <- ?BOOK_FIELDS]).

-spec book_retired(map()) -> map().
book_retired(Event) ->
    maps:from_list([{Field, field(Field, Event)} || Field <- ?RETIRED_FIELDS]).

field(Field, Event) ->
    maps:get(Field, Event, maps:get(atom_to_binary(Field, utf8), Event, undefined)).

%% @doc Text as CBOR text, booleans as 1/0, numbers as they are.
-spec to_wire(term()) -> term().
to_wire(B) when is_binary(B) -> {text, B};
to_wire(true) -> 1;
to_wire(false) -> 0;
to_wire(L) when is_list(L) -> [to_wire(E) || E <- L];
to_wire(M) when is_map(M) -> maps:map(fun(_K, V) -> to_wire(V) end, M);
to_wire(Other) -> Other.

-spec topic(binary(), member_registered | book_procured | book_retired) -> binary().
topic(RealmName, member_registered) ->
    macula_topic:app_fact(RealmName, ?ORG, ?DOMAIN, <<"member">>,
                          <<"member_registered">>, ?VERSION);
topic(RealmName, book_procured) ->
    macula_topic:app_fact(RealmName, ?ORG, ?DOMAIN, <<"book">>,
                          <<"book_procured">>, ?VERSION);
topic(RealmName, book_retired) ->
    macula_topic:app_fact(RealmName, ?ORG, ?DOMAIN, <<"book">>,
                          <<"book_retired">>, ?VERSION).

%% @doc The realm whose name the topics carry: io.macula for this fleet.
%% (mcl-victron refuses to publish when this does not hash-match the pool's
%% realm -- a topic in another realm goes where nobody listens. That check
%% needs the pool, so the fleet hardening lives there; here the name is the
%% documented constant the topics are built from.)
-spec realm_name() -> binary().
realm_name() -> <<"io.macula">>.
