%% @doc mcl-bookclub-admin: the LAN-facing admin UI and its JSON API.
%%
%% The task-based UI the operator uses to run the club. It lives in the
%% FACADE, like /health: the facade owns the wire (cowboy, JSON), the desks
%% own the work. Every write goes through the desk's `{command}_api'
%% entry point -- the same dispatch the mesh and the tests use, so the UI
%% can never do anything the domain does not already allow.
%%
%% The listener binds the box's LAN interfaces by default (0.0.0.0): the
%% UI is LAN-facing, NOT mesh-facing, on MCL_ADMIN_PORT (default 8488). It
%% is an operator tool on the same box the service runs on -- no auth layer
%% of its own, deliberately, and documented as such.
-module(mcl_bookclub_admin).

-export([start_listener/0, routes/0]).
-export([init/2]).

%% @doc The admin listener, as a child of the facade supervisor. Port 0
%% gives an ephemeral port (the integration test reads it back with
%% ranch:get_port/1).
-spec start_listener() -> {ok, pid()} | {error, term()}.
start_listener() ->
    Dispatch = cowboy_router:compile([{'_', routes()}]),
    cowboy:start_clear(mcl_bookclub_admin_http, socket_opts(admin_port(), admin_ip()),
                       #{env => #{dispatch => Dispatch}}).

%% @doc The routes: the static UI, and one JSON API with the corpus's route
%% shapes -- POST /api/{plural}/{verb} for commands, GET /api/{plural}/:id
%% for reads.
-spec routes() -> [{string(), module(), term()}].
routes() ->
    [{"/", cowboy_static, {priv_file, mcl_bookclub, "admin/index.html"}},
     {"/app.js", cowboy_static, {priv_file, mcl_bookclub, "admin/app.js"}},
     {"/api/[...]", ?MODULE, #{}}].

%%====================================================================
%% cowboy
%%====================================================================

%% Single-shot, like mcl_om's own health handler: read, dispatch, reply,
%% done -- the whole request in init/2.
init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path_info(Req0),
    {Params, Req1} = read_params(Method, Req0),
    {Status, Body} = dispatch(Method, Path, Params),
    Req = cowboy_req:reply(Status,
                           #{<<"content-type">> => <<"application/json">>},
                           jsx:encode(Body), Req1),
    {ok, Req, State}.

read_params(<<"POST">>, Req0) ->
    {ok, Body, Req} = cowboy_req:read_body(Req0),
    {decode(Body), Req};
read_params(_, Req) ->
    {#{}, Req}.

%%====================================================================
%% The dispatch table
%%====================================================================

%% WRITES: one route per desk, through the desk's own entry point.
dispatch(<<"POST">>, [<<"clubs">>, <<"initiate">>], Params) ->
    result(initiate_bookclub_api:handle(Params));
dispatch(<<"POST">>, [<<"clubs">>, <<"archive">>], Params) ->
    result(archive_bookclub_api:handle(Params));
dispatch(<<"POST">>, [<<"clubs">>, <<"plan_party">>], Params) ->
    result(plan_party_api:handle(Params));
dispatch(<<"POST">>, [<<"members">>, <<"register">>], Params) ->
    result(register_member_api:handle(Params));
dispatch(<<"POST">>, [<<"members">>, <<"unregister">>], Params) ->
    result(unregister_member_api:handle(Params));
dispatch(<<"POST">>, [<<"books">>, <<"procure">>], Params) ->
    result(procure_book_api:handle(Params));
dispatch(<<"POST">>, [<<"books">>, <<"retire">>], Params) ->
    result(retire_book_api:handle(Params));
dispatch(<<"POST">>, [<<"readings">>, <<"start">>], Params) ->
    result(start_reading_api:handle(Params));
dispatch(<<"POST">>, [<<"readings">>, <<"finish">>], Params) ->
    result(finish_reading_api:handle(Params));
%% READS: one route per QRY desk.
dispatch(<<"GET">>, [<<"clubs">>, Id], _) ->
    found(get_bookclub_by_id:find(Id));
dispatch(<<"GET">>, [<<"members">>, Id, <<"readings">>], _) ->
    found(get_readings_by_member:find(Id));
dispatch(<<"GET">>, [<<"members">>, Id], _) ->
    found(get_member_by_id:find(Id));
dispatch(<<"GET">>, [<<"books">>, Id], _) ->
    found(get_book_by_id:find(Id));
dispatch(<<"GET">>, [<<"readings">>, Id], _) ->
    found(get_reading_by_id:find(Id));
dispatch(_, _, _) ->
    {404, #{error => not_found}}.

result({ok, Version, Events}) ->
    {200, #{ok => true, version => Version, events => Events}};
result({error, Reason}) ->
    {400, #{ok => false, error => Reason}}.

found({ok, Value}) ->
    {200, Value};
found({error, Reason}) ->
    {404, #{ok => false, error => Reason}}.

%%====================================================================
%% The wire's edges
%%====================================================================

%% A body the decoder cannot read is empty params, not a crash: the desk
%% entry points turn missing fields into {error, missing_required_fields},
%% which is the answer the operator needs.
decode(<<>>) ->
    #{};
decode(Body) ->
    try jsx:decode(Body, [{labels, atom}]) of
        Params when is_map(Params) -> Params;
        _ -> #{}
    catch
        _:_ -> #{}
    end.

admin_port() ->
    application:get_env(mcl_bookclub, admin_port, 8488).

admin_ip() ->
    application:get_env(mcl_bookclub, admin_ip, undefined).

socket_opts(Port, Unset) when Unset =:= undefined; Unset =:= "" ->
    [{port, Port}];
socket_opts(Port, Ip) ->
    {ok, Address} = inet:parse_address(binary_to_list(Ip)),
    [{port, Port}, {ip, Address}].
