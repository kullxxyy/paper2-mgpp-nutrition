*===============================================================================
* PAPER 2 — ALTERNATIVE GROUPS AND EXPLORATORY SPECIFICATIONS
* File: analyses/07_robustness.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 7A — CONTINUOUS AND ALTERNATIVE BASELINE-CALORIE GROUPS
**# PART 7A — CONTINUOUS AND ALTERNATIVE BASELINE-CALORIE GROUPS
*===============================================================================

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
reghdfe lnHHINC_real did##c.pre_kcal_std1 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_01_`y'_`g'.ster", replace
lincom 1.did + 1.did#c.pre_kcal_std1

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
foreach g in low_q4 low_q5 low_q6 low_q10 {
    di "========== `g' =========="
    reghdfe lnHHINC_real did##i.`g' `RD1', absorb(hhid wave) cluster(COMMID)
    estimates save "$P2_MODELS/07_robustness_model_02_`y'_`g'.ster", replace
    lincom 1.did + 1.did#1.`g'
}
 
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"

reghdfe lnHHINC_real did##ib3.group3 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_03_`y'_`g'.ster", replace

* total effect for bottom
lincom 1.did + 1.did#1.group3

* total effect for midlow
lincom 1.did + 1.did#2.group3

* difference between bottom and midlow
lincom 1.did#1.group3 - 1.did#2.group3

*===============================================================================
* %% PART 7B — MEDIAN BASELINE-CALORIE ROBUSTNESS
**# PART 7B — MEDIAN BASELINE-CALORIE ROBUSTNESS
*===============================================================================

preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowS1  evt_p0##i.lowS1   evt_p2##i.lowS1   evt_p5##i.lowS1   evt_p7##i.lowS1 $P2_ES_MED_EXTRA  ///
        `RD1', absorb(hhid wave) cluster(COMMID)
    estimates save "$P2_MODELS/07_robustness_model_04_`y'_`g'.ster", replace
    
    eststo ES_`y'

    test 1.lowS1#1.evt_m7

}

esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/07_robustness_table_01.rtf", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

* Save this displayed table.
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn using "$P2_TABLES/07_robustness_table_01.csv", replace ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")
restore

local RD1 " c.age##c.age i.job hhsize market trans  n_child elderly_share male_share lnHHINC_real"
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_05_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1
eststo kcal
reghdfe lnd3carbo  did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_06_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1
eststo carbo
reghdfe lnd3fat    did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_07_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1
eststo fat
reghdfe lnd3protn  did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_08_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_02.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_02.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

*===============================================================================
* %% PART 7C — PRE-POLICY EVENT × LOW CALORIES × LATER FARM ENTRY
**# PART 7C — PRE-POLICY EVENT × LOW CALORIES × LATER FARM ENTRY
*===============================================================================

* Controls
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"
* Outcomes
local outcomes lnd3kcal lnd3carbo lnd3fat lnd3protn

* Run DDD regressions
eststo clear
foreach y of local outcomes {

    reghdfe `y' ///
    evt_m7##i.lowS1##i.ever_farmer ///
        `RD1', ///
        absorb(IDind wave) cluster(COMMID)
    estimates save "$P2_MODELS/07_robustness_model_09_`y'_`g'.ster", replace

    eststo `y'
}

* Export table
esttab lnd3kcal lnd3carbo lnd3fat lnd3protn, ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    addnotes("Exploratory: evt_m7 × lowS1 × later farmer entry" ///
             "Individual and wave fixed effects" ///
             "t statistics in parentheses")

* Save this displayed table.
esttab lnd3kcal lnd3carbo lnd3fat lnd3protn using "$P2_TABLES/07_robustness_table_03.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    addnotes("Exploratory: evt_m7 × lowS1 × later farmer entry" ///
             "Individual and wave fixed effects" ///
             "t statistics in parentheses")

* Save this displayed table.
esttab lnd3kcal lnd3carbo lnd3fat lnd3protn using "$P2_TABLES/07_robustness_table_03.csv", replace ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    addnotes("Exploratory: evt_m7 × lowS1 × later farmer entry" ///
             "Individual and wave fixed effects" ///
             "t statistics in parentheses")

*===============================================================================
* %% PART 7D — RURAL HETEROGENEITY AMONG NEVER-ENTERING HOUSEHOLDS
**# PART 7D — RURAL HETEROGENEITY AMONG NEVER-ENTERING HOUSEHOLDS
*===============================================================================

gen rural=t2-1
preserve
keep if ever_farmer==0
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_10_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.rural
eststo kcal
reghdfe lnd3carbo  did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_11_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.rural
eststo carbo
reghdfe lnd3fat    did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_12_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.rural
eststo fat
reghdfe lnd3protn  did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_13_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.rural
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_04.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_04.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
restore

*===============================================================================
* %% PART 7E — CONTEMPORANEOUS INCOME AND CALORIE GROUPS
**# PART 7E — CONTEMPORANEOUS INCOME AND CALORIE GROUPS
*===============================================================================

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_14_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_income
eststo kcal
reghdfe lnd3carbo  did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_15_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_income
eststo carbo
reghdfe lnd3fat    did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_16_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_income
eststo fat
reghdfe lnd3protn  did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_17_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_income
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_05.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_05.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share "

eststo clear

foreach y in lnd3kcal lnd3carbo lnd3fat lnd3protn {

    reghdfe `y' did##i.q_income `RD1', absorb(IDind wave) cluster(COMMID)
    estimates save "$P2_MODELS/07_robustness_model_18_`y'_`g'.ster", replace

    quietly lincom 1.did
    estadd scalar DID_Q1 = r(estimate)

    quietly lincom 1.did + 1.did#2.q_income
    estadd scalar DID_Q2 = r(estimate)

    quietly lincom 1.did + 1.did#3.q_income
    estadd scalar DID_Q3 = r(estimate)

    quietly lincom 1.did + 1.did#4.q_income
    estadd scalar DID_Q4 = r(estimate)

    * store with nice names
    if "`y'"=="lnd3kcal"   eststo kcal
    if "`y'"=="lnd3carbo"  eststo carbo
    if "`y'"=="lnd3fat"    eststo fat
    if "`y'"=="lnd3protn"  eststo protn
}

