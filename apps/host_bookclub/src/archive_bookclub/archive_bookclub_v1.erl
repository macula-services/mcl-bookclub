%% @doc The archive_bookclub_v1 command: soft-delete the club.
%%
%% `archive', the house soft-delete verb -- never delete. The command names
%% the club's stream id and who archived it; everything else the archive
%% needs comes from the aggregate state, echoed into the event.
-module(archive_bookclub_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([stream_id/1, get_club_id/1, get_archived_by/1]).

-record(archive_bookclub, {
    club_id :: binary(),
    archived_by :: binary()
}).

-opaque t() :: #archive_bookclub{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> archive_bookclub_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{club_id := ClubId, archived_by := By}) ->
    record_when(is_binary(ClubId), ClubId =/= <<>>,
                is_binary(By), By =/= <<>>,
                ClubId, By);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, ClubId, By) ->
    {ok, #archive_bookclub{club_id = ClubId, archived_by = By}};
record_when(_, _, _, _, _, _) ->
    {error, invalid_params}.

%% @doc Checks about the world, not the shape: the stream id must satisfy the
%% reckon-db stream contract, or the append is refused.
-spec validate(t()) -> ok | {error, term()}.
validate(#archive_bookclub{club_id = ClubId}) ->
    case reckon_gater_stream_id:validate(ClubId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#archive_bookclub{club_id = ClubId, archived_by = By}) ->
    #{command_type => command_type(),
      club_id => ClubId,
      archived_by => By}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{club_id := ClubId, archived_by := By}) ->
    new(#{club_id => ClubId, archived_by => By});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the club's own id.
-spec stream_id(t()) -> binary().
stream_id(#archive_bookclub{club_id = ClubId}) ->
    ClubId.

-spec get_club_id(t()) -> binary().
get_club_id(#archive_bookclub{club_id = ClubId}) ->
    ClubId.

-spec get_archived_by(t()) -> binary().
get_archived_by(#archive_bookclub{archived_by = By}) ->
    By.
