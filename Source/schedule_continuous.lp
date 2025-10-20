% ---------- parameters (override with -c if desired) ----------
#const hours = 8.
#const cap = 10.
#const maxrate = 3.
#const initial = 0.

hour(1..hours).
val(0..maxrate).
sval(0..cap).

price(1, 10).  price(2, 12).  price(3, 9).  price(4, 8).
price(5, 7).   price(6, 11).  price(7, 20). price(8, 18).
% ... up to price(24, ...)


% ---------- input: price(H,Price). (user supplies these facts) ----------
% Example: price(1,10). price(2,12). ... for H = 1..hours

% ---------- choose an amount to charge and an amount to discharge each hour ----------
1 { charge(H,V) : val(V) } 1 :- hour(H).
1 { discharge(H,V) : val(V) } 1 :- hour(H).

% cannot both charge and discharge > 0 in the same hour
:- charge(H,C), discharge(H,D), C > 0, D > 0.

% ---------- state-of-charge propagation ----------
% initial SoC
soc(0, initial).

% deterministic SoC evolution: soc(H) = soc(H-1) + charge - discharge
soc(H, S) :-
    hour(H), H > 0,
    soc(H-1, Sp),
    charge(H, C), discharge(H, D),
    S = Sp + C - D,
    S >= 0, S <= cap.

% require a valid soc value for each hour
:- hour(H), H > 0, not soc(H, _).

% ---------- profit (net contribution) ----------
% net per hour V = price(H) * (discharge_amount - charge_amount)
net(H, V) :-
    price(H, P),
    charge(H, C), discharge(H, D),
    V = P * (D - C).

% maximize total profit (sum of per-hour nets)
#maximize { V : net(H, V) }.

% ---------- convenient output atoms ----------
action(H, charge, C)     :- charge(H, C), C > 0.
action(H, discharge, D)  :- discharge(H, D), D > 0.
action(H, none, 0)       :- charge(H, 0), discharge(H, 0).

% show actions and soc after each hour
#show action/3.
#show soc/2.
