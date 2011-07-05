%%%-------------------------------------------------------------------
%%% @author Andreas Schultz <aschultz@tpip.net>
%%% @copyright (C) 2011, Andreas Schultz
%%% @doc
%%%
%%% @end
%%% Created :  5 Jul 2011 by Andreas Schultz <aschultz@tpip.net>
%%%-------------------------------------------------------------------
-module(flower_dispatcher).

-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([delete/1, join/1, leave/1, terminate/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
		 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {
		  events
		 }).


%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
	gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

delete(Event) ->
	gen_sever:call(?SERVER, {unregister, Event}).

join(Event) ->
	gen_sever:call(?SERVER, {join, Event}).
leave(Event) ->
	gen_sever:call(?SERVER, {leave, Event}).

terminate() ->
	gen_sever:call(?SERVER, terminate).

%%%===================================================================
%%% gen_server functions
%%%===================================================================

init([]) ->
    process_flag(trap_exit, true),
	ets:new(?SERVER, [bag, protected, named_table, {keypos, 1}]),
	{ok, #state{}}.

handle_call({delete, Event}, _From, State) ->
	ets:delete(?SERVER, Event),
	{reply, ok, State};

handle_call({join, Event}, From, State) ->
	Reply = do_join(Event, From),
	{reply, Reply, State};

handle_call({leave, Event}, From, State) ->
	Reply = do_leave(Event, From),
	{reply, Reply, State};

handle_call({dispatch, Event, Msg}, _From, State) ->
	Handlers = ets:match(?SERVER, {Event, '$1'}),
	lists:foreach(fun(Pid) -> gen_server:cast(Pid, {Event, Msg}) end, Handlers),
	{reply, ok, State}.

handle_cast(terminate, State) ->
	{stop, requested, State}.

handle_info({'EXIT', Pid, _Reason}, State) ->
	ets:match_delete(?SERVER, {'_', Pid}),
	{noreply, State};

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

do_join(Event, Pid) ->
	case flow_event:is_registered(Event) of
		true ->
			link(Pid),
			ets:match_delete(?SERVER, {Event, Pid}),
			ets:insert(?SERVER, {Event, Pid}),
			ok;
		false ->
			{error, invalid}
	end.

do_leave(Event, Pid) ->
	unlink(Pid),
	ets:match_delete(?SERVER, {Event, Pid}),
	ok.

