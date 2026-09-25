%% @doc retire_book_api: the HTTP entry point for retire_book_v1.
%%
%% Pure, like every entry point here. The book id is REQUIRED.
-module(retire_book_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    case retire_book_v1:new(#{book_id => maps:get(book_id, Params, undefined),
                              retired_by => maps:get(retired_by, Params, undefined)}) of
        {ok, Cmd} -> maybe_retire_book:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
