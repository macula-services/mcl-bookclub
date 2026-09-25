%% @doc start_reading_api: the HTTP entry point for start_reading_v1.
%%
%% Pure, like every entry point here. The reading id is minted when the
%% operator does not bring one -- the reading is the child, and the entry
%% point is the member's side that identifies it.
-module(start_reading_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    handle_with(maps:get(reading_id, Params, start_reading_v1:mint_reading_id()),
                Params).

handle_with(ReadingId, Params) ->
    case start_reading_v1:new(#{reading_id => ReadingId,
                                member_id => maps:get(member_id, Params, undefined),
                                book_id => maps:get(book_id, Params, undefined)}) of
        {ok, Cmd} -> maybe_start_reading:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
