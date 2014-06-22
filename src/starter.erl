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
-export([start/0]).


start() ->

  {ok, Config} = file:consult("ggt.cfg"),
  {ok, NS} = werkzeug:get_config_value(nameservicename, Config),
  pong = net_adm:ping(NS),
  timer:sleep(1000), %%Add a sleep because ping seems to work too slow.
%%   global:whereis_name(nameservice),
  {ok, Koordinator_name} = werkzeug:get_config_value(koordinatorname, Config),
  {ok, Praktikumsgruppe} = werkzeug:get_config_value(nr_praktikumsgruppe, Config),
  {ok, Teamnummer} = werkzeug:get_config_value(nr_team, Config),
  MyDict = dict:new(),
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
  KoordinatorPID ! {?GGTVALS, self()},
  receive
    {?GGTVALS_RES, TTW, TTT, GGTs} ->
      State2 = dict:append(ttw, TTW, State),
      State3 = dict:append(ttt, TTT, State2),
      State4 = dict:append(ggts, GGTs, State3),
      KoordinatorPID ! {get_starter_number, self()},
      receive
        {starter_number, Number} ->
      State5 = dict:append(starter_number, Number, State4),
      startGGTProcesses(GGTs, State5);
	Any ->
	werkzeug:logging(logfile, io_lib:format("komische antwort: ~p \n", [Any]))
  end

end

.

startGGTProcesses(0, State) ->
  terminate(State);

startGGTProcesses(NumberOfProcesses, State) ->
  PID = erlang:spawn(ggtDispatcher, ggtDispatcher:start(), []),
  [TTW|_] = dict:fetch(ttw, State),
  [TTT|_] = dict:fetch(ttt, State),
  [Praktikumsgruppe|_] = dict:fetch(nr_praktikumsgr, State),
  [TEAM|_] = dict:fetch(nr_team, State),
  [Starternumber|_] = dict:fetch(starter_number, State),
  Startnummer = list_to_atom(lists:concat([Praktikumsgruppe , TEAM , NumberOfProcesses , "_" , Starternumber])),
  [Nameservice|_] = dict:fetch(nameservice, State),
  [Koordinator|_] = dict:fetch(koordinatorname, State),

  PID ! {TTW, TTT, Startnummer, Nameservice, Koordinator},
  startGGTProcesses(NumberOfProcesses - 1, State)
.

terminate(State) ->
  State,
  ok
.