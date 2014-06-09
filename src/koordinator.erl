%%%-------------------------------------------------------------------
%%% @author Loki
%%% @author Marilena
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:41
%%%-------------------------------------------------------------------
-module(koordinator).
-author("Loki").
-author("Marilena").
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
  case State of
    register ->
    sendGGTValues(),
  end
  .

loop(State) ->
  ok
  .

sendGGTValues(PID)->
  receive
    get_ggt_vals ->
        {ok, Config} = file:consult("koordinator.cfg"),
        {ok, Regtime} = werkzeug:get_config_value(rt, Config),
        {ok, Anz_ggt} = werkzeug:get_config_value(anz_ggt, Config),
        {ok, Delay} = werkzeug:get_config_value(ttw, Config),
        {ok, Termtime} = werkzeug:get_config_value(ttt, Config),
        NewDict = dict:new(),
        Registertime = dict:append(rt, Regtime, NewDict),
        Anzahl_ggt = dict:append(anz_ggt, Anz_ggt, NewDict),
        Delaytime = dict:append(ttw, Delay, NewDict),
        Terminatetime = dict:append(ttt, Termtime, NewDict),
        starter ! {ggt_vals, {Registertime, Anzahl_ggt, Delaytime, Terminatetime}},
  end
.

buildRing(State) ->
  ok
.

%% Erzeugt und setzt Mi werte fuer ggtProzesse
setPMIs(State) ->
  ok
.

%% Startet die ggtBerechnung
startCalculation(State) ->
  ok
.


terminate(State) ->
  ok
.

%% Die Funktion die den Ready zustant repraesentiert.
ready(State) ->
  ok
.

%% repraesentiert den Register Zustand
register(State) ->
  ok
.

%% bearbeitet eine Terminierungsnachricht eines ggtProzesses
computeGGTTermination(State) ->
  ok
.

%% Informiert die ggtProzesse ueber die Terminierung des koordinators
kill(State) ->
  ok
.