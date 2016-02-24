#Twitter_Miner
=============

--------------------------------------------------------------------------
                                        Main
--------------------------------------------------------------------------

Compile with rebar: rebar compile

Start erl with: erl -pa deps/*/ebin -pa ebin -config twitterminer

Then start program with main:start(), will run at 3 given times each day.

Will start scheduler, handler and the loop.

Ip = "129.16.155.22".                                                                                                
Port = 8087.                                                                                                         
Bucket = <<"Alpha">>.                                                                                               
ResultBucket = <<"Result">>.

Erlang school project
