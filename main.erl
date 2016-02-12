-module(main).
-export([scheduler/0, start_link_handler/0, start/0, start_link_scheduler/0, stop_scheduler/0, init/0, loop/0]).

%% erl -pa /home/erlach/riak-erlang-client/ebin/ /home/erlach/riak-erlang-client/deps/*/ebin

%% -----------------------------------------------------------------------
%% Main
%% -----------------------------------------------------------------------
%% Start erl with command below.
%% erl -pa deps/*/ebin -pa ebin -config twitterminer
%% Run with main:start(), will run at 2 given times each day.
%% Will start scheduler, handler module and the supervisor_loop.
%% Stop function will exit the given process name(registered name).
%% -----------------------------------------------------------------------

%% Start

start() -> 
    case whereis(starter) of
        undefined ->
            process_flag(trap_exit, true),
            register(starter, Pid = spawn_link(?MODULE, init, [])),
            application:ensure_all_started(twitterminer),
            start_link_scheduler(),
            start_link_handler(),
            {ok, Pid, "Program started"};
        Pid ->
            {ok, Pid, "Program already running"}
    end.            

%% Scheduler
scheduler() ->
    {{_,_,_},{H, M, _}} = calendar:local_time(),
    receive
        after 10000 ->
            ok
    end,
    case {H, M} of 
        {15, 20} -> 
            twitterminer_riak:twitter_example(), 
            handler ! {self(), start}, 
            scheduler();
        {15, 23} -> 
            twitterminer_riak:twitter_example(), 
            handler ! {self(), start}, 
            scheduler();
        {14, 23} -> 
            twitterminer_riak:twitter_example(), 
            handler ! {self(), start}, 
            scheduler();
        {H, M} -> scheduler()
    end.
    
%% Handler
start_link_handler() ->
    case whereis(handler) of
        undefined ->
            process_flag(trap_exit, true),
            register(handler, Pid = spawn_link(handler, loop, [])),
            {ok, Pid};
        Pid -> 
            {ok, Pid}
    end.

%% Scheduler
start_link_scheduler() ->
    case whereis(scheduler) of
        undefined ->
            process_flag(trap_exit, true),
            register(scheduler, Pid = spawn_link(?MODULE, scheduler, [])),
            {ok, Pid};
        Pid -> 
            {ok, Pid}
    end.

%% Stop scheduler
stop_scheduler() -> 
    case whereis(scheduler) of
        undefined -> 
            already_stopped;
        Pid -> 
            true = exit(Pid, stop),
            stopped
    end.

%% Init
init() ->
    Pid=spawn_link(?MODULE, loop, []),
    register(looper, Pid).

%% Loop 
loop() ->
    case whereis(loop) of
        undefined -> error;
        Pid ->
           receive
                {'EXIT', Pid, _} -> 
                    start(),
                    loop();
                {'EXIT', scheduler, _} ->
                    start_link_scheduler(),
                    loop();
                {'EXIT', starter, _} ->
                    start(),
                    loop()
            end
    end.
