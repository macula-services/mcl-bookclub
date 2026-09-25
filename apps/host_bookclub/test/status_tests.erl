%% @doc The status modules: the flag maps and their readable names.
%%
%% These tests pin the read-model contract's status strings to the flag
%% maps that own them. The projections derive their status strings from
%% these modules (never from literals of their own -- see the PRJ boundary
%% test), so a change here is a deliberate, visible change to the strings
%% every query desk hands out.
-module(status_tests).

-include_lib("eunit/include/eunit.hrl").

pure_test_() ->
    [fun the_bookclub_flag_map_names_the_two_flags/0,
     fun the_book_flag_map_names_the_two_flags/0,
     fun the_member_flag_map_names_the_two_flags/0,
     fun the_reading_flag_map_names_the_two_flags/0,
     fun to_string_renders_a_mask_through_evoq/0].

the_bookclub_flag_map_names_the_two_flags() ->
    ?assertEqual(#{1 => <<"active">>, 2 => <<"archived">>},
                 bookclub_status:flag_map()).

the_book_flag_map_names_the_two_flags() ->
    ?assertEqual(#{1 => <<"on_shelf">>, 2 => <<"retired">>},
                 book_status:flag_map()).

the_member_flag_map_names_the_two_flags() ->
    ?assertEqual(#{1 => <<"active">>, 2 => <<"unregistered">>},
                 member_status:flag_map()).

the_reading_flag_map_names_the_two_flags() ->
    ?assertEqual(#{1 => <<"in_progress">>, 2 => <<"finished">>},
                 reading_status:flag_map()).

to_string_renders_a_mask_through_evoq() ->
    %% A single flag renders its own name; a mask of both renders the
    %% joined, comma-separated description evoq's conversion produces.
    ?assertEqual(<<"active">>,
                 bookclub_status:to_string(bookclub_status:initiated())),
    ?assertEqual(<<"archived">>,
                 bookclub_status:to_string(bookclub_status:archived())),
    ?assertEqual(<<"active, archived">>,
                 bookclub_status:to_string(
                   bookclub_status:initiated() bor bookclub_status:archived())).
