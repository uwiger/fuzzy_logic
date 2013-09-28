-module(crane).

-compile(export_all).

-compile({parse_transform, inline}).
-compile(inline).
-compile({inline_size,100}).

-inline_module(fuz). 

test(N, D, A) when N > 1 ->
    {T,R} = timer:tc(?MODULE, test, [N,D,A,undefined]),
    {T/N, R}.

test(N, D, A, _R) when N > 0 ->
    test(N-1, D, A, regulate(D, A));
test(_, _, _, R) ->
    R.

regulate(Distance, Angle) ->
    fuz:defuzzify(fuz:eval_rules(control(Distance, Angle), ?MODULE)).

-define(distance(T, N, Ps), fuz:set(T, {distance,N}, -10, 40, Ps)).

%% Values taken from Von Altrock, pg 41
distance(far) ->
    ?distance(s, {distance, far}, {15, 24});
distance(medium) ->
    ?distance(pi, {distance, medium}, {5, 5, 15, 24});
distance(close) ->
    ?distance(lambda, {distance, close}, {0, 5, 10});
distance(zero) ->
    ?distance(lambda, {distance,zero}, {-5, 0, 5});
distance(too_far) ->
    ?distance(z, {distance,too_far}, {nil, 0}).

-define(angle(T, N, Ps), fuz:set(T, {angle,N}, -90, 90, Ps)).

%% Values from Von Altrock, pg 41
angle(pos_big) ->
    ?angle(s, pos_big, {10, 60});
angle(pos_small) ->
    ?angle(lambda, pos_small, {0, 10, 60});
angle(zero) ->
    ?angle(lambda, zero, {-10, 0, 10});
angle(neg_small) ->
    ?angle(lambda, neg_small, {-60, -10, 0});
angle(neg_big) ->
    ?angle(z, neg_big, {-60, -10}).

-define(power(T, N, Ps), fuz:defuz_method(
			   'COM',fuz:set(T, {power, N}, -30, 30, Ps))).
%% Values from Von Altrock, pp. 41-42
power(neg_high) ->
    ?power(lambda, neg_high, {-30, -27, -8});
power(neg_medium) ->
    ?power(lambda, neg_medium, {-27, -8, 0});
power(zero) ->
    ?power(lambda, zero, {-8, 0, 8});
power(pos_medium) ->
    ?power(lambda, pos_medium, {0, 8, 27});
power(pos_high) ->
    ?power(lambda, pos_high, {8, 27, 30}).

%%
%% control() -> [{IF, THEN}].
%% IF :: = {'AND', [IfCond]} | {'OR', [IfCond]}
%% THEN ::= ThenCond
%% IfCond ::= {Variable, Value, LinguisticValue}
%% ThenCond ::= {Variable, LingusticValue}
%%
control(D, A) ->
    [{{'AND', [{distance, D, far}, {angle, A, zero}]},
      {power, pos_medium}},
     {{'AND', [{distance, D, far}, {angle, A, neg_small}]},
      {power, pos_high}},
     {{'AND', [{distance, D, medium}, {angle, A, neg_small}]},
      {power, pos_high}},
     {{'AND', [{distance, D, medium}, {angle, A, neg_big}]},
      {power, pos_medium}},
     {{'AND', [{distance, D, close}, {angle, A, pos_small}]},
      {power, neg_medium}},
     {{'AND', [{distance, D, close}, {angle, A, zero}]},
      {power, zero}},
     {{'AND', [{distance, D, close}, {angle, A, neg_small}]},
      {power, pos_medium}},
     {{'AND', [{distance, D, zero}, {angle, A, pos_small}]},
      {power, neg_medium}},
     {{'AND', [{distance, D, zero}, {angle, A, zero}]},
      {power, zero}}].
