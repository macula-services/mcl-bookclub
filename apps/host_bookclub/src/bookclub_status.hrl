%% Status bit flags for the bookclub aggregate, following the house
%% convention: an aggregate's state carries status as a bit mask, one power
%% of two per flag, manipulated through evoq_bit_flags. Macros are named
%% ?{AGGREGATE_UPPER}_{FLAG}. The readable status strings ("active",
%% "archived") are computed at projection time, never at query time, so this
%% header is the only place raw flags exist.
-define(BOOKCLUB_INITIATED, 1).   %% 2^0: the club exists
-define(BOOKCLUB_ARCHIVED,  2).   %% 2^1: soft-deleted; commands refused
