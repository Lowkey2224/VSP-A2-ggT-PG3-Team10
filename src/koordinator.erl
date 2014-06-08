%%%-------------------------------------------------------------------
%%% @author Loki
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:41
%%%-------------------------------------------------------------------
-module(koordinator).
-author("Loki").

-include("constants.hrl").
-include("messages.hrl").

%% API
-export([start/0]).

  start() ->

    {ok, Config} = file:consult("nameservice.cfg"),
    {ok, Name} = werkzeug:get_config_value(name, Config),
    MyDict = dict:new(),
    State = dict:append(nsname, Name, MyDict),
    PIDggT = erlang:spawn(fun() -> init(State) end),
%%     TODO use this shit right.
    ok
  .

init(State) ->
  Name = dict:fetch(nsname, State),
  Service = koordinator,
  Node = self(),
  Name ! {self(), {?REBIND, Service, Node}},
  receive
    {?REBIND_RES, ok} ->
      werkzeug:logging(logfile, "juchu"),
      loop(State),
      ok

  end
  .

loop(State) ->
  ok
  .

sendGGTValues(PID)->
  ok
.

buildRing(State) ->
  ok
.


setPMIs(State) ->
  ok
.

startProcesses(State) ->
  ok
.

