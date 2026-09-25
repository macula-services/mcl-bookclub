%% @doc The bookclub aggregate's status: the flags, AND their readable names.
%%
%% The .hrl holds the raw flags (one power of two each); THIS module owns
%% the flag map that names them, and to_string/1 renders a mask through
%% evoq's own conversion (evoq_bit_flags:to_string/2). The projections
%% derive their status strings from here, so the bits and the names live in
%% one place and cannot drift apart -- a readable-status literal inside a
%% projection is the Demon 68 relapse, and the PRJ boundary test refuses it.
-module(bookclub_status).

-include("bookclub_status.hrl").

-export([initiated/0, archived/0, flag_map/0, to_string/1]).

-spec initiated() -> pos_integer().
initiated() -> ?BOOKCLUB_INITIATED.

-spec archived() -> pos_integer().
archived() -> ?BOOKCLUB_ARCHIVED.

%% @doc Flag -> readable name. The values are the read-model contract's
%% status strings, pinned by the status tests.
-spec flag_map() -> #{pos_integer() => binary()}.
flag_map() ->
    #{?BOOKCLUB_INITIATED => <<"active">>,
      ?BOOKCLUB_ARCHIVED => <<"archived">>}.

%% @doc A mask, rendered readable through evoq's own flag-map conversion.
-spec to_string(non_neg_integer()) -> binary().
to_string(Status) ->
    evoq_bit_flags:to_string(Status, flag_map()).
