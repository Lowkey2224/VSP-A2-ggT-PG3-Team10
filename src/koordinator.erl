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
-define(MYNAME, coordinator).


start() ->

  {ok, Config} = file:consult("koordinator.cfg"),
  {ok, Name} = werkzeug:get_config_value(nameservicename, Config),
  {ok, RegisterTime} = werkzeug:get_config_value(rt, Config),
  {ok, GgtPerStarter} = werkzeug:get_config_value(ggt_per_starter, Config),
  {ok, TimeToWait} = werkzeug:get_config_value(ttw, Config),
  {ok, TimeToTerminate} = werkzeug:get_config_value(ttt, Config),
  Known = global:whereis_name(?MYNAME),
   tools:log(?MYNAME, "registered ~p \n",[Known]),

  if Known == undefined->
    io:format(io_lib:format("Muss neu registrieren\n", [])),
    erlang:register(?MYNAME, self()),
    global:register_name(?MYNAME, self());
    true ->
      io:format(io_lib:format("Alles cool\n", []))
  end,

  net_adm:ping(Name),
  timer:sleep(1000),
%%   global:whereis_name(nameservice),

%%   NSPID = global:whereis_name(Name),
%   tools:log(?MYNAME, "Nameservicepid = ~p, fuer ~p \n",[NSPID, Name]),
  MyDict = dict:store(result, 999999,dict:new()),
  State1 = dict:store(nsname, Name, MyDict),
  State2 = dict:store(rt, RegisterTime * 1000, State1),
  State3 = dict:store(ggt_per_starter, GgtPerStarter, State2),
  State4 = dict:store(ttw, TimeToWait, State3),
  State5 = dict:store(ttt, TimeToTerminate, State4),
  State6 = dict:store(clients, [], State5),
  State = dict:store(startercount, 0, State6),
  init(State)
.

init(State) ->
   Nameservice = dict:fetch(nsname, State),
%   tools:log(?MYNAME, "Nameservice = ~p, My Name = ~s\n",[Nameservice, MyName]),
  ok = ourTools:registerWithNameService(?MYNAME, Nameservice),
%%   Register should only run for rt seconds
  RT = dict:fetch(rt, State),
  This = self(),
%%   We dont need to remember the Timer ourselfs
  {ok, _} = timer:send_after(RT, This, {end_register, This}),
  tools:log(?MYNAME, "~p: ~p wechselt in Register Mode.\n", [werkzeug:timeMilliSecond(), ?MYNAME]),
  register(State)

.

sendNeighbours(Paired, NSName) ->
% TODO Pruefen ob das wirklich funktionioert
  dict:map(fun(Key, {L, R}) -> PID = ourTools:lookupNamewithNameService(Key, NSName), PID ! {?NEIGHBOURS, L, R},
    ok end, Paired)
.

buildRing(State) ->
  Clients = dict:fetch(clients, State),
  tools:log(?MYNAME, "~p: Baue Ring auf mit ~p Clients.\n", [werkzeug:timeMilliSecond(), length(Clients)]),
  [First | Rest1] = Clients,
  [Second | Rest] = Rest1,
  StateOne = {lists:last(Rest), Second},
  StateTwo = {First, nok},
  Dict = dict:store(Second, StateTwo, dict:store(First, StateOne, dict:new())),

  Paired = buildRing(Dict, Rest, Second, First),
  NSName = dict:fetch(nsname, State),
  sendNeighbours(Paired, NSName),
  tools:log(?MYNAME, "~p: Wechselt in Ready State\n", [werkzeug:timeMilliSecond()]),
  ready(State)
.


%% If the Last Element was the last Element in the List.
buildRing(Paired, [], Last, First) ->
  {LeftLast, nok} = dict:fetch(Last, Paired),
  TmpPaired = dict:erase(Last, Paired),
  Ring = dict:store(Last, {LeftLast, First}, TmpPaired),
  tools:log(?MYNAME, "~p: Ring aufgebaut\n", [werkzeug:timeMilliSecond()]),
  Ring
;

buildRing(Paired, Clients, Last, First) ->
  {LeftLast, nok} = dict:fetch(Last, Paired),
  [Actual | Rest] = Clients,
  TmpPaired = dict:erase(Last, Paired),
  TmpPaired2 = dict:store(Last, {LeftLast, Actual}, TmpPaired),
  NewPaired = dict:store(Actual, {Last, nok}, TmpPaired2),
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

  receive
    {?CALC, Target} ->
      insideReady(startCalc(State, Target))
  end,
  ok
