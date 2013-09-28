-module(fuz).

-compile(export_all).
-export([set/5,
	 defuz_method/2]).

-ifndef(FUZ_HRL).
-include("fuz.hrl").
-endif.

-ifdef(debug).
-define(rpt(In, Out),
	io:format("(~p:~p) ~p -> ~p.~n", [?MODULE, ?LINE, In, Out])).
-else.
-define(rpt(In, Out), no_debug).
-endif.


do(N, M, F, A) when N >= 1->
    eval(M, F, A),
    do(N-1, M, F, A);
do(_, M, F, A) ->
    eval(M, F, A).

%%
%% This function originally stored sets in an ets table.
%% Currently, it merely returns the calculated set
%% so that one may hand-code it into a callback module.
%% The ets table idea is probably a good one while
%% we're running experiments to find the right values.
%%
set_mbf(_Set, MBF) when is_record(MBF, mbf) ->
    MBF.

%%
%% set(Type, Set, Min, Max, Points).
%%   pi     : {Point10, Point11, Point21, Point20}
%%   z      : {Point1, Point2}
%%   s      : {Point1, Point2}
%%   lambda : {Point1, Max, Point2}
%%   points : [{X1,Y1}]
%%
%% Calculate a fuzzy set. This function recognizes the most
%% common simplified sets: pi, s-type, z-type, lambda-type.
%% 'points' allows for point definitions a la FTL.
%% The output is an optimized set (with the values needed for
%% fast fuzzyfication/defuzzyfication.
%%
set(pi, Set, Min, Max, {Low1, High1, High2, Low2}) ->
    set_mbf(Set, #mbf{name = Set,
		      min = Min,
		      max = Max,
		      point1 = Low1,
		      slope1 = slope(High1, Low1),
		      point2 = High2,
		      slope2 = slope(High2, Low2),
		      area = (High1-Low1)/2 + (High2-High1) + (Low2-High2)/2});
set(z, Set, Min, Max, {Point1, Point2}) ->
    set_mbf(Set, #mbf{name = Set,
		      min = Min,
		      max = Max,
		      point1 = nil,
		      slope1 = 0,
		      point2 = Point2,
		      slope2 = slope(Point1, Point2),
		      area = ((Point1-Min) +
			      (Point2-Point1)/2)});
set(s, Set, Min, Max, {Point1, Point2}) ->
    set_mbf(Set, #mbf{name = Set,
		      min = Min,
		      max = Max,
		      point1 = Point1,
		      slope1 = slope(Point2, Point1),
		      point2 = Point2,
		      slope2 = 0,
		      area = ((Point2-Point1)/2 +
			      (Max-Point2))});
set(lambda, Set, Min, Max, {Point1, MaxP, Point2}) ->
    set_mbf(Set, #mbf{name = Set,
		      min = Min,
		      max = Max,
		      point1 = Point1,
		      slope1 = slope(MaxP, Point1),
		      point2 = MaxP,
		      slope2 = slope(MaxP, Point2),
		      area = (Point2-Point1)/2});
set(points, Set, Min, Max,
    [{Min, 1}, {P1, 1}, {P2, 0}, {Max, 0}]) ->
    set(z, Set, Min, Max, {P1, P2});
set(points, Set, Min, Max,
   [{Min, 0}, {P1, 0}, {P2, 1}, {P3, 0}, {Max, 0}]) ->
    set(lambda, Set, Min, Max, {P1, P2, P3});
set(points, Set, Min, Max,
   [{Min, 0}, {P1, 0}, {P2, 1}, {P3, 1}, {P4, 0}, {Max, 0}]) ->
    set(pi, Set, Min, Max, {P1, P2, P3, P4});
set(points, Set, Min, Max,
   [{Min, 0}, {P1, 0}, {P2, 1}, {Max, 1}]) ->
    set(s, Set, Min, Max, {P1, P2}).

