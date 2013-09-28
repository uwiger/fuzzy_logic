%%% fuz.hrl


-define(FUZ_HRL,true).
-define(NORMAL, 100).
-define(HALF_NORMAL, 50).

-define(dbg(), ok).
%-define(dbg(), io:format("~p.~n", [{?MODULE, ?LINE}])).

-record(mbf, {name, min = 0, max = ?NORMAL,
	      point1 = 0, slope1 = 0,
	      point2 = 0, slope2 = 0,
	      area = 0,
	      fuz_method = 'CMBF',   % currently ignored
	      defuz_method = 'COM'}). % Supported: 'MOM' and 'COM'

-record(shape, {point1, slope1, point2, slope2, area}).
-record(method, {fuz_method = 'CMBF', defuz_method = 'COM'}).

%% Defuzzyfication:
%% 'MOM' - Mean of Maximum. This is used to calculate the most
%%         probable linguistic value (and a typical numeric value).
%%         This is useful when calculating state.
%%         The value chosen is the one with the highest comination
%%         of (degree of truth) and weight.
%%
%% 'COM' - Center of Maximum. This is used to calculate the best
%%         compromise. It returns a weighted value which is a
%%         compromise of those rules which were at all true.
