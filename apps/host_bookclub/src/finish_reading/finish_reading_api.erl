%% @doc finish_reading_api: the HTTP entry point for finish_reading_v1.
%%
%% Pure, like every entry point here. The reading id and the pages read are
%% REQUIRED -- a finish names an in-progress reading.
-module(finish_reading_api).

-export([handle/1]).

-spec handle(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
handle(Params) ->
    case finish_reading_v1:new(#{reading_id => maps:get(reading_id, Params, undefined),
                                 pages_read => maps:get(pages_read, Params, undefined)}) of
        {ok, Cmd} -> maybe_finish_reading:dispatch(Cmd);
        {error, _} = Error -> Error
    end.
