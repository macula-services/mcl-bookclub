%% @doc Handler for `register_member_v1'.
%%
%% The desk: one module that owns the business rule (a member registers
%% once), produces the matching `member_registered_v1' event, and
%% dispatches. The aggregate calls handle_from_map/2; callers dispatch/1.
-module(maybe_register_member).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% register_member_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := register_member_v1} = Payload) ->
    handled(State, register_member_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a member
%% registers exactly once. The already-unregistered refusal is the
%% aggregate's blanket guard, not this desk's.
-spec handle(member_state:t(), register_member_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    register_when_fresh(member_state:is_registered(State), Cmd).

register_when_fresh(true, _Cmd) ->
    {error, already_registered};
register_when_fresh(false, Cmd) ->
    case register_member_v1:validate(Cmd) of
        ok ->
            events(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(Cmd) ->
    {ok, Event} = member_registered_v1:new(#{
        member_id => register_member_v1:get_member_id(Cmd),
        club_id => register_member_v1:get_club_id(Cmd),
        name => register_member_v1:get_name(Cmd),
        club_name => register_member_v1:get_club_name(Cmd)}),
    {ok, [member_registered_v1:to_map(Event)]}.

%% @doc Register the member on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(register_member_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case register_member_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(register_member_v1, member_aggregate,
                               register_member_v1:stream_id(Cmd),
                               register_member_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
