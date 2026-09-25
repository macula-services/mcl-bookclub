%% @doc The finish_reading_v1 command: a member finishes reading a book.
%%
%% The command names the reading's stream id and the pages read. Everything
%% else the finished event needs comes from the aggregate state, echoed into
%% the event.
-module(finish_reading_v1).

-behaviour(evoq_command).

-export([command_type/0, new/1, to_map/1, validate/1, from_map/1]).
-export([stream_id/1, get_reading_id/1, get_pages_read/1]).

-record(finish_reading, {
    reading_id :: binary(),
    pages_read :: non_neg_integer()
}).

-opaque t() :: #finish_reading{}.
-export_type([t/0]).

-spec command_type() -> atom().
command_type() -> finish_reading_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{reading_id := ReadingId, pages_read := Pages}) ->
    record_when(is_binary(ReadingId), ReadingId =/= <<>>,
                is_integer(Pages), Pages >= 0,
                ReadingId, Pages);
new(_) ->
    {error, missing_required_fields}.

record_when(true, true, true, true, ReadingId, Pages) ->
    {ok, #finish_reading{reading_id = ReadingId, pages_read = Pages}};
record_when(_, _, _, _, _, _) ->
    {error, invalid_params}.

-spec validate(t()) -> ok | {error, term()}.
validate(#finish_reading{reading_id = ReadingId}) ->
    case reckon_gater_stream_id:validate(ReadingId) of
        ok ->
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

-spec to_map(t()) -> map().
to_map(#finish_reading{reading_id = ReadingId, pages_read = Pages}) ->
    #{command_type => command_type(),
      reading_id => ReadingId,
      pages_read => Pages}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{reading_id := ReadingId, pages_read := Pages}) ->
    new(#{reading_id => ReadingId, pages_read => Pages});
from_map(_) ->
    {error, missing_required_fields}.

%% @doc The stream the command is addressed to: the reading's own id.
-spec stream_id(t()) -> binary().
stream_id(#finish_reading{reading_id = ReadingId}) ->
    ReadingId.

-spec get_reading_id(t()) -> binary().
get_reading_id(#finish_reading{reading_id = ReadingId}) ->
    ReadingId.

-spec get_pages_read(t()) -> non_neg_integer().
get_pages_read(#finish_reading{pages_read = Pages}) ->
    Pages.
