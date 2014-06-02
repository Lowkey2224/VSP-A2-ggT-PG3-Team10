%%%-------------------------------------------------------------------
%%% @author Loki
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Jun 2014 11:42
%%%-------------------------------------------------------------------
-module(starter).
-author("Loki").
%% -import(nameservice,[]).
%% -import(werkzeug,[]).

-include("constants.hrl").
-include("messages.hrl").


%% API
-export([start/0]).


start() ->
  nameservice:start(),
  {ok, Config} = file:consult("nameservice.cfg"),
  {ok, Name} = werkzeug:get_config_value(name, Config),
  werkzeug:logging("LogFileStarter", io_lib:format("Nameserver started with name ~s",[Name])),
  koordinator:start()
  .
