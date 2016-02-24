-module(twitterminer_riak).

-export([twitter_example/0, twitter_save_pipeline/3, get_riak_hostport/1]).

-record(hostport, {host, port}).

% This file contains example code that connects to Twitter and saves tweets to Riak.
% It would benefit from refactoring it together with twitterminer_source.erl.

keyfind(Key, L) ->
  {Key, V} = lists:keyfind(Key, 1, L),
  V.

%% @doc Get Twitter account keys from a configuration file.
get_riak_hostport(Name) ->
  {ok, Nodes} = application:get_env(twitterminer, riak_nodes),
  {Name, Keys} = lists:keyfind(Name, 1, Nodes),
  #hostport{host=keyfind(host, Keys),
            port=keyfind(port, Keys)}.

%% @doc This example will download a sample of tweets and print it.
twitter_example() ->
  URL = "https://stream.twitter.com/1.1/statuses/sample.json",

  % We get our keys from the twitterminer.config configuration file.
  Keys = twitterminer_source:get_account_keys(account1),

  %RHP = get_riak_hostport(riak1),
  {ok, R} = riakc_pb_socket:start("129.16.155.22", 8087),
  % {ok, R} = riakc_pb_socket:start_link(RHP#hostport.host, RHP#hostport.port)

  % Run our pipeline
  P = twitterminer_pipeline:build_link(twitter_save_pipeline(R, URL, Keys)),

  % If the pipeline does not terminate after 60 s, this process will
  % force it.
  T = spawn_link(fun () ->
        receive
          cancel -> ok
        after 60000 -> % Sleep fo 60 s
            twitterminer_pipeline:terminate(P)
        end
    end),
  %supervisor_loop ! {self(), start, extracting_completed},
  Res = twitterminer_pipeline:join(P),
  T ! cancel,
  Res.

%% @doc Create a pipeline that connects to twitter and
%% saves tweets to Riak. We save all messages that have ids,
%% which might include delete notifications etc.
twitter_save_pipeline(R, URL, Keys) ->


  Prod = twitterminer_source:twitter_producer(URL, Keys),

  % Pipelines are constructed 'backwards' - consumer is first, producer is last.
  [
    twitterminer_pipeline:consumer(
      fun(Msg, N) -> save_tweet(R, Msg), N+1 end, 0),
    twitterminer_pipeline:map(
      fun twitterminer_source:decorate_with_id/1),
    twitterminer_source:split_transformer(),
    Prod].

% We save only objects that have ids.
%% Save tweet with updated secondary index
save_tweet(R, {parsed_tweet, _L, B, {id, I}}) ->
  Timestamp = timestampYMD(),
  Bucket = <<"Alpha">>,
  Key = list_to_binary(integer_to_list(I)),
  Hashtag = twitterminer_source:filter(B),
  case Hashtag of
    [] -> empty_tag_not_sent;
    _ -> Value = {I, Timestamp, Hashtag},  % {I, {}, X}
    io:format("Value: ~p~n", [Value]),
    Obj = riakc_obj:new(Bucket, Key, Value),
    MetaData = riakc_obj:get_update_metadata(Obj),
    ObjSecondary = riakc_obj:set_secondary_index(MetaData, 
      [{{binary_index, "Timestamp"}, [Timestamp]},
      {{binary_index, "Hashtags"}, [Hashtag]}]),
    NewObj = riakc_obj:update_metadata(Obj, ObjSecondary),
    riakc_pb_socket:put(R, NewObj)
  end;

save_tweet(_, _) -> ok.

%% Timetamp in year-month-day format
timestampYMD() ->
  {{Year, Month, Day}, _} = calendar:local_time(),
    Format = "~4.10.0B-~2.10.0B-~2.10.0B",
    IsoFormat = io_lib:format(Format, [Year, Month, Day]),
    list_to_binary(IsoFormat).

