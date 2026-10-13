$title Minimal single-node capacity expansion: one thermal plant, one solar plant, one battery

$onText
Chooses the battery power (MW) and energy (MWh) capacity that minimise
total annual system cost for a single representative day (24 hours),
scaled up to a year. Thermal and solar capacity are fixed (already built).
$offText

* ---------------------------------------------------------------
* 1. Sets
* ---------------------------------------------------------------
Set t "hours of the representative day" / t1*t24 /;

* ---------------------------------------------------------------
* 2. Scalar parameters (all numbers are placeholders: change them)
* ---------------------------------------------------------------
Scalars
    days        "days represented by the model day"          / 365    /
    thermal_cap "installed thermal capacity (MW)"            / 850    /
    solar_cap   "installed solar capacity (MW)"              / 800    /
    c_thermal   "thermal marginal cost (EUR per MWh)"        / 120    /
    voll        "cost of unserved energy (EUR per MWh)"      / 3000   /
    eta_c       "battery charging efficiency"                / 0.92   /
    eta_d       "battery discharging efficiency"             / 0.92   /
    capex_P     "battery power capex (EUR per MW)"           / 100000 /
    capex_E     "battery energy capex (EUR per MWh)"         / 200000 /
    r           "discount rate"                              / 0.07   /
    life        "battery lifetime (years)"                   / 15     /
    crf         "capital recovery factor";

* Converts upfront capex into an equal annual payment
crf = r / (1 - (1 + r)**(-life));

* ---------------------------------------------------------------
* 3. Time-series data (synthetic: replace with real data later)
* ---------------------------------------------------------------
Parameters
    demand(t)   "demand (MW)"
    solar_cf(t) "solar capacity factor (0 to 1)";

* Base load plus a morning bump and an evening peak
demand(t) = 550 + 250*exp(-sqr(ord(t)-19)/8) + 100*exp(-sqr(ord(t)-8)/6);

* Solar: bell-shaped between hour 6 and hour 18, zero at night
solar_cf(t)$(ord(t) > 6 and ord(t) < 18) = sin(pi*(ord(t)-6)/12);

* ---------------------------------------------------------------
* 4. Variables
* ---------------------------------------------------------------
Positive Variables
    p_thermal(t) "thermal output (MW)"
    p_solar(t)   "solar output used (MW)"
    charge(t)    "battery charging power (MW)"
    discharge(t) "battery discharging power (MW)"
    soc(t)       "battery state of charge (MWh)"
    unserved(t)  "unserved energy (MW)"
    P_bat        "battery power capacity built (MW)"
    E_bat        "battery energy capacity built (MWh)";

Variable
    total_cost   "total annual system cost";

* ---------------------------------------------------------------
* 5. Equations
* ---------------------------------------------------------------
Equations
    obj          "objective: total annual cost"
    balance(t)   "supply equals demand in every hour"
    thermal_lim(t)
    solar_lim(t)
    soc_dyn(t)   "battery energy balance"
    soc_lim(t)
    charge_lim(t)
    discharge_lim(t);

obj ..
    total_cost =e= days * sum(t, c_thermal*p_thermal(t) + voll*unserved(t))
                 + crf * (capex_P*P_bat + capex_E*E_bat);

* Charging counts as extra demand; discharging counts as supply
balance(t) ..
    p_thermal(t) + p_solar(t) + discharge(t) + unserved(t)
        =e= demand(t) + charge(t);

thermal_lim(t) ..   p_thermal(t) =l= thermal_cap;

* Using less than the available solar means curtailment
solar_lim(t) ..     p_solar(t) =l= solar_cf(t)*solar_cap;

* t--1 is the circular lag: hour 1 follows hour 24,
* so the battery ends the day with the charge it started with
soc_dyn(t) ..
    soc(t) =e= soc(t--1) + eta_c*charge(t) - discharge(t)/eta_d;

soc_lim(t) ..       soc(t)       =l= E_bat;
charge_lim(t) ..    charge(t)    =l= P_bat;
discharge_lim(t) .. discharge(t) =l= P_bat;

* ---------------------------------------------------------------
* 6. Solve
* ---------------------------------------------------------------
Model grid / all /;
solve grid using lp minimizing total_cost;

* ---------------------------------------------------------------
* 7. Results
* ---------------------------------------------------------------
Parameter
    price(t)     "implied electricity price (EUR per MWh)"
    report(t,*)  "hourly dispatch (MW)";

* The dual of the balance constraint is the marginal cost of one more MWh
* in that hour. The objective is scaled by 'days', so divide it back out.
price(t) = balance.m(t) / days;

report(t,'demand')    = demand(t);
report(t,'thermal')   = p_thermal.l(t);
report(t,'solar')     = p_solar.l(t);
report(t,'curtailed') = solar_cf(t)*solar_cap - p_solar.l(t);
report(t,'charge')    = charge.l(t);
report(t,'discharge') = discharge.l(t);
report(t,'soc_MWh')   = soc.l(t);
report(t,'price')     = price(t);

display P_bat.l, E_bat.l, total_cost.l, report;
