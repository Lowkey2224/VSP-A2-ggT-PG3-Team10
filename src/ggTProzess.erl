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
    {?SETPMI, Mi} ->
      NewState = dict:append(mi, Mi, State),
      preProcess(NewState)
  end
.

loop(State) ->
  receive
    kill -> kill();
    {calculate, Number} ->
      NewState = calculate(State, Number),
      loop(NewState)
  end
.


kill() ->
  global:unregister_name(?PROCESSNAME),
  ok.


calculate(State, Number) ->
  Mi = dict:fetch(mi, State),
  case Number < Mi of
    true ->
      NewMi = ((Mi - 1) rem Number) + 1,
      TempState = dict:store(mi, NewMi, dict:erase(mi, State)),
      NewState = sendMi(TempState);
    _Else ->
      NewState = State
  end
.

%% pre_process zustand
preProcess(State) ->
  ok
.

%% Zustand Process
process(State) ->
  ok
.

sendMi(State) ->
  error(not_implemented)
.
%% Informiert den Koordinator ueber aenderungen von Mi
briefMi(State) ->
  ok
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