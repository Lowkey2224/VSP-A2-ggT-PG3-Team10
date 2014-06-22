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
      State = dict:store(koordinator, Koordinator,
        dict:store(nsname, Nameservice,
          dict:store(name, Name,
            dict:store(ttt, TTT,
              dict:store(ttw, TTW,
                dict:store(parent, self(), dict:new())))))),
      tools:log(Name, "~p ggtProzess erfolgreich gestartet mit Namen: ~s\n", [werkzeug:timeMilliSecond(), Name]),
      Worker = spawn_link(ggTProzess, init, [State]),
      MyState = dict:store(koordinator, Koordinator,
        dict:store(nsname, Nameservice,
          dict:store(worker, Worker,
            dict:store(name, Name,dict:new())))),
      init(MyState)
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
      dict:fetch(worker, State) ! {?NEIGHBOURS, L, R},
      preProcess(State)
  end
.

%% pre_process zustand
preProcess(State) ->
  receive
    {?SETPMI, Mi} ->
      process(dict:store(mi, Mi, State))
  end
.

%% Zustand Process
process(State) ->
  Worker = dict:fetch(worker, State),
%%   tools:log(foo, "~p: Processstate by PID ~p dict = ~p\n", [werkzeug:timeMilliSecond(),self(), State]),
  receive
    {?SEND, Y} ->
      Worker ! {?SEND, Y},
      process(State);
    {?VOTE, Initiator} ->
      Worker ! {?VOTE, Initiator},
      process(State);
    {?TELLMI, PID}->
      Mi = dict:fetch(mi, State),
      PID ! {?TELLMI_RES, Mi},
      process(State);
    {?WHATSON, PID} ->
      PID ! {?WHATSON_RES, dict:fetch(status, State)},
      process(State);
    {?KILL} ->
      terminate(State);
%%       Schnittstelle fuer den ggTProzess
    {giff_mi, Mi} ->
      process(dict:store(mi, Mi, State));
    {giff_status, Status} ->
      process(dict:store(status, Status, State))
  end
.

registerWithKoordinator(State) ->
  Koord = dict:fetch(koordinator, State),
  NS = dict:fetch(nsname, State),
  Name = dict:fetch(name, State),
  PID = ourTools:lookupNamewithNameService(Koord,NS),
  PID ! {?CHECKIN, Name},
  State
.

terminate(State) ->
  Name = dict:fetch(name, State),
  tools:log(Name, "~p: ~p abmelden vom Namensservice.\n", [werkzeug:timeMilliSecond(), Name]),
  Result = ourTools:unbindOnNameService(Name, dict:fetch(nsname, State)),
  tools:log(Name, "~p: ~p beendet sich nach Antwort ~p von NS beim Abmelden.\n", [werkzeug:timeMilliSecond(), Name, Result]),
  exit(dict:fetch(worker, State), kill)
.