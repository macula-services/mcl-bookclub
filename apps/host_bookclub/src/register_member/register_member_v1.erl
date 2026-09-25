%% @doc The register_member_v1 command: a person joins the club.
%%
%% The command names the member's stream id (minted, never derived from the
%% human name), the club being joined, and the member's name. The payload
%% keys are ATOMS -- evoq reads command_type with an atom lookup.
-module(register_member_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([mint_member_id/0, stream_id/1, get_member_id/1, get_club_id/1, get_name/1]).

-record(register_member, {
    member_id :: binary(),
    club_id :: binary(),
    name :: binary()
}).

-opaque t() :: #register_member{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> register_member_v1.

%% @doc Mint the member's stream id. The AggregateId IS the reckon stream id
%% (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the human name goes in the payload and
%% this derived id is what the command is addressed to.
-spec mint_member_id() -> binary().
mint_member_id() ->
    reckon_gater_stream_id:new(<<"member">>).

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{member_id := MemberId, club_id := ClubId, name := Name}) ->
    record_when(is_binary(MemberId), MemberId =/= <<>>,
                is_binary(ClubId), ClubId =/= <<>>,
                is_binary(Name), Name =/= <<>>,
                MemberId, ClubId, Name);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, true, true, MemberId, ClubId, Name) ->
    {ok, #register_member{member_id = MemberId, club_id = ClubId, name = Name}};
record_when(_, _, _, _, _, _, _, _, _) ->
    {error, invalid_params}.

%% @doc Checks about the world, not the shape: both stream ids must satisfy
%% the reckon-db stream contract.
-spec validate(t()) -> ok | {error, term()}.
validate(#register_member{member_id = MemberId, club_id = ClubId}) ->
    case {reckon_gater_stream_id:validate(MemberId),
          reckon_gater_stream_id:validate(ClubId)} of
        {ok, ok} ->
            ok;
        {{error, Reason}, _} ->
            {error, Reason};
        {_, {error, Reason}} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#register_member{member_id = MemberId, club_id = ClubId, name = Name}) ->
    #{command_type => command_type(),
      member_id => MemberId,
      club_id => ClubId,
      name => Name}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{member_id := MemberId, club_id := ClubId, name := Name}) ->
    new(#{member_id => MemberId, club_id => ClubId, name => Name});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the member's own id.
-spec stream_id(t()) -> binary().
stream_id(#register_member{member_id = MemberId}) ->
    MemberId.

-spec get_member_id(t()) -> binary().
get_member_id(#register_member{member_id = MemberId}) ->
    MemberId.

-spec get_club_id(t()) -> binary().
get_club_id(#register_member{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#register_member{name = Name}) ->
    Name.
