%% @doc plan_party_api: the HTTP entry point for plan_party_v1.
%%
%% Pure, like every entry point here. The club id is REQUIRED.
-module(plan_party_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    case plan_party_v1:new(#{club_id => maps:get(club_id, Params, undefined)}) of
        {ok, Cmd} -> maybe_plan_party:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
