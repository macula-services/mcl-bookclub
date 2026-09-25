%% @doc The {command}_api entry points against a real reckon-db store.
%%
%% The admin UI's writes go through these modules; this suite is the
%% rehearsal of every task the UI offers, without the wire.
-module(admin_api_tests).

-include_lib("eunit/include/eunit.hrl").

store_test_() ->
    {setup,
     fun host_bookclub_test_store:start/0,
     fun host_bookclub_test_store:stop/1,
     [{timeout, 60, fun a_club_is_initiated_and_mints_its_id/0},
      {timeout, 60, fun a_member_registers_into_the_club/0},
      {timeout, 60, fun a_book_is_procured_and_retired/0},
      {timeout, 60, fun a_reading_starts_and_finishes/0},
      {timeout, 60, fun a_party_is_planned/0}]}.

pure_test_() ->
    [fun every_entry_point_refuses_missing_fields/0].

a_club_is_initiated_and_mints_its_id() ->
    {ok, 0, [#{club_id := ClubId, name := <<"The Crooked Shelf">>}]} =
        initiate_bookclub_api:handle(#{name => <<"The Crooked Shelf">>,
                                       initiated_by => <<"raf">>}),
    ?assertMatch(<<"bookclub-", _/binary>>, ClubId),
    %% The same params with an explicit id work too.
    {ok, 0, _} = initiate_bookclub_api:handle(#{club_id => initiate_bookclub_v1:mint_club_id(),
                                                name => <<"Another">>,
                                                initiated_by => <<"raf">>}).

a_member_registers_into_the_club() ->
    {ok, 0, [#{club_id := ClubId}]} =
        initiate_bookclub_api:handle(#{name => <<"The Crooked Shelf">>,
                                       initiated_by => <<"raf">>}),
    {ok, 0, [#{member_id := MemberId, club_id := ClubId, name := <<"Bea">>}]} =
        register_member_api:handle(#{club_id => ClubId, name => <<"Bea">>}),
    ?assertMatch(<<"member-", _/binary>>, MemberId).

a_book_is_procured_and_retired() ->
    {ok, 0, [#{club_id := ClubId}]} =
        initiate_bookclub_api:handle(#{name => <<"The Crooked Shelf">>,
                                       initiated_by => <<"raf">>}),
    {ok, 0, [#{book_id := BookId, title := <<"Project Hail Mary">>}]} =
        procure_book_api:handle(#{club_id => ClubId,
                                  title => <<"Project Hail Mary">>,
                                  author => <<"Andy Weir">>}),
    {ok, 1, _} = retire_book_api:handle(#{book_id => BookId, retired_by => <<"raf">>}),
    {error, retired} = retire_book_api:handle(#{book_id => BookId, retired_by => <<"raf">>}).

a_reading_starts_and_finishes() ->
    {ok, 0, [#{club_id := ClubId}]} =
        initiate_bookclub_api:handle(#{name => <<"The Crooked Shelf">>,
                                       initiated_by => <<"raf">>}),
    {ok, 0, [#{member_id := MemberId}]} =
        register_member_api:handle(#{club_id => ClubId, name => <<"Bea">>}),
    {ok, 0, [#{book_id := BookId}]} =
        procure_book_api:handle(#{club_id => ClubId,
                                  title => <<"Project Hail Mary">>,
                                  author => <<"Andy Weir">>}),
    {ok, 0, [#{reading_id := ReadingId, member_id := MemberId, book_id := BookId}]} =
        start_reading_api:handle(#{member_id => MemberId, book_id => BookId}),
    {ok, 1, _} = finish_reading_api:handle(#{reading_id => ReadingId,
                                             pages_read => 476}).

a_party_is_planned() ->
    {ok, 0, [#{club_id := ClubId}]} =
        initiate_bookclub_api:handle(#{name => <<"The Crooked Shelf">>,
                                       initiated_by => <<"raf">>}),
    {ok, 1, [#{parties_planned := 1}]} = plan_party_api:handle(#{club_id => ClubId}),
    {ok, 2, [#{parties_planned := 2}]} = plan_party_api:handle(#{club_id => ClubId}).

%% An empty body is empty params, and every entry point answers with the
%% same missing-field error -- the answer the operator needs, not a crash.
every_entry_point_refuses_missing_fields() ->
    lists:foreach(
      fun({Module, Fun}) ->
              ?assertMatch({error, _}, Module:Fun(#{}))
      end,
      [{initiate_bookclub_api, handle}, {archive_bookclub_api, handle},
       {register_member_api, handle}, {unregister_member_api, handle},
       {procure_book_api, handle}, {retire_book_api, handle},
       {start_reading_api, handle}, {finish_reading_api, handle},
       {plan_party_api, handle}]).
