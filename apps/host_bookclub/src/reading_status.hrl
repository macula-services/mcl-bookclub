%% Status bit flags for the reading aggregate, following the house
%% convention: one power of two per flag, manipulated through
%% evoq_bit_flags. The raw flags live here; their readable names live in
%% reading_status:flag_map/0, and the projections take them from there.
-define(READING_IN_PROGRESS, 1).   %% 2^0: started, not yet finished
-define(READING_FINISHED,   2).   %% 2^1: finished; commands refused
