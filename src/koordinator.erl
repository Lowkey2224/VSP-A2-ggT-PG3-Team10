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

-define(TARGET, 480).

start() ->

  {ok, Config} = file:consult("nameservice.cfg"),
  {ok, Name} = werkzeug:get_config_value(name, Config),
  {ok, RegisterTime} = werkzeug:get_config_value(rt, Config),
  {ok, GgtPerStarter} = werkzeug:get_config_value(ggt_per_starter, Config),
  {ok, TimeToWait} = werkzeug:get_config_value(ttw, Config),
  {ok, TimeToTerminate} = werkzeug:get_config_value(ttt, Config),
  MyDict = dict:new(),
  State1 = dict:append(nsname, Name, MyDict),
  State2 = dict:append(rt, RegisterTime * 1000, State1),
  State3 = dict:append(ggt_per_starter, GgtPerStarter, State2),
  State4 = dict:append(ttw, TimeToWait * 1000, State3),
  State = dict:append(ttt, TimeToTerminate * 1000, State4),
  PIDggT = erlang:spawn(fun() -> init(State) end),
%%     TODO use this shit right.
  {ok, PIDggT}
.

init(State) ->
  Nameservice = dict:fetch(nsname, State),
  MyName = koordinator,
  ok = ourTools:registerWithNameService(Nameservice, MyName),
%%   Register should only run for rt seconds
  RT = dict:fetch(rt, State),
  This = self(),
%%   We dont need to remember the Timer ourselfs
  {ok, _} = timer:send_after(RT, This, {end_register, This}),
  register(State)

.

loop(State) ->
  ok
.

sendGGTValues(PID) ->
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
  Clients = dict:fetch(clients, State),
  [First|Rest1 ] = Clients,
  [Second|Rest ] = Rest1,
  StateOne = {lists:last(Rest), Second},
  StateTwo = {First, nok},
  Dict = dict:append(Second, StateTwo,dict:append(First, StateOne, dict:new())),

  Paired = buildRing(Dict, Rest,{First,Second}, First),
  sendNeighbours(Paired),
  ready(State)
.

sendNeighbours(Paired) ->
  dict:map(fun(Key, {L,R}) -> Key !  {?NEIGHBOURS, L, R}, ok end, Paired)
.

%% If the Last Element was the last Element in the List.
buildRing(Paired,[],Last,First) ->
  {LeftLast, nok} = dict:fetch(Last, Paired),
  TmpPaired = dict:erase(Last,Paired),
  dict:append(Last, {LeftLast,First}, TmpPaired)
;

buildRing(Paired, Clients, Last, First) ->
  {LeftLast, nok} = dict:fetch(Last, Paired),
  [Actual|Rest] = Clients,
  TmpPaired = dict:erase(Last,Paired),
  TmpPaired2 = dict:append(Last, {LeftLast,Actual}, TmpPaired),
  NewPaired =  dict:append(Actual, {Last,nok}, TmpPaired2),
  buildRing(NewPaired,Rest,Actual,First)
.

%% Erzeugt und setzt Mi werte fuer ggtProzesse
setPMIs(Clients, PMis) ->

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
  Clients = dict:fetch(clients,State),
  ClientCount = length(Clients),
  setPMIs(Clients, werkzeug:bestimme_mis(?TARGET, ClientCount)),
%%   NumberOfCalcs = max(2,),

  ok
.

%% repraesentiert den Register Zustand

register(State) ->
  receive
    {?GGTVALS, PID} ->
      TTW = dict:fetch(ttw, State),
      TTT = dict:fetch(ttt, State),
      GGTs = dict:fetch(ggt_per_starter, State),
      PID ! {?GGTVALS_RES, TTW, TTT, GGTs},
      register(State);
    {?CHECKIN, GgtNAme} ->

      register(addClient(State, GgtNAme));
    {end_register, self()} ->
      initPhase(State)
  end

.

initPhase(State) ->
  receive
    {step} ->
      buildRing(State)
  end.

addClient(State, Name) ->
  GgtList = dict:fetch(State, clients),
  NewList = [Name, GgtList],
  dict:append(clients, NewList, dict:erase(clients, State))
.

%% bearbeitet eine Terminierungsnachricht eines ggtProzesses
computeGGTTermination(State) ->
  ok
.

%% Informiert die ggtProzesse ueber die Terminierung des koordinators
kill(State) ->
  ok
.