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

  {ok, Config} = file:consult("ggT.cfg"),
  {ok, Node} = werkzeug:get_config_value(erl_node, Config),
  {ok, Koordinator_name} = werkzeug:get_config_value(koordinatorname, Config),
  {ok, Praktikumsgruppe} = werkzeug:get_config_value(nr_praktikumsgruppe, Config),
  {ok, Teamnummer} = werkzeug:get_config_value(nr_team, Config),
  MyDict = dict:new(),
  MyDict2 = dict:append(nameservice, Node, MyDict),
  MyDict3 = dict:append(koordinatorname, Koordinator_name, MyDict2),
  MyDict4 = dict:append(nr_praktikumsgr, Praktikumsgruppe, MyDict3),
  MyDict5 = dict:append(nr_team, Teamnummer, MyDict4),
  getConfigValues(MyDict5)
.

getConfigValues(State) ->

  Koordinator = dict:fetch(koordinatorname, State),
  KoordinatorPID = ourTools:lookupNamewithNameService(Koordinator, dict:fetch(nameservice, State)),
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
      startGGTProcesses(GGTs, State5)
  end

end

.

startGGTProcesses(0, State) ->
  terminate(State);

startGGTProcesses(NumberOfProcesses, State) ->
  PID = erlang:spawn(fun() -> ggTProzess:init() end),
  TTW = dict:fetch(ttw, State),
  TTT = dict:fetch(ttt, State),
  Praktikumsgruppe = dict:fetch(nr_praktikumsgruppe, State),
  TEAM = dict:fetch(nr_team, State),
  Starternumber = dict:fetch(starter_number, State),
  Startnummer = Praktikumsgruppe + TEAM + NumberOfProcesses + "_" + Starternumber,
  Nameservice = dict:fetch(nameservice, State),
  Koordinator = dict:fetch(koordinatorname, State),

  PID ! {TTW, TTT, Startnummer, Nameservice, Koordinator},
  startGGTProcesses(NumberOfProcesses - 1, State)
.

terminate(State) ->
  ok
.