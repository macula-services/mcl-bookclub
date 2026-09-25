%% @doc get_bookclub_by_id: the club, by its stream id.
%%
%% A query desk is a pure module answered by the query store: no state, no
%% framework, no mesh. The facade will advertise this desk as a mesh
%% capability once the walking skeleton proves the path; until then it is
%% called directly, here and in tests.
%%
%% Banned-name clean: get_{aggregate}_by_id, never list_* or get_all_*.
-module(get_bookclub_by_id).

-export([find/1]).

%% @doc One club, or not_found. The row's cells arrive in SELECT order; the
%% schema-contract test keeps that order aligned with the PRJ division's DDL.
-spec find(binary()) -> {ok, map()} | {error, term()}.
find(ClubId) when is_binary(ClubId) ->
    found(bookclub_query_store:q(
            "SELECT club_id, name, status, initiated_by, initiated_at FROM clubs WHERE club_id = ?",
            [ClubId]));
find(_) ->
    {error, missing_club_id}.

found([[ClubId, Name, Status, By, At] | _]) ->
    {ok, #{club_id => ClubId,
           name => Name,
           status => Status,
           initiated_by => By,
           initiated_at => At}};
found([]) ->
    {error, not_found};
found({error, Reason}) ->
    {error, {store_error, Reason}}.
