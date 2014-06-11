
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
      werkzeug:logging(logfile, io_lib:format("Service ~p ist nun bekannt\n", [Name])),
      ok
  end
  .
%% Name, Nameservice
lookupNamewithNameService(Name, Nameservice) ->
PID = global:whereis_name(Nameservice),
  PID ! {self(), {?LOOKUP, Name }},
  receive
    {?LOOKUP_RES, ?UNDEFINED} ->
      werkzeug:logging(logfile, io_lib:format("Service ~p ist unbekannt\n", [Name])),
      {nok, ?UNDEFINED};
    {?LOOKUP_RES, PID} ->
      werkzeug:logging(logfile, io_lib:format("Service ~p wurde gefunden in: ~p\n", [Name, PID])),
      {ok, PID}
  end
.

%% Name, Nameservice
unbindOnNameService(Name, Nameservice) ->
PID = global:whereis_name(Nameservice),
  PID ! {self(), {?UNBIND, Name }},
  receive
    {nok} ->
      werkzeug:logging(logfile, io_lib:format("Service ~p ist unbekannt\n", [Name])),
      {nok, ?UNDEFINED};
    {?LOOKUP_RES, PID} ->
      werkzeug:logging(logfile, io_lib:format("Service ~p wurde entfernt in: ~p\n", [Name, PID])),
      {ok, PID}
  end

.