%% Status bit flags for the reading aggregate, following the house
%% convention: one power of two per flag, manipulated through
%% evoq_bit_flags. The readable status strings are computed at projection
%% time, never at query time.
-define(READING_IN_PROGRESS, 1).   %% 2^0: started, not yet finished
-define(READING_FINISHED,   2).   %% 2^1: finished; commands refused
