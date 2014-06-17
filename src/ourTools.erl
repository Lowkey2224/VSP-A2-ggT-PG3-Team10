
%%%-------------------------------------------------------------------
%%% @author Loki
%%% @author Marilena
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Jun 2014 14:36
%%%-------------------------------------------------------------------
-module(ourTools).
-author("Loki").
-author("Marilena").
-include("constants.hrl").
-include("messages.hrl").

%% API
-export([registerWithNameService/2, lookupNamewithNameService/2, unbindOnNameService/2]).

%% Name, Nameservice
registerWithNameService(Name, Nameservice) ->


  PID = global:whereis_name(Nameservice),
  PID ! {self(), {?REBIND, Name, node()}},
  receive
    {?REBIND_RES, ok} ->
%%       werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("Service ~p ist nun bekannt\n", [Name])),
      ok
  end
  .
%% Name, Nameservice
lookupNamewithNameService(Name, Nameservice) ->
PID = global:whereis_name(Nameservice),
  PID ! {self(), {?LOOKUP, Name }},
  receiveLookupAnswer(Name)
.

receiveLookupAnswer(_) ->
  receive
    {?LOOKUP_RES, ?UNDEFINED} ->
%%       werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("Service ~s ist unbekannt\n", [Name])),
      ?UNDEFINED;
    {?LOOKUP_RES, {Name2, Node}} ->
%%        werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("Service ~p wurde gefunden in: ~p\n", [Name, Node])),
% 	werkzeug:logging(logfile, "Gefunden!\n"),
      {Name2, Node}
%%   ;
%%     Any ->
%%       werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("~p: Komische Nachricht ~p PID ~p\n", [werkzeug:timeMilliSecond(), Any, self()])),
%%       receiveLookupAnswer(Name)
  end
  .

%% Name, Nameservice
unbindOnNameService(Name, Nameservice) ->
PID = global:whereis_name(Nameservice),
  PID ! {self(), {?UNBIND, Name }},
  receive
    {nok} ->
%%       werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("Service ~s ist unbekannt\n", [Name])),
      {nok, ?UNDEFINED};
    {?UNBIND_RES, PID} ->
%%       werkzeug:logging(list_to_atom(lists:concat([logfile,Name])), io_lib:format("Service ~s wurde entfernt in: ~p\n", [Name, PID])),
      PID
  end
.
