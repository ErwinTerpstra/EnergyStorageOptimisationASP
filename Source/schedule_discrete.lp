% Parameters
#const hours = 24.                  % Number of hours in the schedule, should match the numer of facts for price, consumption, etc
#const battery_capacity = 100.      % Default capacity set to 100 to express SoC in percentages
#const max_charge_rate = 30.        % Maximum charge rate as percentage of max soc
#const max_discharge_rate = 30.     % Maximum discharge rate as percentage of max soc
#const charge_efficiency = 80.      % Efficiency of charging the battery from the grid (percentage)
#const discharge_efficiency = 80.   % Efficiency of converting battery charge to grid current (percentage)

#const max_charge_increase = max_charge_rate * 100 / charge_efficiency.
#const max_charge_decrease = max_discharge_rate * discharge_efficiency / 100.

#const initial_soc = 0.

% 
% Expected input:
% price(H, P): Energy price in the given hour. H is the hour and P is the price. One fact per hour
% production(H, P): PV production in the given hour. H is the hour and P is the production. One fact per hour
% consumption(H, C): Site power consumption in the given hour. H is the hour and C is the consumption. One fact per hour
%
% Expected parameters:
% 'hours': Number of hours in the schedule. Should match the number of facts defined for price/2, production/2 and consumption/2
%

% All hours in the schedule
hour(1..hours).

% Supported commands
command(charge; discharge; idle).

%
% SCHEDULING
%

% Choose one command for each hour
1 { schedule(H, C) : command(C) } 1 :- hour(H).

%
% STATE-OF-CHARGE PROPAGATION
%

% soc(Hour, Value): State-of-charge at the *end* of the hour

% Initial SoC
soc(0, initial_soc).

% Charge: soc(H) = min(soc(H-1) + max_charge_rate, battery_capacity)
soc(H, S) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, charge),
    S = @min(Sp + max_charge_increase, battery_capacity).

% Discharge: soc(H) = max(soc(H-1) - max_discharge_rate, 0)
soc(H, S) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, discharge),
    S = @max(Sp - max_charge_decrease, 0).

% Idle: soc(H) = soc(H-1)
soc(H, Sp) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, idle).

% Closed world assumptions must have values for all hours
:- hour(H), H > 0, not soc(H, _).
:- hour(H), H > 0, not price(H, _).
:- hour(H), H > 0, not production(H, _).
:- hour(H), H > 0, not consumption(H, _).
:- soc(H, V1), soc(H, V2), V1 != V2.
:- soc(H, S), S < 0.
:- soc(H, S), S > battery_capacity.
:- hour(H), not grid_usage(H, _).

% Action Constraints
:- hour(H), soc(H-1, S), S >= battery_capacity, schedule(H, charge).
:- hour(H), soc(H-1, S), S <= 0, schedule(H, discharge).
:- hour(H), soc(H-1, S1), soc(H, S2), schedule(H, charge), S2 - S1 > max_charge_increase.
:- hour(H), soc(H-1, S1), soc(H, S2), schedule(H, discharge), S1 - S2 > max_charge_decrease.


% 
% PROFIT CALCULATION
%

% Helper atom to determine grid usage based on delta soc
grid_usage(H, V) :-
    soc(H, S),
    soc(H-1, Sp),
    S > Sp,
    V = (S - Sp) * 100 / charge_efficiency.

grid_usage(H, V) :-
    soc(H, S),
    soc(H-1, Sp),
    S <= Sp,
    V = (S - Sp) * discharge_efficiency / 100.

% Constraint to grid usage of zero, but command is not idle
% This helps prevent random 'charge' commands when battery is full, or 'discharge' when battery is empty
:- hour(H),
    grid_usage(H, 0),
    not schedule(H, idle).

% Cost per hour: price * (grid_usage + site_consumption - pv_production)
cost(H, V) :-
    price(H, P),
    grid_usage(H, U),
    consumption(H, C),
    production(H, PV),
    V = P * (U + C - PV).

% Minimize total cost
#minimize { V : cost(H, V) }.

% Show schedule and soc for each hour
#show schedule/2.
#show price/2.
#show cost/2.
#show soc/2.
#show grid_usage/2.