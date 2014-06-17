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
-export([start/0]).
-import(werkzeug, []).
-include("constants.hrl").
-include("messages.hrl").


start() ->
  receive
    {TTW, TTT, Name, Nameservice, Koordinator} ->
      State = dict:append(koordinator, Koordinator,
        dict:append(nsname, Nameservice,
          dict:append(name, Name,
            dict:append(ttt, TTT,
              dict:append(ttw, TTW, dict:new()))))),
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s\n", [werkzeug:timeMilliSecond(), Name]),
      init(State)
  end
.

%% Initialisierung
init(State) ->
  [NS|_] = dict:fetch(nsname, State),
  [Name|_] = dict:fetch(name, State),
  ourTools:registerWithNameService(Name, NS),
  erlang:register(Name, self()),
  registerWithKoordinator(State),
  receive
    {?NEIGHBOURS, L, R} ->
      NewState = dict:append(left, L,
        dict:append(right, R, State)),
      tools:log(Name, "~p: ~p hat Linken Nachbarn ~p und rechten Nachbarn ~p\n", [werkzeug:timeMilliSecond(), Name, L,R]),
      preProcess(NewState)
  end
.



%% returns a new State
calculate(State, Number) ->
  [Mi|_] = dict:fetch(mi, State),
  [TTW|_] = dict:fetch(ttw, State),
  [Timer|_] = dict:fetch(timer, State),
[Name|_] = dict:fetch(name, State),
  StateWithoutTimer = dict:erase(timer, State),
% TODO Fehler hier
  Val = timer:cancel(Timer),
  tools:log(Name, "~p: Timer ~p and cancel Result ~p\n", [werkzeug:timeMilliSecond(), Timer, Val]),
  timer:sleep(TTW),
  case Number < Mi of
    true ->
      NewMi = ((Mi - 1) rem Number) + 1,
      tools:log(Name, "~p: ~p hat neuen Wert Mi ~p\n", [werkzeug:timeMilliSecond(), Name, NewMi]),
      TempState = dict:store(mi, NewMi, dict:erase(mi, StateWithoutTimer)),
      NewState = sendMi(TempState),
      createTimer(NewState);
    _Else ->
      createTimer(StateWithoutTimer)
  end

.

createTimer(State) ->
[L|_] = dict:fetch(left, State),
[NS|_] =  dict:fetch(nsname, State),
  PID = ourTools:lookupNamewithNameService(L, NS),
  [MyName|_] = dict:fetch(name, State),
[TTT|_] = dict:fetch(ttt, State),
  {ok, NewTimer} = timer:send_after(TTT, {?VOTE, MyName}, PID),
  dict:append(timer, NewTimer, State).

%% pre_process zustand
preProcess(State) ->
  [Name|_] =dict:fetch(name, State),
  receive
    {?SETPMI, Mi} ->
      TmpState = dict:append(mi, Mi, State),
      NewState = dict:append(votetime, werkzeug:timeMilliSecond(), TmpState),
      tools:log(Name, "~p: ~p ~p ~p empfangen\n", [werkzeug:timeMilliSecond(), Name, ?SETPMI, Mi]),
      process(createTimer(NewState))
  end
.

%% Zustand Process
process(State) ->
[Name|_] =dict:fetch(name, State),
  receive
    {?SEND, Y} ->
      tools:log(Name, "~p: ~p SEND ~p empfangen\n", [werkzeug:timeMilliSecond(),Name, Y]),
      TmpState = calculate(State, Y),
      Tmp2 = dict:erase(votetime, TmpState),
      NewState = dict:append(votetime, werkzeug:timeMilliSecond(), Tmp2),
      process(NewState);
    {?VOTE, Initiator} ->
      tools:log(Name, "~p: ~p VOTE von ~p empfangen\n", [werkzeug:timeMilliSecond(), Name, Initiator]),
      NewState = vote(State, Initiator),
      process(NewState);
    {?TELLMI, PID}->
      [Mi|_]= dict:fetch(mi, State),
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
  error(not_implemented),
  State.

sendMi(State) ->
  [Name|_] =dict:fetch(name, State),
  [L|_] = dict:fetch(left, State),
  [R|_] = dict:fetch(right, State),
  [Mi|_] = dict:fetch(mi, State),
  [NS|_] = dict:fetch(nsname, State),
  LPID = ourTools:lookupNamewithNameService(L, NS),
  RPID = ourTools:lookupNamewithNameService(R, NS),
  tools:log(Name, "~p: ~p sende ~p ~p and ~p\n", [werkzeug:timeMilliSecond(), Name, ?SEND, Mi, L]),
  LPID ! {?SEND, Mi},
  tools:log(Name, "~p: ~p sende ~p ~p and ~p\n", [werkzeug:timeMilliSecond(), Name, ?SEND, Mi, R]),
  RPID ! {?SEND, Mi},
  briefMi(State)

.
%% Informiert den Koordinator ueber aenderungen von Mi
briefMi(State) ->
  [Koord|_] = dict:fetch(koordinator, State),
  [Mi|_] = dict:fetch(mi, State),
  [Name|_] = dict:fetch(name, State),
  [NS|_] = dict:fetch(nsname, State),
  PID = ourTools:lookupNamewithNameService(Koord, NS),
  tools:log(Name, "~p: ~p sende ~p ~p \n", [werkzeug:timeMilliSecond(), Name, ?BRIEFME, Mi]),
  PID ! {?BRIEFME, {Name, Mi, werkzeug:timeMilliSecond()}, self()},
  State
.

%% Informiert den Koordinator dass der Prozess sich terminiert hat
briefTermination(State) ->
  [Koord|_] = dict:fetch(koordinator, State),
  [NS|_] = dict:fetch(nsname, State),
  [Mi|_] = dict:fetch(mi, State),
  [Name|_] = dict:fetch(name, State),
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  PID ! {?BRIEFTERM, {Name, Mi, werkzeug:timeMilliSecond()}, self()}
.

%% Realisiert im Timer
%% Startet eine Abstimmung um alle PRozesse zu beenden.
%% startVote(State) ->
%%   ok
%% .

%% Diese Methode stimmt über die Terminierung ab
vote(State, Name) ->
  [MyName|_] = dict:fetch(name, State),
  case MyName =:= Name of
    true ->
      terminate(State);
    _Else ->
      Now = werkzeug:timeMilliSecond(),
      [Last|_] = dict:fetch(votetime, State),
      [TTT|_] = dict:fetch(ttt, State),
      Diff = Now-Last,
      if (Diff > (TTT/2)) ->
        [L|_] = dict:fetch(left, State),
        [NS|_] = dict:fetch(nsname, State),
        PID = ourTools:lookupNamewithNameService(L,NS),
        PID ! {?VOTE, Name}
        end

  end
.

terminate(State) ->
  briefTermination(State)
.

registerWithKoordinator(State) ->
  [Koord|_] = dict:fetch(koordinator, State),
  [NS|_] = dict:fetch(nsname, State),
  [Name|_] = dict:fetch(name, State),
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  PID ! {?CHECKIN, Name},
  State
.