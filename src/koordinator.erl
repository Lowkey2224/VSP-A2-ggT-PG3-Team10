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

  {ok, Config} = file:consult("koordinator.cfg"),
  {ok, Name} = werkzeug:get_config_value(nameservicename, Config),
  {ok, RegisterTime} = werkzeug:get_config_value(rt, Config),
  {ok, GgtPerStarter} = werkzeug:get_config_value(ggt_per_starter, Config),
  {ok, TimeToWait} = werkzeug:get_config_value(ttw, Config),
  {ok, TimeToTerminate} = werkzeug:get_config_value(ttt, Config),
  net_adm:ping(Name),
  NSPID = global:whereis_name(Name),
%   tools:log(koordinator, "Nameservicepid = ~p, fuer ~p \n",[NSPID, Name]),
  MyDict = dict:new(),
  State1 = dict:append(nsname, Name, MyDict),
  State2 = dict:append(rt, RegisterTime * 1000, State1),
  State3 = dict:append(ggt_per_starter, GgtPerStarter, State2),
  State4 = dict:append(ttw, TimeToWait * 1000, State3),
  State5 = dict:append(ttt, TimeToTerminate * 1000, State4),
  State = dict:append(startercount, 0, State5),
  init(State)
.

init(State) ->
   [Nameservice|_] = dict:fetch(nsname, State),
  MyName = koordinator,
%   tools:log(koordinator, "Nameservice = ~p, My Name = ~s\n",[Nameservice, MyName]),
  ok = ourTools:registerWithNameService(MyName, Nameservice),
%%   Register should only run for rt seconds
  [RT|_] = dict:fetch(rt, State),
  This = self(),
%%   We dont need to remember the Timer ourselfs
  {ok, _} = timer:send_after(RT, This, {end_register, This}),
  register(State)

.

buildRing(State) ->
  [Clients|_] = dict:fetch(clients, State),
  [First | Rest1] = Clients,
  [Second | Rest] = Rest1,
  StateOne = {lists:last(Rest), Second},
  StateTwo = {First, nok},
  Dict = dict:append(Second, StateTwo, dict:append(First, StateOne, dict:new())),

  Paired = buildRing(Dict, Rest, {First, Second}, First),
  [NSName|_] = dict:fetch(nsname, State),
  sendNeighbours(Paired, NSName),
  ready(State)
.

sendNeighbours(Paired, NSName) ->

  dict:map(fun(Key, {L, R}) -> {ok, PID} = ourTools:lookupNamewithNameService(Key, NSName), PID ! {?NEIGHBOURS, L, R},
    ok end, Paired)
.

%% If the Last Element was the last Element in the List.
buildRing(Paired, [], Last, First) ->
  [{LeftLast, nok}|_] = dict:fetch(Last, Paired),
  TmpPaired = dict:erase(Last, Paired),
  dict:append(Last, {LeftLast, First}, TmpPaired)
;

buildRing(Paired, Clients, Last, First) ->
  [{LeftLast, nok}|_] = dict:fetch(Last, Paired),
  [Actual | Rest] = Clients,
  TmpPaired = dict:erase(Last, Paired),
  TmpPaired2 = dict:append(Last, {LeftLast, Actual}, TmpPaired),
  NewPaired = dict:append(Actual, {Last, nok}, TmpPaired2),
  buildRing(NewPaired, Rest, Actual, First)
.

%% Erzeugt und setzt Mi werte fuer ggtProzesse
setPMIs([], [], _) ->
  ok;
setPMIs(Clients, PMis, NSName) ->
  [Client | ClientRest] = Clients,
  [Mi | Rest] = PMis,
%%   TODO auf nok testen
  {ok, ClientPID} = ourTools:lookupNamewithNameService(Client, NSName),
  ClientPID ! {?SETPMI, Mi},
  setPMIs(ClientRest, Rest, NSName)
.

%% Select n Random Clients
selectRandomClients(_, [], Chosen, _) ->
  Chosen;
selectRandomClients(_, _, Chosen, 0) ->
  Chosen;
selectRandomClients(State, Clients, ChosenClients, NumberOfCalcs) ->
  Index = random:uniform(length(Clients)),
  Client1 = lists:nth(Index, Clients),
  NewClients = lists:delete(Client1, Clients),
  selectRandomClients(State, NewClients, [Client1 | ChosenClients], NumberOfCalcs - 1)

.

%% Die Funktion die den Ready zustant repraesentiert.


