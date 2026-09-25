%% @doc register_member_api: the HTTP entry point for register_member_v1.
%%
%% Pure, like every entry point here. The member id is minted when the
%% operator does not bring one; the event echoes it back.
-module(register_member_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    handle_with(maps:get(member_id, Params, register_member_v1:mint_member_id()),
                Params).

handle_with(MemberId, Params) ->
    case register_member_v1:new(#{member_id => MemberId,
                                  club_id => maps:get(club_id, Params, undefined),
                                  name => maps:get(name, Params, undefined),
                                  club_name => maps:get(club_name, Params, <<>>)}) of
        {ok, Cmd} -> maybe_register_member:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
