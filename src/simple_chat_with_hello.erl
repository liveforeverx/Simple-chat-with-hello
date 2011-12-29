-module(simple_chat_with_hello).
-export([start/0]).
-export([start/2, stop/1]).

-behaviour(hello_stateful_handler).
-export([init/3, handle/2, terminate/2]).
-export([method_info/1, param_info/2, init/2, handle_request/4, handle_info/3, terminate/3]).

-include_lib("hello/include/hello.hrl").

-define(USERS, users).
-define(HARDCODED, "/home/dima/dev/simple_chat_with_hello/priv").

start() ->
    application:start(cowboy),
%    hello:start(),
    start([], []).

start(_Type, _StartArgs) ->
    io:format(user, "Starting ~n", []),
    Dispatch = [{'_', [{'_', simple_chat_with_hello, []}]}],
    cowboy:start_listener(http, 100,
                            cowboy_tcp_transport, [{port, 10000}],
                            cowboy_http_protocol, [{dispatch, Dispatch}]),
%    bind(),
    pg2:create(?USERS),
    {ok, self()}.

stop(_) ->
    ok.

% HTTP SERVER
init({tcp, http}, Req, _Opts) ->
    {ok, Req, undefined_state}.

handle(Req, State) ->
    {Path, Req1} = cowboy_http_req:path(Req),
    case code:priv_dir(simple_chat_with_hello) of
        {error, _} ->
            DirName = ?HARDCODED;
        DirName ->
            ok
    end,
    io:format(user, "log:~p~n", [Path]),
    File = hd(lists:reverse(Path)),
    FileName = filename:join([DirName, File]),
    case file:read_file(FileName) of
        {ok, Binary} ->
            {ok, Req2} = cowboy_http_req:reply(200, [], Binary, Req1);
        {error, _} ->
            {ok, Req2} = cowboy_http_req:reply(200, [], <<"file not found">>, Req1)
    end,
    {ok, Req2, State}.

terminate(_Req, _State) ->
    ok.

bind() ->
    hello:bind_stateful("sockjs://127.0.0.1:10000/chat", ?MODULE, []).

%% HELLO RPC SUPER BEHAVIOR
method_info(_State) ->
    [#rpc_method{name = post}].

param_info(post, _State) ->
    [#rpc_param{name = 'message', type = string}].

init(_Context, []) ->
    pg2:join(?USERS, self()),
    {ok, undefined}.

handle_request(_From, post, [Message], State) ->
    Pids = pg2:get_members(?USERS),
    Self = self(),
    [Pid ! {send, Message} || Pid <- Pids, Pid =/= Self],
    {noreply, State}.

handle_info(Context, {send, Msg}, State) ->
    hello_stateful_handler:notify_np(Context, posted, [{message, Msg}]),
    {noreply, State}.

terminate(_Context, _Reason, _State) ->
    ok.
