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
-define(MYNAME, koordinator310).


start() ->

  {ok, Config} = file:consult("koordinator.cfg"),
  {ok, Nameservice} = werkzeug:get_config_value(nameservicename, Config),
  {ok, RegisterTime} = werkzeug:get_config_value(rt, Config),
  {ok, GgtPerStarter} = werkzeug:get_config_value(ggt_per_starter, Config),
  {ok, TimeToWait} = werkzeug:get_config_value(ttw, Config),
  {ok, TimeToTerminate} = werkzeug:get_config_value(ttt, Config),
  global:register_name(?MYNAME, self()),
erlang:register(?MYNAME, self()),
%%   NSPID = global:whereis_name(Name),
%   tools:log(?MYNAME, "Nameservicepid = ~p, fuer ~p \n",[NSPID, Name]),
  MyDict = dict:new(),
%%   net_adm:ping(Nameservice),
  NSPID = global:whereis_name(Nameservice),
  State1 = dict:append(nsname, NSPID, MyDict),
  State2 = dict:append(rt, RegisterTime * 1000, State1),
  State3 = dict:append(ggt_per_starter, GgtPerStarter, State2),
  State4 = dict:append(ttw, TimeToWait * 1000, State3),
  State5 = dict:append(ttt, TimeToTerminate * 1000, State4),
  State6 = dict:append(clients, [], State5),
  State = dict:append(startercount, 0, State6),
  init(State)
.

init(State) ->
   [Nameservice|_] = dict:fetch(nsname, State),  
   tools:log(?MYNAME, "Nameservice = ~p, My Name = ~s\n",[Nameservice, ?MYNAME]),
  ok = ourTools:registerWithNameService(?MYNAME, Nameservice),
%%   Register should only run for rt seconds
  [RT|_] = dict:fetch(rt, State),
  This = self(),
%%   We dont need to remember the Timer ourselfs
  {ok, _} = timer:send_after(RT, This, {end_register, This}),
  tools:log(?MYNAME, "~p: ~p wechselt in Register Mode.\n", [werkzeug:timeMilliSecond(), ?MYNAME]),
  register(State)

.

sendNeighbours(Paired, NSName) ->
% TODO Pruefen ob das wirklich funktionioert
  dict:map(fun(Key, [{L, R}|_]) -> PID = ourTools:lookupNamewithNameService(Key, NSName), PID ! {?NEIGHBOURS, L, R},
    ok end, Paired)
.

buildRing(State) ->
  [Clients|_] = dict:fetch(clients, State),
  tools:log(?MYNAME, "~p: Baue Ring auf mit ~p.\n", [werkzeug:timeMilliSecond(), Clients]),
  [First | Rest1] = Clients,
  [Second | Rest] = Rest1,
  StateOne = {lists:last(Rest), Second},
  StateTwo = {First, nok},
  Dict = dict:append(Second, StateTwo, dict:append(First, StateOne, dict:new())),

  Paired = buildRing(Dict, Rest, Second, First),
  [NSName|_] = dict:fetch(nsname, State),
  sendNeighbours(Paired, NSName),
  tools:log(?MYNAME, "~p: Wechselt in Ready State\n", [werkzeug:timeMilliSecond()]),
  ready(State)
.


%% If the Last Element was the last Element in the List.
buildRing(Paired, [], Last, First) ->
  [{LeftLast, nok}|_] = dict:fetch(Last, Paired),
  TmpPaired = dict:erase(Last, Paired),
   tools:log(?MYNAME, "~p: Ring aufgebaut\n", [werkzeug:timeMilliSecond()]),
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
  ClientPID = ourTools:lookupNamewithNameService(Client, NSName),
