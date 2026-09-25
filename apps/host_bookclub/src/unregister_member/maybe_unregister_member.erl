%% @doc Handler for `unregister_member_v1'.
%%
%% The desk: one module that owns the business rule (a member unregisters
%% only once it exists), produces the matching `member_unregistered_v1'
%% event, and dispatches. The already-unregistered refusal is the
%% aggregate's blanket guard, not this desk's.
-module(maybe_unregister_member).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% unregister_member_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := unregister_member_v1} = Payload) ->
    handled(State, unregister_member_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule, stated against the aggregate state: a member can
%% only unregister once it exists.
-spec handle(member_state:t(), unregister_member_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    unregister_when_registered(member_state:is_registered(State), State, Cmd).

unregister_when_registered(false, _State, _Cmd) ->
    {error, not_registered};
unregister_when_registered(true, State, Cmd) ->
    case unregister_member_v1:validate(Cmd) of
        ok ->
            events(State, Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

events(State, Cmd) ->
    {ok, Event} = member_unregistered_v1:new(#{
        member_id => member_state:member_id(State),
        club_id => member_state:club_id(State),
        name => member_state:name(State),
        registered_at => member_state:registered_at(State),
        unregistered_by => unregister_member_v1:get_unregistered_by(Cmd)}),
    {ok, [member_unregistered_v1:to_map(Event)]}.

%% @doc Unregister the member on its own stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(unregister_member_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case unregister_member_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(unregister_member_v1, member_aggregate,
                               unregister_member_v1:stream_id(Cmd),
                               unregister_member_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
