% Parameters
#const hours = 24.
#const battery_capacity = 100.
#const max_charge_rate = 30.
#const max_discharge_rate = 30.
#const charge_efficiency = 80.
#const discharge_efficiency = 80.
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

% Possible SoC values. The domain is much bigger than what is valid for the battery, but we need to cover some range
% of values to be able to perform arithmetic on them and afterwards clamp to valid values
soc_val(-(battery_capacity*10)..(battery_capacity*10)).

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

% Util to clamp soc between 0 and battery_capacity
soc_clamp(I, I) :- soc_val(I), I >= 0, I <= battery_capacity.
soc_clamp(I, battery_capacity) :- soc_val(I), I > battery_capacity.
soc_clamp(I, 0) :- soc_val(I), I < 0.

% soc(Hour, Value): State-of-charge at the *end* of the hour

% initial SoC
soc(0, initial_soc).

% Charge: soc(H) = min(soc(H-1) + max_charge_rate, battery_capacity)
soc(H, S) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, charge),
    soc_clamp(Sp + max_charge_increase, S).

% Discharge: soc(H) = max(soc(H-1) - max_discharge_rate, 0)
soc(H, S) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, discharge),
    soc_clamp(Sp - max_charge_decrease, S).

% Idle: soc(H) = soc(H-1)
soc(H, Sp) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    schedule(H, idle).

% Constraint: a valid soc value for each hour
:- hour(H), H > 0, not soc(H, _).

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