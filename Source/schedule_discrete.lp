% ------------------------------------------------------------
% Parameters/input
%
% Expected input:
% price(H, P): Energy price in the given hour. H is the hour and P is the price. One fact per hour
% production(H, P): PV production in the given hour. H is the hour and P is the production. One fact per hour
% consumption(H, C): Site power consumption in the given hour. H is the hour and C is the consumption. One fact per hour
%
% Expected parameters:
% 'hours': Number of hours in the schedule. Should match the number of facts defined for price/2, production/2 and consumption/2
% 'inital_soc': State-of-charge at start of the schedule (default 0)
% ------------------------------------------------------------

% Parameters
#const hours = 24.                  % Number of hours in the schedule, should match the numer of facts for price, consumption, etc
#const battery_capacity = 100.      % Default capacity set to 100 to express SoC in percentages
#const max_charge_rate = 30.        % Maximum inverter charge rate as percentage of max soc
#const max_discharge_rate = 30.     % Maximum inverter discharge rate as percentage of max soc
#const charge_efficiency = 80.      % Efficiency of charging the battery from the grid (percentage)
#const discharge_efficiency = 80.   % Efficiency of converting battery charge to grid current (percentage)
#const charge_rate_epsilon = 1.     % Safe margin above/below max charge rate which we allow to prevent rounding error

#const initial_soc = 0.

% Deived helpers to determine the maximum charge increase/decrease per slot
#const max_charge_increase = max_charge_rate * charge_efficiency / 100.
#const max_charge_decrease = max_discharge_rate * 100 / discharge_efficiency.

% ------------------------------------------------------------
% Statics:
% hour: Atoms which identify an hour in the schedule
% command: Atoms which identifies a command the scheduler has taken for a specific schedule slot
%
%------------------------------------------------------------

% All hours in the schedule. Similar to 'steps/1'
hour(1..hours).

% Domain range for 'energy' values. These are Wh values, but are represented
% in percentages of the total battery capacity to limit the domain size
energy(-1000..1000).

% Domain range for 'price' values. These are in tenths of cents.
price(-100000..100000).

% Supported commands
command(charge; discharge; idle).

% ------------------------------------------------------------
% Initial state (time 0)
% ------------------------------------------------------------

% Initial SoC
holds(soc(initial_soc), 0).

% ------------------------------------------------------------
% Fluents:
% soc/1: State-of-charge at the *end* of the hour
% inverter_power/1: The amount of grid usage (derived)
% cost/1: The monetary cost of grid usage (derived)
%
% ------------------------------------------------------------
fluent(defined, soc(V)) :- energy(V).
fluent(defined, inverter_power(V)) :- energy(V).
fluent(defined, cost(V)) :- price(V).

% State-of-charge deterministic propagation

% Charge: soc(H) = min(soc(H-1) + max_charge_rate, battery_capacity)
holds(soc(S), H) :-
    hour(H), H > 0,
    holds(soc(Sp), H-1),
    occurs(schedule(charge), H),
    S = @min(Sp + max_charge_increase, battery_capacity).

% Discharge: soc(H) = max(soc(H-1) - max_discharge_rate, 0)
holds(soc(S), H):-
    hour(H), H > 0,
    holds(soc(Sp), H-1),
    occurs(schedule(discharge), H),
    S = @max(Sp - max_charge_decrease, 0).

% Idle: soc(H) = soc(H-1)
holds(soc(Sp), H) :-
    hour(H), H > 0,
    holds(soc(Sp), H-1),
    occurs(schedule(idle), H).

% Helper atom to determine inverter power based on delta soc
% This helps handling being at max/min soc correctly
holds(inverter_power(V), H) :-
    holds(soc(S), H),
    holds(soc(Sp), H-1),
    S > Sp,
    V = (S - Sp) * 100 / charge_efficiency.

holds(inverter_power(V), H) :-
    holds(soc(S), H),
    holds(soc(Sp), H-1),
    S <= Sp,
    V = (S - Sp) * discharge_efficiency / 100.

% Cost per hour: price * (inverter_power + site_consumption - pv_production)
holds(cost(V), H) :-
    holds(inverter_power(I), H),
    price(H, P),
    consumption(H, C),
    production(H, PV),
    V = P * (I + C - PV).

% General Inertia Axioms
% Disabled, as we don't have any inertial fluents
% holds(F, I+1) :- 
%     fluent(inertial, F),
%     holds (F, I),
%     not -holds(F, I +1) ,
%     I < n.

%  -holds(F, I+1) :- 
%     fluent(inertial, F),
%     -holds(F, I),
%     not holds (F, I+1),
%     I < n.

% ------------------------------------------------------------
% Action Constraints
% ------------------------------------------------------------

% Closed world assumptions: must have values for all hours
:- hour(H), H > 0, not holds(soc(_), H).
:- holds(soc(V1), H), holds(soc(V2), H), V1 != V2.
:- holds(cost(V1), H), holds(cost(V2), H), V1 != V2.
:- holds(soc(S), H), S < 0.
:- holds(soc(S), H), S > battery_capacity.

% Don't charge when battery is full
:- hour(H), holds(soc(S), H), S >= battery_capacity, occurs(schedule(charge), H).

% Don't discharge when battery is empty
:- hour(H), holds(soc(S), H), S <= 0, occurs(schedule(discharge), H).

% Inverter power shouldn't exceed max
% Note that we add some padding here to prevent tripping over rounding errors
:- hour(H), holds(inverter_power(I), H), I > max_charge_rate + charge_rate_epsilon.
:- hour(H), holds(inverter_power(I), H), -I > max_discharge_rate + charge_rate_epsilon.

% Constraint to grid usage of zero, but command is not idle
% This helps prevent random 'charge' commands when battery is full, or 'discharge' when battery is empty
:- hour(H),
    holds(inverter_power(0), H),
    not occurs(schedule(idle), H).

% ------------------------------------------------------------
% Goal definition: select a command for each hour 
% and minimize total cost.
% ------------------------------------------------------------

% Choose one command for each hour
1 { occurs(schedule(C), H) : command(C) } 1 :- hour(H).

% Minimize total cost
#minimize { V : holds(cost(V), H) }.

% ------------------------------------------------------------
% Output: Show results (fluents/actions) and inputs (price, production, consumption) for each hour
% ------------------------------------------------------------
#show price/2.
#show production/2.
#show consumption/2.
#show holds/2.
#show occurs/2. 