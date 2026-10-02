*===============================================================================
* PAPER 2 — BASELINE-INCOME HETEROGENEITY AND DDD
* File: analyses/04_income_ddd.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 4 — INCOME HETEROGENEITY AND CALORIES × INCOME DDD
**# PART 4 — INCOME HETEROGENEITY AND CALORIES × INCOME DDD
*===============================================================================

preserve
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/04_income_ddd_model_01_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowINC_q25
eststo kcal
reghdfe lnd3carbo  did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/04_income_ddd_model_02_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowINC_q25
eststo carbo
reghdfe lnd3fat    did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/04_income_ddd_model_03_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowINC_q25
eststo fat
reghdfe lnd3protn  did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/04_income_ddd_model_04_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowINC_q25
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/04_income_ddd_table_01.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/04_income_ddd_table_01.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
restore 

preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowINC_q25  evt_p0##i.lowINC_q25   evt_p2##i.lowINC_q25   evt_p5##i.lowINC_q25   evt_p7##i.lowINC_q25 $P2_ES_INC_EXTRA  ///
        `RD1', absorb(hhid wave) cluster(COMMID)
    estimates save "$P2_MODELS/04_income_ddd_model_05_`y'_`g'.ster", replace
    
    eststo ES_`y'

    test 1.lowINC_q25#1.evt_m7

}
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/04_income_ddd_table_02.rtf", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/04_income_ddd_table_02.csv", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")
restore

****************************************************
******DDD anaylsis *********************************
****************************************************
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"

eststo clear
foreach y in lnd3kcal lnd3carbo lnd3fat lnd3protn {

    reghdfe `y' ///
        did##i.lowS1_q25##i.lowINC_q25 ///
        `RD1', ///
        absorb(IDind wave) cluster(COMMID)
    estimates save "$P2_MODELS/04_income_ddd_model_06_`y'_`g'.ster", replace

    eststo `y'
    lincom 1.did
    lincom 1.did + 1.did#1.lowS1_q25
    lincom 1.did + 1.did#1.lowINC_q25
    lincom 1.did + 1.did#1.lowS1_q25 + 1.did#1.lowINC_q25 + 1.did#1.lowS1_q25#1.lowINC_q25

}

preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowS1_q25##i.lowINC_q25  evt_p0##i.lowS1_q25##i.lowINC_q25   evt_p2##i.lowS1_q25##i.lowINC_q25 evt_p5##i.lowS1_q25##i.lowINC_q25   evt_p7##i.lowS1_q25##i.lowINC_q25 $P2_ES_DDD_EXTRA  ///
        `RD1', absorb(hhid wave) cluster(COMMID)
    estimates save "$P2_MODELS/04_income_ddd_model_07_`y'_`g'.ster", replace
    
    eststo ES_`y'
    test 1.evt_m7#1.lowS1_q25#1.lowINC_q25

}
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/04_income_ddd_table_03.rtf", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/04_income_ddd_table_03.csv", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

restore
