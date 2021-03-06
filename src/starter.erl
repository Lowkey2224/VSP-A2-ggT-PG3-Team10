%%%-------------------------------------------------------------------
%%% @author Loki
%%% @author Marilena
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:42
%%%-------------------------------------------------------------------
-module(starter).
-author("Loki").
-author("Marilena").
%% -import(nameservice,[]).
%% -import(werkzeug,[]).

-include("constants.hrl").
-include("messages.hrl").


%% API
-export([start/1]).


start(Number) ->

  {ok, Config} = file:consult("ggt.cfg"),
  {ok, NS} = werkzeug:get_config_value(nameservicename, Config),
  pong = net_adm:ping(NS),
  timer:sleep(1000), %%Add a sleep because ping seems to work too slow.
  global:whereis_name(nameservice),
  {ok, Koordinator_name} = werkzeug:get_config_value(koordinatorname, Config),
  {ok, Praktikumsgruppe} = werkzeug:get_config_value(nr_praktikumsgruppe, Config),
  {ok, Teamnummer} = werkzeug:get_config_value(nr_team, Config),
  MyDict = dict:append(starter_number, Number,dict:new()),
  MyDict2 = dict:append(nameservice, NS, MyDict),
  MyDict3 = dict:append(koordinatorname, Koordinator_name, MyDict2),
  MyDict4 = dict:append(nr_praktikumsgr, Praktikumsgruppe, MyDict3),
  MyDict5 = dict:append(nr_team, Teamnummer, MyDict4),
  getConfigValues(MyDict5)
.

getConfigValues(State) ->

  [Koordinator|_] = dict:fetch(koordinatorname, State),
  [NS|_]=dict:fetch(nameservice, State),
%   werkzeug:logging(logfile, io_lib:format("Nameservice hat namen: ~p \n", [NS])),
  KoordinatorPID = ourTools:lookupNamewithNameService(Koordinator, NS),
%   werkzeug:logging(logfile, io_lib:format("Nachricht and Koordinator geschickt: ~p \n", [?GGTVALS])),
  io:format(io_lib:format("Frage nach ~p\n", [?GGTVALS])),

  KoordinatorPID ! {?GGTVALS, self()},
  receive
    {?GGTVALS_RES, TTW, TTT, GGTs} ->
      io:format(io_lib:format("Antwort TTW ~p, TTT ~p, GGTs ~p \n", [TTW, TTT, GGTs])),
      State2 = dict:append(ttw, TTW, State),
      State3 = dict:append(ttt, TTT, State2),
      State4 = dict:append(ggts, GGTs, State3),
%%       io:format(io_lib:format("Frage nach Starternummer\n", [])),
%%       KoordinatorPID ! {get_starter_number, self()},
%%       receive
%%         {starter_number, Number} ->
%%       State5 = dict:append(starter_number, Number, State4),
%%           io:format(io_lib:format("Starternummer ~p erhalten \n", [Number])),
      startGGTProcesses(GGTs, State4);
	    Any ->
	    werkzeug:logging(logfile, io_lib:format("komische antwort: ~p \n", [Any]))
end
.

startGGTProcesses(0, State) ->
  terminate(State);

startGGTProcesses(NumberOfProcesses, State) ->
  PID = erlang:spawn(fun() -> ggtDispatcher:start() end),
%%   io:format(io_lib:format("Dispatcher Nr ~p gestartet mit PID ~p \n", [NumberOfProcesses, PID])),
  [TTW|_] = dict:fetch(ttw, State),
  [TTT|_] = dict:fetch(ttt, State),
  [Praktikumsgruppe|_] = dict:fetch(nr_praktikumsgr, State),
  [TEAM|_] = dict:fetch(nr_team, State),
  [Starternumber|_] = dict:fetch(starter_number, State),
  Startnummer = list_to_atom(lists:concat([Praktikumsgruppe , TEAM , NumberOfProcesses , "_" , Starternumber])),
  [Nameservice|_] = dict:fetch(nameservice, State),
  [Koordinator|_] = dict:fetch(koordinatorname, State),

  PID ! {TTW, TTT, Startnummer, Nameservice, Koordinator},
%%   io:format(io_lib:format("GGTVals an ggt Uebermittelt \n", [])),
  startGGTProcesses(NumberOfProcesses - 1, State)
.

terminate(State) ->
  State,
  ok
.