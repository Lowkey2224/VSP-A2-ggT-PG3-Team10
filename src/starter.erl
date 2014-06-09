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
  {ok, Koordinator_name} = werkzeug:get_config_value(koordinator_name, Config),
  {ok, Praktikumsgruppe} = werkzeug:get_config_value(nr_praktikumsgruppe, Config),
  {ok, Teamnummer} = werkzeug:get_config_value(nr_team, Config),
  .

getConfigValues(State) ->
    case State of
        register ->
        koordinator ! get_ggt_vals,
        receive
              ggt_vals ->
%%%           TODO liste von daten annehmen
        end
     end
     startGGTProcesses(Anzahl_ggt)
.

startGGTProcesses(NumberOfProcesses) ->
  ?PROCESSNAME ! {ttw, ttt, startnummer,nsname, Service} %aus der liste vom koordinator s.o.
.

terminate(State) ->
  error(not_implemented)
.