esttab kcal carbo fat protn, ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    stats(DID_Q1 DID_Q2 DID_Q3 DID_Q4, ///
          labels("DID effect: Q1 (lowest)" "DID effect: Q2" "DID effect: Q3" "DID effect: Q4 (highest)") ///
          fmt(%9.3f %9.3f %9.3f %9.3f)) ///
    addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_06.rtf", replace ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    stats(DID_Q1 DID_Q2 DID_Q3 DID_Q4, ///
          labels("DID effect: Q1 (lowest)" "DID effect: Q2" "DID effect: Q3" "DID effect: Q4 (highest)") ///
          fmt(%9.3f %9.3f %9.3f %9.3f)) ///
    addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_06.csv", replace ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    stats(DID_Q1 DID_Q2 DID_Q3 DID_Q4, ///
          labels("DID effect: Q1 (lowest)" "DID effect: Q2" "DID effect: Q3" "DID effect: Q4 (highest)") ///
          fmt(%9.3f %9.3f %9.3f %9.3f)) ///
    addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_19_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo kcal
reghdfe lnd3carbo  did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_20_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo carbo
reghdfe lnd3fat    did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_21_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo fat
reghdfe lnd3protn  did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_22_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_07.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_07.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

local RD1 " c.age##c.age i.job hhsize market trans c.lnHHINC_real n_child elderly_share male_share  "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_23_`y'_`g'.ster", replace
eststo kcal
reghdfe lnd3carbo  did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_24_`y'_`g'.ster", replace
eststo carbo
reghdfe lnd3fat    did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_25_`y'_`g'.ster", replace
eststo fat
reghdfe lnd3protn  did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/07_robustness_model_26_`y'_`g'.ster", replace
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_08.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab kcal carbo fat protn using "$P2_TABLES/07_robustness_table_08.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Contemporaneous groups and never-entry restrictions are exploratory; they use potentially policy-affected variables.
