%% @doc procure_book_api: the HTTP entry point for procure_book_v1.
%%
%% Pure, like every entry point here. The book id is minted when the
%% operator does not bring one; the event echoes it back.
-module(procure_book_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    handle_with(maps:get(book_id, Params, procure_book_v1:mint_book_id()),
                Params).

handle_with(BookId, Params) ->
    case procure_book_v1:new(#{book_id => BookId,
                               club_id => maps:get(club_id, Params, undefined),
                               title => maps:get(title, Params, undefined),
                               author => maps:get(author, Params, undefined)}) of
        {ok, Cmd} -> maybe_procure_book:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