.

startCalc(State, Target) ->
  Clients = dict:fetch(clients, State),
  NSName = dict:fetch(nsname, State),
  ClientCount = length(Clients),
  tools:log(?MYNAME, "~p: Calc mit Target ~p erhalten \n", [werkzeug:timeMilliSecond(), Target]),
  NewState = dict:store(target, Target, State),
  setPMIs(Clients, werkzeug:bestimme_mis(Target, ClientCount), NSName),
  tools:log(?MYNAME, "~p: Mis an die GGT Prozesse  verschickt.\n", [werkzeug:timeMilliSecond()]),
  NumberOfCalcs = max(2, ClientCount * 0.15),
  Chosen = selectRandomClients(NewState, Clients, [], NumberOfCalcs),
  tools:log(?MYNAME, "~p: ~p zufaellige GGTs ausgewaehtl und eine Liste von Laenge ~p.\n", [werkzeug:timeMilliSecond(), NumberOfCalcs, length(Chosen)]),
  startChosenClients(Target, Chosen, NSName),
  tools:log(?MYNAME, "~p: Berechnung gestartet\n", [werkzeug:timeMilliSecond()]),
  NewState

.

insideReady(State) ->
%%   io:format(io_lib:format("Inside Ready\n", [])),
  receive
    {?BRIEFME, {GgtName, Mi, Time}} ->
      tools:log(?MYNAME, "~p: ggtNode ~p meldet neues Mi: ~p\n", [Time, GgtName, Mi]),
      insideReady(State);
    {?BRIEFTERM, {GgtName, Mi, Time}, PID} ->
      computeGGTTermination(State, GgtName, Mi, Time, PID);
    {?RESET} ->
      reset(State);
    {?PROMPT} ->
      insideReady(tell_mi(State));
    {?WHATSON} ->
      insideReady(whats_on(State));
    {?TOGGLE} ->
      insideReady(toggle(State));
    {?KILL} ->
      tools:log(?MYNAME, "~p: ~p erhalten!\n", [werkzeug:timeMilliSecond(),?KILL]),
      killggTs(State),
      terminate(State);
    X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X]),
      insideReady(State);
    {?CALC, Target} ->
      insideReady(startCalc(State, Target))
  end
  .

toggle(State) ->
  IsKEy = dict:is_key(toggle, State),
  if IsKEy == false ->
    tools:log(?MYNAME, "~p: Toggle Gesetzt\n", [werkzeug:timeMilliSecond()]),
    dict:store(toggle, true, State);
    true ->
      tools:log(?MYNAME, "~p: Toggle entfernt\n", [werkzeug:timeMilliSecond()]),
      dict:erase(toggle, State)
  end.


whats_on(State) ->
  NS = dict:fetch(nsname, State),
  Fun = fun(X) ->
    PID = ourTools:lookupNamewithNameService(X, NS),
    PID ! {?WHATSON, self()},
    receive
      {?WHATSON_RES, GGTState} ->
        tools:log(?MYNAME, "~p: ggtNode ~p meldet hat Zustand: ~p (abgefragt durch ~p)\n", [werkzeug:timeMilliSecond(), X, GGTState, ?WHATSON])
    end
  end,
  Clients = dict:fetch(clients, State),
  lists:map(Fun, Clients),
State
.

tell_mi(State) ->
  NS = dict:fetch(nsname, State),
  Fun = fun(X) ->
    PID = ourTools:lookupNamewithNameService(X, NS),
    PID ! {?TELLMI, self()},
    receive
      {?TELLMI_RES, Mi} ->
        tools:log(?MYNAME, "~p: ggtNode ~p meldet hat Mi: ~p (abgefragt durch tell_mi)\n", [werkzeug:timeMilliSecond(), X, Mi])
    end
  end,
  Clients = dict:fetch(clients, State),
  lists:map(Fun, Clients),
  State
.
startChosenClients(_, [], _) ->
  ok;