tools:log(?MYNAME, "~p: Sende Mi ~p and ~p\n", [werkzeug:timeMilliSecond(), Mi, Client]),
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
      tools:log(?MYNAME, "~p: Calc mit Targeet ~p erhalten \n", [werkzeug:timeMilliSecond(), Target]),
      NewState = dict:append(target, Target, State),
      setPMIs(Clients, werkzeug:bestimme_mis(Target, ClientCount), NSName),
      tools:log(?MYNAME, "~p: Mis an die GGT Prozesse  verschickt.\n", [werkzeug:timeMilliSecond()]),
      NumberOfCalcs = max(2, ClientCount * 0.15),
      Chosen = selectRandomClients(NewState, Clients, [], NumberOfCalcs),
      tools:log(?MYNAME, "~p: ~p zufaellige GGTs ausgewaehtl.\n", [werkzeug:timeMilliSecond(), NumberOfCalcs]),
      startChosenClients(Target, Chosen, NSName),
      tools:log(?MYNAME, "~p: Berechnugn gestartet\n", [werkzeug:timeMilliSecond()]),
      receive
        {?BRIEFME, {GgtName, Mi, Time}} ->
          tools:log(?MYNAME, "~p: ggtNode ~p meldet neues Mi: ~p", [Time, GgtName, Mi]);
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
          kill(NewState);
         X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X])
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
        tools:log(?MYNAME, "~p: ggtNode ~p meldet hat Zustand: ~p (abgefragt durch tell_mi)\n", [werkzeug:timeMilliSecond(), X, GGTState])
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
        tools:log(?MYNAME, "~p: ggtNode ~p meldet hat Mi: ~p (abgefragt durch tell_mi)\n", [werkzeug:timeMilliSecond(), X, Mi])
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
       tools:log(?MYNAME, "~p: ~p hat Anfrage GGTVALS bekommen von PID: ~p\n", [werkzeug:timeMilliSecond(), ?MYNAME, PID]),
      [TTW|_] = dict:fetch(ttw, State),
      [TTT|_] = dict:fetch(ttt, State),
      [GGTs|_] = dict:fetch(ggt_per_starter, State),
	tools:log(?MYNAME, "~p: Sende TTW: ~p, TTT:~p, Anzahl GGTs pro Starter: ~p \n", [werkzeug:timeMilliSecond(), TTW, TTT, GGTs]),
      PID ! {?GGTVALS_RES, TTW, TTT, GGTs},
      register(State);

    {get_starter_number, PID} ->
      [NN|_] = dict:fetch(startercount, State),
      Number = NN+1,
      TmpState = dict:erase(startercount, State),
      NewState = dict:append(startercount, Number, TmpState),
      tools:log(?MYNAME, "~p: Starter fragt nach Starternummer: ~p\n", [werkzeug:timeMilliSecond(), Number]),
      PID ! {starter_number, Number},
      register(NewState)
  ;
    {?CHECKIN, GgtNAme} ->
	tools:log(?MYNAME, "~p: Client ~p meldet sich an\n", [werkzeug:timeMilliSecond(), GgtNAme]),
      register(addClient(State, GgtNAme));
    {end_register, MyPid} ->
      tools:log(?MYNAME, "~p: Koordinator geht in initialisierungsphase\n", [werkzeug:timeMilliSecond()]),
      initPhase(State);
    X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X])
  end

.

initPhase(State) ->
  receive
    {step} ->
      tools:log(?MYNAME, "~p: Koordinator hat Step erhalten und baut den Ring auf\n", [werkzeug:timeMilliSecond()]),
      buildRing(State);
     X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X])

  end.

addClient(State, Name) ->
	{Status,_} = dict:find(clients,State),
  Clients =  if Status == ok ->
	[List|_] = dict:fetch(clients,State),
	List;
  Status =/= ok -> []
end,



%   [GgtList|_] = dict:fetch(clients, State),
  NewList = [Name| Clients],
  dict:append(clients, NewList, dict:erase(clients, State))
.

%% bearbeitet eine Terminierungsnachricht eines ggtProzesses
computeGGTTermination(State, GgtName, Mi, Time, PID) ->
  tools:log(?MYNAME, "~p: ggtNode ~p  an ~p meldet terminierung mit Ergebnis: ~p", [Time, GgtName, PID, Mi]),
  State
.

%% Informiert die ggtProzesse ueber die Terminierung des koordinatorss
kill(State) ->
  [GgtList|_] = dict:fetch(State, clients),
  [Ns|_] = dict:fetch(nsname, clients),
  tools:log(?MYNAME, "~p: Sende Kill an alle GGT PRozesse\n", [werkzeug:timeMilliSecond()]),
  stopAllGGTs(GgtList, Ns),
  ourTools:unbindOnNameService(?MYNAME, Ns),
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