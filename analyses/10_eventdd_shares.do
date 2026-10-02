*===============================================================================
* PAPER 2 — OPTIONAL EVENTDD SHARE GRAPHS
* File: analyses/10_eventdd_shares.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 10 — ORIGINAL EVENTDD SHARE GRAPHS (ENABLE IN CONFIG)
**# PART 10 — ORIGINAL EVENTDD SHARE GRAPHS (ENABLE IN CONFIG)
*===============================================================================

preserve
gen imple_year=.
replace imple_year=2004 if t1==43
gen timeToTreat = wave-imple_year

local add = 18   // number of event-time values (-7 to 10) = 10 - (-7) + 1 = 18
insobs `add'

local k = _N - `add' + 1   // starting observation for new rows

forvalues x = -7/10{
    replace timeToTreat = `x' in `k'
    local ++k
}
    local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share   lnHHINC_real"
eventdd  sC_imp  `RD1' ,hdfe absorb(i.hhid i.wave ) cluster(COMMID) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Nutrient share / quality index") xlabel(-7(1)10)) 
graph export "$P2_FIGURES/eventdd_sC_imp.png", replace width(2000)
 estat leads  
eventdd  sF_imp  `RD1' ,hdfe absorb(i.hhid i.wave ) cluster(COMMID) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Nutrient share / quality index") xlabel(-7(1)10)) 
graph export "$P2_FIGURES/eventdd_sF_imp.png", replace width(2000)
 estat leads  
eventdd  sP_imp  `RD1' ,hdfe absorb(i.hhid i.wave ) cluster(COMMID) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Protein energy share") xlabel(-7(1)10)) 
graph export "$P2_FIGURES/eventdd_sP_imp.png", replace width(2000)
 estat leads  
eventdd  Q2  `RD1' ,hdfe absorb(i.hhid i.wave ) cluster(COMMID) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Nutrient share / quality index") xlabel(-7(1)10)) 
graph export "$P2_FIGURES/eventdd_Q2.png", replace width(2000)
 estat leads 
restore
