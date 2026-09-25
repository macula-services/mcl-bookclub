%% Status bit flags for the member aggregate, following the house
%% convention: an aggregate's state carries status as a bit mask, one power
%% of two per flag, manipulated through evoq_bit_flags. The unregistered
%% flag is the member's soft-delete; the readable status strings are
%% computed at projection time, never at query time.
-define(MEMBER_REGISTERED,   1).   %% 2^0: the member exists
-define(MEMBER_UNREGISTERED, 2).   %% 2^1: soft-deleted; commands refused
