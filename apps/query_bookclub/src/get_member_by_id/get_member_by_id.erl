%% @doc get_member_by_id: the member, by its stream id.
%%
%% A query desk is a pure module answered by the query store: no state, no
%% framework, no mesh. An unregistered member is still answerable by id,
%% with its status visible -- hiding happens in the paged list desks.
-module(get_member_by_id).

-export([find/1]).

%% @doc One member, or not_found. The row's cells arrive in SELECT order; the
%% schema-contract test keeps that order aligned with the PRJ division's DDL.
-spec find(binary()) -> {ok, map()} | {error, term()}.
find(MemberId) when is_binary(MemberId) ->
    found(bookclub_query_store:q(
            "SELECT member_id, club_id, name, status, registered_at FROM members WHERE member_id = ?",
            [MemberId]));
find(_) ->
    {error, missing_member_id}.

found([[MemberId, ClubId, Name, Status, At] | _]) ->
    {ok, #{member_id => MemberId,
           club_id => ClubId,
           name => Name,
           status => Status,
           registered_at => At}};
found([]) ->
    {error, not_found};
found({error, Reason}) ->
    {error, {store_error, Reason}}.
