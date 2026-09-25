%% Status bit flags for the book aggregate, following the house
%% convention: one power of two per flag, manipulated through
%% evoq_bit_flags. The raw flags live here; their readable names live in
%% book_status:flag_map/0, and the projections take them from there.
-define(BOOK_ON_SHELF, 1).   %% 2^0: procured, on the club's shelf
-define(BOOK_RETIRED,  2).   %% 2^1: soft-deleted; commands refused
