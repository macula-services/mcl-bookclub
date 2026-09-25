%% @doc The reading aggregate's status: the flags, AND their readable names.
%%
%% The .hrl holds the raw flags; THIS module owns the flag map that names
%% them, and to_string/1 renders a mask through evoq's own conversion
%% (evoq_bit_flags:to_string/2). The projections derive their status
%% strings from here -- a readable-status literal inside a projection is
%% the Demon 68 relapse, refused by the PRJ boundary test.
-module(reading_status).

-include("reading_status.hrl").

-export([in_progress/0, finished/0, flag_map/0, to_string/1]).

-spec in_progress() -> pos_integer().
in_progress() -> ?READING_IN_PROGRESS.

-spec finished() -> pos_integer().
finished() -> ?READING_FINISHED.

%% @doc Flag -> readable name. The values are the read-model contract's
%% status strings, pinned by the status tests.
-spec flag_map() -> #{pos_integer() => binary()}.
flag_map() ->
    #{?READING_IN_PROGRESS => <<"in_progress">>,
      ?READING_FINISHED => <<"finished">>}.

%% @doc A mask, rendered readable through evoq's own flag-map conversion.
-spec to_string(non_neg_integer()) -> binary().
to_string(Status) ->
    evoq_bit_flags:to_string(Status, flag_map()).
