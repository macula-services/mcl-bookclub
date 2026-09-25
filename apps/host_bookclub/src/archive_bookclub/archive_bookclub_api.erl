%% @doc archive_bookclub_api: the HTTP entry point for archive_bookclub_v1.
%%
%% Pure, like every entry point here: params in, dispatch result out. The
%% club id is REQUIRED -- an archive names an existing club.
-module(archive_bookclub_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    case archive_bookclub_v1:new(#{club_id => maps:get(club_id, Params, undefined),
                                   archived_by => maps:get(archived_by, Params, undefined)}) of
        {ok, Cmd} -> maybe_archive_bookclub:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
