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
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s", [werkzeug:timeMilliSecond(), Name]),
      init(State)
  end
.

%% Initialisierung
init(State) ->
  NS = dict:fetch(nsname, State),
  Name = dict:fetch(name, State),
  ourTools:registerWithNameService(Name, NS),
  registerWithKoordinator(State),
  receive
    {?NEIGHBOURS, L, R} ->
      NewState = dict:append(left, L,
        dict:append(right, R, State)),
      preProcess(NewState)
  end
.



%% returns a new State
calculate(State, Number) ->
  Mi = dict:fetch(mi, State),
  TTW = dict:fetch(ttw, State),
  Timer = dict:fetch(timer, State),
  StateWithoutTimer = dict:erase(timer, State),
  {ok, cancel} = timer:cancel(Timer),
  timer:sleep(TTW),
  case Number < Mi of
    true ->
      NewMi = ((Mi - 1) rem Number) + 1,
      TempState = dict:store(mi, NewMi, dict:erase(mi, StateWithoutTimer)),
      NewState = sendMi(TempState),
      createTimer(NewState);
    _Else ->
      createTimer(StateWithoutTimer)
  end

.

createTimer(State) ->
  PID = ourTools:lookupNamewithNameService(dict:fetch(left, State), dict:fetch(nsname, State)),
  MyName = dict:fetch(name, State),
  NewTimer = timer:send_after(dict:fetch(ttt, State), {?VOTE, MyName}, PID),
  dict:append(timer, NewTimer, State).

%% pre_process zustand
preProcess(State) ->
  receive
    {?SETPMI, Mi} ->
      TmpState = dict:append(mi, Mi, State),
      NewState = dict:append(votetime, werkzeug:timeMilliSecond(), TmpState),
      process(createTimer(NewState))
  end
.

%% Zustand Process
process(State) ->
  receive
    {?SEND, Y} ->
      TmpState = calculate(State, Y),
      Tmp2 = dict:erase(votetime, TmpState),
      NewState = dict:append(votetime, werkzeug:timeMilliSecond(), Tmp2),
      process(NewState);
    {?VOTE, Name} ->
      NewState = vote(State, Name),
      process(NewState);
    {?TELLMI, PID}->
      PID ! {?TELLMI_RES, dict:fetch(mi, State)},
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
  L = dict:fetch(left, State),
  R = dict:fetch(right, State),
  Mi = dict:fetch(mi, State),
  NS = dict:fetch(nsname, State),
  LPID = ourTools:lookupNamewithNameService(L, NS),
  RPID = ourTools:lookupNamewithNameService(R, NS),
  LPID ! {?SEND, Mi},
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
  PID ! {?BRIEFME, {Name, Mi, werkzeug:timeMilliSecond()}, self()},
  State
.

%% Informiert den Koordinator dass der Prozess sich terminiert hat
briefTermination(State) ->
  Koord = dict:fetch(koordinator, State),
  NS = dict:fetch(nsname, State),
  Mi = dict:fetch(mi, State),
  Name = dict:fetch(name, State),
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
  MyName = dict:fetch(name, State),
  case MyName =:= Name of
    true ->
      terminate(State);
    _Else ->
      Now = werkzeug:timeMilliSecond(),
      Last = dict:fetch(votetime, State),
      TTT = dict:fetch(ttt, State),
      Diff = Now-Last,
      if (Diff > (TTT/2)) ->
        L = dict:fetch(left, State),
        NS = dict:fetch(nsname, State),
        PID = ourTools:lookupNamewithNameService(L,NS),
        PID ! {?VOTE, Name}
        end

  end
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