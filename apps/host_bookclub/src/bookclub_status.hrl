%% Status bit flags for the bookclub aggregate, following the house
%% convention: an aggregate's state carries status as a bit mask, one power
%% of two per flag, manipulated through evoq_bit_flags. Macros are named
%% ?{AGGREGATE_UPPER}_{FLAG}. The raw flags live here; their readable names
%% live in bookclub_status:flag_map/0 (rendered through
%% evoq_bit_flags:to_string/2). The projections write the readable string
%% into the read model at projection time, never at query time -- but they
%% take it from bookclub_status, never from a literal of their own.
-define(BOOKCLUB_INITIATED, 1).   %% 2^0: the club exists
-define(BOOKCLUB_ARCHIVED,  2).   %% 2^1: soft-deleted; commands refused
