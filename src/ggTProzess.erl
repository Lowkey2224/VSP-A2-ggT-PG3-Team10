%%%-------------------------------------------------------------------
%%% @author Loki
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:43
%%%-------------------------------------------------------------------
-module(ggTProzess).
-author("Loki").

%% API
-export([start/0]).
-import(werkzeug,[]).
-include("constants.hrl").
-include("messages.hrl").


start() ->
  receive
    {TTW, TTT, Name, Nameservice, Koordinator} ->
      State = dict:append(koordinator,Koordinator,
      dict:append(nsname,Nameservice,
      dict:append(name,Name,
      dict:append(ttt,TTT,
      dict:append(ttw,TTW, dict:new()))))),
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s",[werkzeug:timeMilliSecond(), Name]),
      init(State)
  end
.

%% Initialisierung
init(State) ->
  NS = dict:fetch(nsname, State),
  Name = dict:fetch(name, State),
  ourTools:registerWithNameService(Name,NS),
  registerWithKoordinator(State),
  receive
    {?NEIGHBOURS, L, R} ->
      NewState = dict:append(left, L,
      dict:append(right, R, State)),
      preProcess(NewState)
  end
.




kill() ->

  ok.


calculate(State, Number) ->
  Mi = dict:fetch(mi, State),
  TTW = dict:fetch(ttw, State),
  Timer = dict:fetch(timer, State),
  NewState2 = dict:erase(timer, State),
  {ok, cancel} = timer:cancel(Timer),
  timer:sleep(TTW),
  case Number < Mi of
    true ->
      NewMi = ((Mi - 1) rem Number) + 1,
      TempState = dict:store(mi, NewMi, dict:erase(mi, NewState2)),
      NewState = sendMi(TempState),
    PID = ourTools:lookupNamewithNameService(dict:fetch(left, NewState), dict:fetch(nsname, NewState)),
     MyPid = self(),
    NewTimer = timer:send_after(dict:fetch(ttt, NewState), {?VOTE, MyPid}, PID),
    RealState = dict:append(timer, NewTimer, NewState);
    _Else ->
      NewState = NewState2,
      PID = ourTools:lookupNamewithNameService(dict:fetch(left, NewState), dict:fetch(nsname, NewState)),
      MyPid = self(),
      NewTimer = timer:send_after(dict:fetch(ttt, NewState), {?VOTE, MyPid}, PID),
      RealState = dict:append(timer, NewTimer, NewState)
  end

.

%% pre_process zustand
preProcess(State) ->
  receive
    {?SETPMI, Mi} ->
      NewState = dict:append(mi, Mi,State),
      process(NewState)
  end
.

%% Zustand Process
process(State) ->
  receive
    {send, Y} ->
      NewState = calculate(State, Y)
  end
.

sendMi(State) ->
  L = dict:fetch(left, State),
  R = dict:fetch(right, State),
  Mi = dict:fetch(mi, State),
  NS = dict:fetch(nsname, State),
  LPID = ourTools:lookupNamewithNameService(L,NS),
  RPID = ourTools:lookupNamewithNameService(R,NS),
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
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  PID ! {?BRIEFME,{Name, Mi, werkzeug:timeMilliSecond()}, self()},
  State
.

%% Informiert den Koordinator dass der Prozess sich terminiert hat
briefTermination(State) ->
  ok
.

%% Startet eine Abstimmung um alle PRozesse zu beenden.
startVote(State) ->
  ok
.

%% Diese Methode stimmt über die Terminierung ab
vote(State) ->
  ok
.

terminate(State) ->
  ok
.

registerWithKoordinator(State) ->
  ok
.