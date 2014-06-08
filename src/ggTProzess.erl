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
-export([]).
-import(werkzeug,[]).
-include("constants.hrl").
-include("messages.hrl").
-define(LOGFILE, "ggTLogFile").
-define(PROCESSNAME, "ggTLogFile").

init(Mi) ->

  Known = global:whereis_name(?PROCESSNAME),
  case Known of
    undefined ->
      MyDict = dict:new(),
      State = dict:append(mi, Mi, MyDict),
      PIDggT = erlang:spawn(fun() -> loop(State) end),
      global:register_name(?PROCESSNAME, PIDggT),


      werkzeug:logging(?LOGFILE, io_lib:format("~p Client service erfolgreich gestartet mit PID: ~p\n", [werkzeug:timeMilliSecond(), PIDggT]));
    _NotUndef -> {ok, ?PROCESSNAME}
  end,
  {ok, ?PROCESSNAME}
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