%%%-------------------------------------------------------------------
%%% @author Loki
%%% @author Marilena
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:43
%%%-------------------------------------------------------------------
-module(ggTProzess).
-author("Loki").
-author("Marilena").

%% API
-export([start/0, initiateVote/2]).
-import(werkzeug, []).
-include("constants.hrl").
-include("messages.hrl").


start() ->
  receive
    {TTW, TTT, Name, Nameservice, Koordinator} ->
      State = dict:store(koordinator, Koordinator,
        dict:store(nsname, Nameservice,
          dict:store(name, Name,
            dict:store(ttt, TTT,
              dict:store(ttw, TTW, dict:new()))))),
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s und PID ~p\n", [werkzeug:timeMilliSecond(), Name, self()]),
      init(State)
  end
.

%% Initialisierung
init(State) ->
  NS = dict:fetch(nsname, State),
  Name = dict:fetch(name, State),
  ourTools:registerWithNameService(Name, NS),
  erlang:register(Name, self()),
  registerWithKoordinator(State),
  receive
    {?NEIGHBOURS, L, R} ->
      NewState = dict:store(left, L,
        dict:store(right, R, State)),
      tools:log(Name, "~p: ~p hat Linken Nachbarn ~p und rechten Nachbarn ~p\n", [werkzeug:timeMilliSecond(), Name, L,R]),
      preProcess(NewState)
  end
.



%% returns a new State
calculate(State, Number) ->
  Mi = dict:fetch(mi, State),
  TTW = dict:fetch(ttw, State),
  Timer = dict:fetch(timer, State),
Name = dict:fetch(name, State),
  StateWithoutTimer = dict:erase(timer, State),
% TODO Fehler hier
  timer:cancel(Timer),
%%   tools:log(Name, "~p: Timer ~p and cancel Result ~p\n", [werkzeug:timeMilliSecond(), Timer, Val]),
  timer:sleep(TTW),
  case Number < Mi of
    true ->
      NewMi = ((Mi - 1) rem Number) + 1,
      tools:log(Name, "~p: ~p hat neuen Wert Mi ~p\n", [werkzeug:timeMilliSecond(), Name, NewMi]),
      TempState = dict:store(mi, NewMi, StateWithoutTimer),
      NewState = sendMi(TempState),
      createTimer(NewState);
    _Else ->
      createTimer(StateWithoutTimer)
  end

.

createTimer(State) ->
L = dict:fetch(left, State),
NS =  dict:fetch(nsname, State),
  PID = ourTools:lookupNamewithNameService(L, NS),
  MyName = dict:fetch(name, State),
TTT = dict:fetch(ttt, State),
%%   {ok, NewTimer} = timer:send_after(TTT, {?VOTE, MyName}, PID),
  {ok, NewTimer} = timer:apply_after(TTT, ggTProzess, initiateVote, [MyName,PID]),
  dict:store(timer, NewTimer, State).

%% pre_process zustand
preProcess(State) ->
  Name =dict:fetch(name, State),
  receive
    {?SETPMI, Mi} ->
      TmpState = dict:store(mi, Mi, State),
      NewState = dict:store(votetime, now(), TmpState),
      tools:log(Name, "~p: ~p ~p ~p empfangen\n", [werkzeug:timeMilliSecond(), Name, ?SETPMI, Mi]),
      process(createTimer(NewState))
  end
.

%% Zustand Process
process(State) ->
%%   tools:log(foo, "~p: Processstate by PID ~p dict = ~p\n", [werkzeug:timeMilliSecond(),self(), State]),
  Name =dict:fetch(name, State),
  receive
    {?SEND, Y} ->
      tools:log(Name, "~p: ~p SEND ~p empfangen\n", [werkzeug:timeMilliSecond(),Name, Y]),
      TmpState = calculate(State, Y),
      NewState = dict:store(votetime, now(), TmpState),
      process(NewState);
    {?VOTE, Initiator} ->
      tools:log(Name, "~p: ~p VOTE von ~p empfangen\n", [werkzeug:timeMilliSecond(), Name, Initiator]),
      NewState = vote(State, Initiator),
      process(NewState);
    {?TELLMI, PID}->
      Mi = dict:fetch(mi, State),
      PID ! {?TELLMI_RES, Mi},
      process(State);
    {?WHATSON, PID} ->
      NewState = computeWhatsOn(State, PID),
      process(NewState);
    {?KILL} ->
      terminate(State)
  end
