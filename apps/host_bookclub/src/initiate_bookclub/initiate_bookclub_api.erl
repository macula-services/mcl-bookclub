%% @doc initiate_bookclub_api: the HTTP entry point for initiate_bookclub_v1.
%%
%% The corpus's command entry point -- the HOPE side of the admin UI. The
%% module is PURE (no cowboy, no mesh): it turns the UI's params into a
%% command and dispatches. The facade owns the wire; the desk owns the
%% dispatch. The club id is minted here when the operator does not bring
%% one -- the API's boundary makes that decision, like every entry point.
-module(initiate_bookclub_api).

-export([handle/1]).

%% @doc Params arrive atom-keyed (the facade JSON-decodes with atom
%% labels). A missing club_id is minted; the event echoes it back.
-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    handle_with(maps:get(club_id, Params, initiate_bookclub_v1:mint_club_id()),
                Params).

handle_with(ClubId, Params) ->
    case initiate_bookclub_v1:new(#{club_id => ClubId,
                                    name => maps:get(name, Params, undefined),
                                    initiated_by => maps:get(initiated_by, Params, undefined)}) of
        {ok, Cmd} -> maybe_initiate_bookclub:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
