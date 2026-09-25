%% @doc The book aggregate's status: the flags, AND their readable names.
%%
%% The .hrl holds the raw flags; THIS module owns the flag map that names
%% them, and to_string/1 renders a mask through evoq's own conversion
%% (evoq_bit_flags:to_string/2). The projections derive their status
%% strings from here -- a readable-status literal inside a projection is
%% the Demon 68 relapse, refused by the PRJ boundary test.
-module(book_status).

-include("book_status.hrl").

-export([on_shelf/0, retired/0, flag_map/0, to_string/1]).

-spec on_shelf() -> pos_integer().
on_shelf() -> ?BOOK_ON_SHELF.

-spec retired() -> pos_integer().
retired() -> ?BOOK_RETIRED.

%% @doc Flag -> readable name. The values are the read-model contract's
%% status strings, pinned by the status tests.
-spec flag_map() -> #{pos_integer() => binary()}.
flag_map() ->
    #{?BOOK_ON_SHELF => <<"on_shelf">>,
      ?BOOK_RETIRED => <<"retired">>}.

%% @doc A mask, rendered readable through evoq's own flag-map conversion.
-spec to_string(non_neg_integer()) -> binary().
to_string(Status) ->
    evoq_bit_flags:to_string(Status, flag_map()).
