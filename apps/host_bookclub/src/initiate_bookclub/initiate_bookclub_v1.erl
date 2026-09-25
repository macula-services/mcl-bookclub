%% @doc The initiate_bookclub_v1 command: what a caller asks for.
%%
%% A command is a record with typed getters, one `to_map/1' that becomes the
%% payload the aggregate's execute/2 sees, and one validate/1 for the checks
%% that are about the world (here: the stream id the command names). The
%% payload keys are ATOMS -- evoq reads command_type with an atom lookup, and
%% a binary-keyed map would store `command_type => undefined' without a sound.
-module(initiate_bookclub_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([mint_club_id/0, stream_id/1, get_club_id/1, get_name/1, get_initiated_by/1]).

-record(initiate_bookclub, {
    club_id :: binary(),
    name :: binary(),
    initiated_by :: binary()
}).

-opaque t() :: #initiate_bookclub{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> initiate_bookclub_v1.

%% @doc Mint the club's stream id. The AggregateId IS the reckon stream id
%% (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the human-readable name goes in the
%% payload and this derived id is what the command is addressed to. Never
%% hand-roll the suffix; reckon_gater_stream_id:new/1 mints the contract.
-spec mint_club_id() -> binary().
mint_club_id() ->
    reckon_gater_stream_id:new(<<"bookclub">>).

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId, name := Name, initiated_by := By}) ->
    record_when(is_binary(ClubId), ClubId =/= <<>>,
                is_binary(Name), Name =/= <<>>,
                is_binary(By), By =/= <<>>,
                ClubId, Name, By);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, true, true, ClubId, Name, By) ->
    {ok, #initiate_bookclub{club_id = ClubId, name = Name, initiated_by = By}};
record_when(_, _, _, _, _, _, _, _, _) ->
    {error, invalid_params}.

%% @doc Checks about the world, not the shape: the stream id must satisfy the
%% reckon-db stream contract, or the append is refused and the error is the
%% only thing the caller ever sees (the dispatch result is the one error
%% channel -- nothing logs it for you).
-spec validate(t()) -> ok | {error, term()}.
validate(#initiate_bookclub{club_id = ClubId}) ->
    case reckon_gater_stream_id:validate(ClubId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#initiate_bookclub{club_id = ClubId, name = Name, initiated_by = By}) ->
    #{command_type => command_type(),
      club_id => ClubId,
      name => Name,
      initiated_by => By}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId, name := Name, initiated_by := By}) ->
    new(#{club_id => ClubId, name => Name, initiated_by => By});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the club's own id.
-spec stream_id(t()) -> binary().
stream_id(#initiate_bookclub{club_id = ClubId}) ->
    ClubId.

-spec get_club_id(t()) -> binary().
get_club_id(#initiate_bookclub{club_id = ClubId}) ->
    ClubId.

-spec get_name(t()) -> binary().
get_name(#initiate_bookclub{name = Name}) ->
    Name.

-spec get_initiated_by(t()) -> binary().
get_initiated_by(#initiate_bookclub{initiated_by = By}) ->
    By.