ready(State) ->
  [Clients|_] = dict:fetch(clients, State),
  [NSName|_] = dict:fetch(nsname, State),
  ClientCount = length(Clients),
  receive
    {?CALC, Target} ->
      NewState = dict:append(target, Target, State),
      setPMIs(Clients, werkzeug:bestimme_mis(Target, ClientCount), NSName),
      NumberOfCalcs = max(2, ClientCount * 0.15),
      Chosen = selectRandomClients(NewState, Clients, [], NumberOfCalcs),
      startChosenClients(Target, Chosen, NSName),
      receive
        {?BRIEFME, {GgtName, Mi, Time}} ->
          tools:log(koordinator, "~p: ggtNode ~p meldet neues Mi: ~s", [Time, GgtName, Mi]);
        {?BRIEFTERM, {GgtName, Mi, Time}, PID} ->
          computeGGTTermination(NewState, GgtName, Mi, Time, PID);
        {?RESET} ->
          reset(NewState);
        {?PROMPT} ->
          tell_mi(NewState);
        {?WHATSON} ->
          whats_on(NewState);
        {?TOGGLE} ->
          ok;
        {?KILL} ->
          kill(NewState)
      end

  end,
  ok
.

whats_on(State) ->
  [NS|_] = dict:fetch(nsname, State),
  Fun = fun(X) ->
    PID = ourTools:lookupNamewithNameService(X, NS),
    PID ! {?WHATSON, self()},
    receive
      {?WHATSON_RES, GGTState} ->
        tools:log(koordinator, "~p: ggtNode ~p meldet hat Zustand: ~p (abgefragt durch tell_mi)\n", [werkzeug:timeMilliSecond(), X, GGTState])
    end
  end,
  [Clients|_] = dict:fetch(clients, State),
  lists:map(Fun, Clients)
.

tell_mi(State) ->
  [NS|_] = dict:fetch(nsname, State),
  Fun = fun(X) ->
    PID = ourTools:lookupNamewithNameService(X, NS),
    PID ! {?TELLMI, self()},
    receive
      {?TELLMI_RES, Mi} ->
        tools:log(koordinator, "~p: ggtNode ~p meldet hat Mi: ~s (abgefragt durch tell_mi)\n", [werkzeug:timeMilliSecond(), X, Mi])
    end
  end,
  [Clients|_] = dict:fetch(clients, State),
  lists:map(Fun, Clients)
.
startChosenClients(_, [], _) ->
  ok;
startChosenClients(Target, Chosen, NSName) ->
  [GgT | Rest] = Chosen,
  Y = werkzeug:bestimme_mis(Target, 1),
  PID = ourTools:lookupNamewithNameService(GgT, NSName),
  PID ! {?SEND, Y},
  startChosenClients(Target, Rest, NSName)
.

%% repraesentiert den Register Zustand

register(State) ->
 MyPid= self(),
  receive
    {?GGTVALS, PID} ->
      [TTW|_] = dict:fetch(ttw, State),
      [TTT|_] = dict:fetch(ttt, State),
      [GGTs|_] = dict:fetch(ggt_per_starter, State),
      PID ! {?GGTVALS_RES, TTW, TTT, GGTs},
      register(State);

    {get_starter_number, PID} ->
      [Number|_] = dict:fetch(startercount, State) + 1,
      TmpState = dict:erase(startercount, State),
      NewState = dict:append(startercount, Number, TmpState),
      PID ! {starter_number, Number},
      register(NewState)
  ;
    {?CHECKIN, GgtNAme} ->

      register(addClient(State, GgtNAme));
    {end_register, MyPid} ->
      initPhase(State)
  end

.

initPhase(State) ->
  receive
    {step} ->
      buildRing(State)
  end.

addClient(State, Name) ->
  [GgtList|_] = dict:fetch(State, clients),
  NewList = [Name, GgtList],
  dict:append(clients, NewList, dict:erase(clients, State))
.

%% bearbeitet eine Terminierungsnachricht eines ggtProzesses
computeGGTTermination(State, GgtName, Mi, Time, PID) ->
  tools:log(koordinator, "~p: ggtNode ~p  an ~p meldet terminierung mit Ergebnis: ~s", [Time, GgtName, PID, Mi]),
  State
.

%% Informiert die ggtProzesse ueber die Terminierung des koordinators
kill(State) ->
  [GgtList|_] = dict:fetch(State, clients),
  [Ns|_] = dict:fetch(nsname, clients),
  tools:log(koordinator, "~p: Sende Kill an alle GGT PRozesse\n", [werkzeug:timeMilliSecond()]),
  stopAllGGTs(GgtList, Ns),
  ourTools:unbindOnNameService(koordinator, Ns),
  ok
.

reset(State) ->
  ok = kill(State),
  start()
.
stopAllGGTs([], _) ->
  ok;
stopAllGGTs(Clients, NS) ->
  [Client | Rest] = Clients,
  Pid = ourTools:lookupNamewithNameService(Client, NS),
  Pid ! {?KILL},
  stopAllGGTs(Rest, NS)
.