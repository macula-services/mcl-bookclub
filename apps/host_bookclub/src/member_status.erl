%% @doc The member aggregate's status: the flags, AND their readable names.
%%
%% The .hrl holds the raw flags; THIS module owns the flag map that names
%% them, and to_string/1 renders a mask through evoq's own conversion
%% (evoq_bit_flags:to_string/2). The projections derive their status
%% strings from here -- a readable-status literal inside a projection is
%% the Demon 68 relapse, refused by the PRJ boundary test.
-module(member_status).

-include("member_status.hrl").

-export([registered/0, unregistered/0, flag_map/0, to_string/1]).

-spec registered() -> pos_integer().
registered() -> ?MEMBER_REGISTERED.

-spec unregistered() -> pos_integer().
unregistered() -> ?MEMBER_UNREGISTERED.

%% @doc Flag -> readable name. The values are the read-model contract's
%% status strings, pinned by the status tests.
-spec flag_map() -> #{pos_integer() => binary()}.
flag_map() ->
    #{?MEMBER_REGISTERED => <<"active">>,
      ?MEMBER_UNREGISTERED => <<"unregistered">>}.

%% @doc A mask, rendered readable through evoq's own flag-map conversion.
-spec to_string(non_neg_integer()) -> binary().
to_string(Status) ->
    evoq_bit_flags:to_string(Status, flag_map()).
