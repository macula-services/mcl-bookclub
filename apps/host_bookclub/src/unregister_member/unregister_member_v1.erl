%% @doc The unregister_member_v1 command: soft-delete the member.
%%
%% `unregister', the club-domain verb for a member leaving -- never delete.
%% Everything else the unregistered event needs comes from the aggregate
%% state, echoed into the event.
-module(unregister_member_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([stream_id/1, get_member_id/1, get_unregistered_by/1]).

-record(unregister_member, {
    member_id :: binary(),
    unregistered_by :: binary()
}).

-opaque t() :: #unregister_member{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> unregister_member_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{member_id := MemberId, unregistered_by := By}) ->
    record_when(is_binary(MemberId), MemberId =/= <<>>,
                is_binary(By), By =/= <<>>,
                MemberId, By);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, MemberId, By) ->
    {ok, #unregister_member{member_id = MemberId, unregistered_by = By}};
record_when(_, _, _, _, _, _) ->
    {error, invalid_params}.

-spec validate(t()) -> ok | {error, term()}.
validate(#unregister_member{member_id = MemberId}) ->
    case reckon_gater_stream_id:validate(MemberId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#unregister_member{member_id = MemberId, unregistered_by = By}) ->
    #{command_type => command_type(),
      member_id => MemberId,
      unregistered_by => By}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{member_id := MemberId, unregistered_by := By}) ->
    new(#{member_id => MemberId, unregistered_by => By});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the member's own id.
-spec stream_id(t()) -> binary().
stream_id(#unregister_member{member_id = MemberId}) ->
    MemberId.

-spec get_member_id(t()) -> binary().
get_member_id(#unregister_member{member_id = MemberId}) ->
    MemberId.

-spec get_unregistered_by(t()) -> binary().
get_unregistered_by(#unregister_member{unregistered_by = By}) ->
    By.
