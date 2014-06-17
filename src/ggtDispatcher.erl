%%%-------------------------------------------------------------------
%%% @author Loki
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. Jun 2014 18:56
%%%-------------------------------------------------------------------
-module(ggtDispatcher).
-author("Loki").

%% API
-export([start/0]).

-include("constants.hrl").
-include("messages.hrl").


start() ->
  receive
    {TTW, TTT, Name, Nameservice, Koordinator} ->
      State = dict:append(koordinator, Koordinator,
        dict:append(nsname, Nameservice,
          dict:append(name, Name,dict:new()))),
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s\n", [werkzeug:timeMilliSecond(), Name]),

      init(State, TTW, TTT)
  end
.

init(State) ->
  [NS|_] = dict:fetch(nsname, State),
  [Name|_] = dict:fetch(name, State),
  ourTools:registerWithNameService(Name, NS),
  erlang:register(Name, self()),
  registerWithKoordinator(State),
  receive
    {?NEIGHBOURS, L, R} ->
      NewState = dict:append(left, L,
        dict:append(right, R, State)),
      tools:log(Name, "~p: ~p hat Linken Nachbarn ~p und rechten Nachbarn ~p\n", [werkzeug:timeMilliSecond(), Name, L,R]),
      preProcess(NewState)
  end
.
