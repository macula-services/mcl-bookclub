%% @doc unregister_member_api: the HTTP entry point for unregister_member_v1.
%%
%% Pure, like every entry point here. The member id is REQUIRED.
-module(unregister_member_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    case unregister_member_v1:new(#{member_id => maps:get(member_id, Params, undefined),
                                    unregistered_by => maps:get(unregistered_by, Params, undefined)}) of
        {ok, Cmd} -> maybe_unregister_member:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