startChosenClients(Target, Chosen, NSName) ->
  [GgT | Rest] = Chosen,
  [Y|_] = werkzeug:bestimme_mis(Target, 1),
  PID = ourTools:lookupNamewithNameService(GgT, NSName),
  tools:log(?MYNAME, "~p: ~p schickt ~p ~p an: ~p\n", [werkzeug:timeMilliSecond(), ?MYNAME,?SEND, Y, PID]),
  PID ! {?SEND, Y},
  startChosenClients(Target, Rest, NSName)
.

%% repraesentiert den Register Zustand

register(State) ->
 MyPid= self(),
  receive
    {?GGTVALS, PID} ->
       tools:log(?MYNAME, "~p: ~p hat Anfrage GGTVALS bekommen von PID: ~p\n", [werkzeug:timeMilliSecond(), ?MYNAME, PID]),
      TTW = dict:fetch(ttw, State),
      TTT = dict:fetch(ttt, State),
      GGTs = dict:fetch(ggt_per_starter, State),
	tools:log(?MYNAME, "~p: Sende TTW: ~p, TTT:~p, Anzahl GGTs pro Starter: ~p \n", [werkzeug:timeMilliSecond(), TTW, TTT, GGTs]),
      PID ! {?GGTVALS_RES, TTW, TTT, GGTs},
      register(State);

    {get_starter_number, PID} ->
      NN = dict:fetch(startercount, State),
      Number = NN+1,
      TmpState = dict:erase(startercount, State),
      NewState = dict:store(startercount, Number, TmpState),
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
    X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X]),
      register(State)
  end

.

initPhase(State) ->
  receive
    {step} ->
      tools:log(?MYNAME, "~p: Koordinator hat Step erhalten und baut den Ring auf\n", [werkzeug:timeMilliSecond()]),
      buildRing(State);
    {reset} ->
      reset(State);
     X -> tools:log(?MYNAME, "~p: Nachricht nicht vertanden! ~p\n", [werkzeug:timeMilliSecond(),X]),
       initPhase(State)

  end.

addClient(State, Name) ->
	{Status,_} = dict:find(clients,State),
  Clients =  if Status == ok ->
	List = dict:fetch(clients,State),
	List;
  Status =/= ok -> []
end,



%   GgtList = dict:fetch(clients, State),
  NewList = [Name| Clients],
  dict:store(clients, NewList, dict:erase(clients, State))
.

%% bearbeitet eine Terminierungsnachricht eines ggtProzesses
computeGGTTermination(State, GgtName, Mi, Time, PID) ->
  tools:log(?MYNAME, "~p: ggtNode ~p  an ~p meldet terminierung mit Ergebnis: ~p\n", [Time, GgtName, PID, Mi]),

  IsKEy = dict:is_key(clients, State),
  if IsKEy == false ->
    %insideReady(killggTs(State));
    insideReady(State);
    true ->
      Res  = dict:fetch(result, State),
      Ns = dict:fetch(nsname, State),
      if Res < Mi ->
        GGTPID = ourTools:lookupNamewithNameService(GgtName, Ns),
        GGTPID ! {?SEND, Res},
        insideReady(State);
        true ->
          %insideReady(killggTs(State))
	  insideReady(State)
      end
  end

.

%% Informiert die ggtProzesse ueber die Terminierung des koordinatorss
killggTs(State) ->
  IsKEy = dict:is_key(clients, State),
  if IsKEy == false ->
    State;
    true ->
      GgtList = dict:fetch(clients, State),
      Ns = dict:fetch(nsname, State),
      tools:log(?MYNAME, "~p: Sende Kill an alle GGT PRozesse\n~p\n", [werkzeug:timeMilliSecond(), GgtList]),
      NewGGTList = stopAllGGTs(GgtList, Ns),
      dict:store(clients, NewGGTList, State)
  end
.

terminate(State)->
  Ns = dict:fetch(nsname, State),
  ourTools:unbindOnNameService(?MYNAME, Ns)
.

reset(State) ->
  killggTs(State),
  start()
.
stopAllGGTs([], _) ->
  [];
stopAllGGTs(Clients, NS) ->
  [Client | Rest] = Clients,
  io:format(io_lib:format("Suche Client ~p\n", [Client])),
  Pid = ourTools:lookupNamewithNameService(Client, NS),
  tools:log(?MYNAME, "~p: Sende Kill an ~p \n", [werkzeug:timeMilliSecond(),Pid]),
  Pid ! ?KILL,
  stopAllGGTs(Rest, NS)
.
