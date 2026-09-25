%% @doc The mesh face of get_bookclub_by_id, advertised as
%% `mcl-bookclub/get_bookclub_by_id'.
%%
%% The capability handler -- the one place the QRY desk's answer crosses
%% onto the mesh. The desk stays pure (no mesh, no wire); this module
%% adapts between the wire and it: parameters arrive atom-keyed or
%% binary-keyed or CBOR-text-wrapped (all three exist in the wild), and the
%% reply's text goes back out as CBOR text.
-module(mcl_bookclub_get_bookclub_by_id).

-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, undefined}.

handle_request(Payload, State) ->
    ClubId = mcl_om_wire:unwrap(mcl_om_wire:field(club_id, Payload)),
    replied(get_bookclub_by_id:find(ClubId), State).

replied({ok, Club}, State) ->
    {reply, to_wire(Club), State};
replied({error, Reason}, State) ->
    {error, Reason, State}.

to_wire(B) when is_binary(B) -> {text, B};
to_wire(true) -> 1;
to_wire(false) -> 0;
to_wire(M) when is_map(M) -> maps:map(fun(_K, V) -> to_wire(V) end, M);
to_wire(Other) -> Other.
