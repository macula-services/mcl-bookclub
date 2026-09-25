%% @doc Handler for `plan_party_v1'.
%%
%% The desk: one module that owns the business rule (a party is planned for
%% an initiated club), produces the matching `party_planned_v1' event with
%% the incremented count echoed from state, and dispatches. The archived
%% refusal is the aggregate's blanket guard.
-module(maybe_plan_party).

-export([handle_from_map/2, handle/2, dispatch/1]).

%% @doc The command's payload as evoq hands it to the aggregate: the map
%% plan_party_v1:to_map/1 made, atom-keyed.
-spec handle_from_map(term(), map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(State, #{command_type := plan_party_v1} = Payload) ->
    handled(State, plan_party_v1:new(Payload));
handle_from_map(_State, _) ->
    {error, unknown_command}.

handled(State, {ok, Cmd}) -> handle(State, Cmd);
handled(_State, {error, _} = Error) -> Error.

%% @doc The business rule: a party is planned only for an initiated club.
%% The count increments HERE, in the state the command runs against, and
%% the event carries the new count -- never a relative "+1" a consumer
%% would have to apply.
-spec handle(bookclub_state:t(), plan_party_v1:t()) ->
    {ok, [map()]} | {error, term()}.
handle(State, Cmd) ->
    plan_when_initiated(bookclub_state:is_initiated(State), State, Cmd).

plan_when_initiated(false, _State, _Cmd) ->
    {error, not_initiated};
plan_when_initiated(true, State, Cmd) ->
    case plan_party_v1:validate(Cmd) of
        ok ->
            events(State);
        {error, Reason} ->
            {error, Reason}
    end.

events(State) ->
    {ok, Event} = party_planned_v1:new(#{
        club_id => bookclub_state:club_id(State),
        parties_planned => bookclub_state:parties_planned(State) + 1}),
    {ok, [party_planned_v1:to_map(Event)]}.

%% @doc Plan the party on the club's stream in mcl_bookclub_store.
%% The caller sees `{error, _}' rather than a success nothing stored.
%%
%% VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING: the
%% store client RAISES `{invalid_stream_id, _}' on a bad id, so the desk is
%% the boundary -- it validates, then dispatches.
-spec dispatch(plan_party_v1:t()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    case plan_party_v1:validate(Cmd) of
        ok ->
            do_dispatch(Cmd);
        {error, Reason} ->
            {error, Reason}
    end.

do_dispatch(Cmd) ->
    EvoqCmd = evoq_command:new(plan_party_v1, bookclub_aggregate,
                               plan_party_v1:stream_id(Cmd),
                               plan_party_v1:to_map(Cmd),
                               #{timestamp => erlang:system_time(millisecond)}),
    evoq_command_router:dispatch(EvoqCmd, #{store_id => mcl_bookclub_store,
                                            adapter => reckon_evoq_adapter,
                                            consistency => eventual}).