.
%% TODO
computeWhatsOn(State, PID) ->
  PID,
  error(not_implemented),
  State.

sendMi(State) ->
%%   Name =dict:fetch(name, State),
  L = dict:fetch(left, State),
  R = dict:fetch(right, State),
  Foo = dict:fetch(mi, State),
  Mi = Foo,
  NS = dict:fetch(nsname, State),
  LPID = ourTools:lookupNamewithNameService(L, NS),
%%   tools:log(Name, "~p: looked up ~p and got ~p PID: ~p\n", [werkzeug:timeMilliSecond(), L, LPID, self()]),
  RPID = ourTools:lookupNamewithNameService(R, NS),
%%   tools:log(Name, "~p: looked up ~p and got ~p PID: ~p\n", [werkzeug:timeMilliSecond(), R, RPID, self()]),
%%   tools:log(Name, "~p: ~p sende ~p ~p and ~p\n", [werkzeug:timeMilliSecond(), Name, ?SEND, Mi, L]),
  LPID ! {?SEND, Mi},
%%   tools:log(Name, "~p: ~p sende ~p ~p and ~p\n", [werkzeug:timeMilliSecond(), Name, ?SEND, Mi, R]),
  RPID ! {?SEND, Mi},
  briefMi(State)

.
%% Informiert den Koordinator ueber aenderungen von Mi
briefMi(State) ->
  Koord = dict:fetch(koordinator, State),
  Mi = dict:fetch(mi, State),
  Name = dict:fetch(name, State),
  NS = dict:fetch(nsname, State),
  PID = ourTools:lookupNamewithNameService(Koord, NS),
  tools:log(Name, "~p: ~p sende ~p ~p \n", [werkzeug:timeMilliSecond(), Name, ?BRIEFME, Mi]),
  PID ! {?BRIEFME, {Name, Mi, werkzeug:timeMilliSecond()}},
  State
.

%% Informiert den Koordinator dass der Prozess sich terminiert hat
briefTermination(State) ->
  Koord = dict:fetch(koordinator, State),
  NS = dict:fetch(nsname, State),
  Mi = dict:fetch(mi, State),
  Name = dict:fetch(name, State),
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  tools:log(Name, "~p: ~p sende ~p mit Mi ~p \n", [werkzeug:timeMilliSecond(), Name, ?BRIEFTERM, Mi]),
  PID ! {?BRIEFTERM, {Name, Mi, werkzeug:timeMilliSecond()}, self()}
.

%% Realisiert im Timer
%% Startet eine Abstimmung um alle PRozesse zu beenden.
%% startVote(State) ->
%%   ok
%% .

%% Diese Methode stimmt über die Terminierung ab
vote(State, Name) ->
  MyName = dict:fetch(name, State),
  if MyName == Name ->
      terminate(State);
    true ->
      processForeignVote(State,Name)
  end
.

processForeignVote(State, Name) ->
  MyName = dict:fetch(name, State),
  Last = dict:fetch(votetime, State),
  TTT = dict:fetch(ttt, State),
  Diff = calcDiff(Last),
  tools:log(MyName, "~p: ~p difference = ~p TTT = ~p\n", [werkzeug:timeMilliSecond(), MyName, Diff, TTT]),
  if (Diff > (TTT/2)) ->
    L = dict:fetch(left, State),
    NS = dict:fetch(nsname, State),
    PID = ourTools:lookupNamewithNameService(L,NS),
    tools:log(MyName, "~p: ~p sende ~p weiter\n", [werkzeug:timeMilliSecond(), MyName, ?VOTE]),
    PID ! {?VOTE, Name},
    State;
    true ->
      tools:log(MyName, "~p: ~p sende ~p nicht weiter\n", [werkzeug:timeMilliSecond(), MyName, ?VOTE]),
      State
  end
  .

calcDiff(Last) ->
  timer:now_diff(now(),Last)/1000
  .

terminate(State) ->
  briefTermination(State)
.

registerWithKoordinator(State) ->
  Koord = dict:fetch(koordinator, State),
  NS = dict:fetch(nsname, State),
  Name = dict:fetch(name, State),
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  PID ! {?CHECKIN, Name},
  State
.

initiateVote(Name, PID) ->
  tools:log(Name, "~p: ~p Starte ~p \n",[werkzeug:timeMilliSecond(), Name, ?VOTE]),
  PID ! {?VOTE, Name}
.