defuz_method(M, #mbf{}=S) when M=='COM';
			       M=='MOM' ->
    S#mbf{defuz_method = M}.

display(MBF) ->
    Elems = record_info(fields, mbf),
    [_|Vals] = tuple_to_list(MBF),
    {mbf, merge_lists(Elems,Vals)}.

merge_lists([H1|T1],[H2|T2]) -> [{H1,H2}|merge_lists(T1,T2)];
merge_lists([],[]) -> [].

%%
%% eval(Module, Function, Args) -> Value | {Var, TypicalValue}
%%
%% Evaluate rules returned by apply(Module, Function, Args).
%% The function should contain rules which all produce the
%% same output variable.
%%
eval(M, F, Args) ->
    Rules = apply(M, F, Args),
    R = eval_rules(Rules, M),
    defuzzify(R).

eval_rules([{{Op, Conds}, Then}|T], M) ->
    case eval_if(Conds, Op, M, []) of
	0 ->
	    ?rpt({Op, Conds}, 0),
	    eval_rules(T, M);
	Res ->
	    ?rpt({Op, Conds}, Res),
	    [eval_then(Then, Res, 1, M)|eval_rules(T, M)]
    end;
eval_rules([{Weight, {Op, Conds}, Then}|T], M) ->
    case eval_if(Conds, Op, M, []) of
	0 ->
	    eval_rules(T, M);
	Res ->
	    [eval_then(Then, Res, Weight, M)|eval_rules(T, M)]
    end;
eval_rules([], _) ->
    [].

eval_if([{Variable, Value, TermName}|T], Op, M, []) ->
    X = membership(Value, M:Variable(TermName)),
    ?rpt({Variable, Value, TermName}, X),
    eval_if(T, Op, M, X);
eval_if([{Variable, Value, TermName}|T], Op, M, Acc) ->
    X = membership(Value, M:Variable(TermName)),
    ?rpt({Variable, Value, TermName}, X),
    eval_if(T, Op, M, eval_op(Op, X, Acc));
eval_if([], _, _, Acc) ->
    Acc.

eval_then({Variable, TermName}, Degree, Weight, M) ->
    {M:Variable(TermName), Degree, Weight}.



defuzzify([{MBF, Degree, Weight}|T]) when MBF#mbf.defuz_method == 'COM' ->
    {X, Y} = lists:foldl(
	       fun({M, D, W}, {Xc, Yc}) ->
		       {(W * D * M#mbf.point2) + Xc,
			W + Yc}
	       end, {0, 0}, [{MBF, Degree, Weight}|T]),
    (X / Y);
defuzzify([{MBF, Degree, Weight}|T]) when MBF#mbf.defuz_method == 'MOM' ->
    {N, V, _} = lists:foldl(
		  fun({M, D, W}, {Nc, Vc, Xc}) ->
			  case D * W of
			      X when X > Xc ->
				  {M#mbf.name, M#mbf.point2, X};
			      _ ->
				  {Nc, Vc, Xc}
			  end
		  end, {0, 0, 0}, [{MBF, Degree, Weight}|T]),
    {N, V};
defuzzify([]) ->
    [].


membership(Input, #mbf{point1 = nil, point2 = P2}) when Input =< P2 ->
    1;
membership(Input, #mbf{point1 = P1}) when Input =< P1 ->
    _Area1 = 0;
membership(Input, #mbf{point2 = P2, slope2 = S2}) when Input > P2 ->
    if S2 == vertical ->
	    0;
       true ->
	    _Area3 = max(0, (1 - ((P2 - Input) * S2)))
    end;
membership(Input, #mbf{point1 = P1, slope1 = S1}) ->
    if S1 == vertical ->
	    1;
       true ->
	    _Area2 = min(1, (Input - P1) * S1)
    end.

eval_op('AND', A, B) -> min(A, B);
eval_op('OR',  A, B) -> max(A, B);
eval_op('NOT', A, B) -> B - A.

read(Name) ->
    case ets:lookup(fuz, Name) of
	[] ->
	    exit({badarg, Name});
	[Value] ->
	    Value
    end.

write(MBF) when is_record(MBF, mbf) ->
    ets:insert(fuz, MBF).


slope(P, P) ->
    vertical;
slope(P1, P2) ->
    1 /(P1 - P2).
