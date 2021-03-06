%%%-------------------------------------------------------------------
%%% @author yunba
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. Jul 2015 7:00 PM
%%%-------------------------------------------------------------------
-module(mongodberl_worker).
-author("yunba").

-behaviour(gen_server).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
    mongodb_single_args,
    mongodb_replset,
    mongodb_rsConn,
    mongodb_singleConn,
    mongodb_dbName,
    mongodb_connection_type
}).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Args :: term()) ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
%%MongoInfo::[{single | replset,MongodbArg,DbName}]
start_link(MongoInfo) ->
    gen_server:start_link(?MODULE, [MongoInfo], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
%MongodbArg :: {single,"host:port"}
init([[{single, MongodbArg, MongoDatabase}]] = _MongoInfo) ->
    process_flag(trap_exit, true),
    {ok, #state{mongodb_single_args = MongodbArg, mongodb_dbName = MongoDatabase, mongodb_connection_type = single}};%%{ok,Pid}=mongoc:start_link(),
%%ReplSet :: {repl,["host1:port1","host2:port2", "host3:port3"]}
init([[{replset, ReplSet, MongoDatabase}]] = _MongoInfo) ->
    process_flag(trap_exit, true),
    {ok, #state{mongodb_replset = ReplSet, mongodb_dbName = MongoDatabase, mongodb_connection_type = replset}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
    {reply, Reply :: term(), NewState :: #state{}} |
    {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
    {stop, Reason :: term(), NewState :: #state{}}).
%%----------------------------------------------------------
%%add
%%----------------------------------------------------------
%%-----------------------------------------------------------
handle_call(rs_connect, _From, State = #state{mongodb_rsConn = undefined, mongodb_replset = ReplSet, mongodb_dbName = MongoDatabase}) ->
    {ReplSetName, Hosts} = ReplSet,
    mongodb:replicaSets(ReplSetName, Hosts),
    mongodb:connect(ReplSetName),
    Mongo = mongoapi:new(ReplSetName, mongodberl:make_sure_binary(MongoDatabase)),
    {reply, {ok, Mongo}, State#state{mongodb_rsConn = Mongo}};

handle_call(rs_connect, _From, State = #state{mongodb_rsConn = Mongo}) ->
    {reply, {ok, Mongo}, State};%%case mongodb:is_connected(ReplSetName) of  TODO erlmongo has bug for this api

handle_call(connect, _From, State = #state{mongodb_singleConn = undefined, mongodb_single_args = Args, mongodb_dbName = MongoDatabase}) ->
    {SingleName, Host} = Args,
    mongodb:singleServer(SingleName, Host),
    mongodb:connect(SingleName),
    Mongo = mongoapi:new(SingleName, mongodberl:make_sure_binary(MongoDatabase)),
    {reply, {ok, Mongo}, State#state{mongodb_singleConn = Mongo}};

handle_call(connect, _From, State = #state{mongodb_singleConn = Mongo}) ->
    {reply, {ok, Mongo}, State};

handle_call(get_connection_type, _From, State = #state{mongodb_connection_type = Type}) ->
    {reply, {ok, Type}, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_info({'DOWN', _Ref, _Type, _Pid, _Info}, State) ->
    {noreply, State#state{mongodb_rsConn = undefined}};

handle_info({'EXIT', _Pid, _Info}, State) ->
    {noreply, State#state{mongodb_rsConn  = undefined}};

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
    {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================