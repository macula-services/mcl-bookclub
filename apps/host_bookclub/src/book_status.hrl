%% Status bit flags for the book aggregate, following the house
%% convention: one power of two per flag, manipulated through
%% evoq_bit_flags. The readable status strings are computed at projection
%% time, never at query time.
-define(BOOK_ON_SHELF, 1).   %% 2^0: procured, on the club's shelf
-define(BOOK_RETIRED,  2).   %% 2^1: soft-deleted; commands refused
