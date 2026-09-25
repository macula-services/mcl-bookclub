%% @doc The plan_party_v1 command: the club plans a party.
%%
%% The command names the club's stream id and nothing else -- the party
%% count lives in the aggregate state, incremented there and echoed into
%% the event.
-module(plan_party_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([stream_id/1, get_club_id/1]).

-record(plan_party, {
    club_id :: binary()
}).

-opaque t() :: #plan_party{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> plan_party_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId}) when is_binary(ClubId), ClubId =/= <<>> ->
    {ok, #plan_party{club_id = ClubId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(t()) -> ok | {error, term()}.
validate(#plan_party{club_id = ClubId}) ->
    case reckon_gater_stream_id:validate(ClubId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#plan_party{club_id = ClubId}) ->
    #{command_type => command_type(),
      club_id => ClubId}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId}) ->
    new(#{club_id => ClubId});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the club's own id.
-spec stream_id(t()) -> binary().
stream_id(#plan_party{club_id = ClubId}) ->
    ClubId.

-spec get_club_id(t()) -> binary().
get_club_id(#plan_party{club_id = ClubId}) ->
    ClubId.
