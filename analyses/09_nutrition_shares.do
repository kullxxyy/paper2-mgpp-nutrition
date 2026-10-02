*===============================================================================
* PAPER 2 — NUTRIENT SHARES AND NUTRITION QUALITY
* File: analyses/09_nutrition_shares.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 9A — SHARE HETEROGENEITY BY BASELINE CALORIES
**# PART 9A — SHARE HETEROGENEITY BY BASELINE CALORIES
*===============================================================================

local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe carb_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_01_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe carb_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_02_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe fat_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_03_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe fat_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_04_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe protein_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_05_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe protein_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_06_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

*===============================================================================
* %% PART 9B — AVERAGE SHARES AND NUTRITION QUALITY
**# PART 9B — AVERAGE SHARES AND NUTRITION QUALITY
*===============================================================================

local RD1 " c.age##c.age i.job hhsize market trans c.lnHHINC_real  n_child elderly_share male_share  "
eststo clear
reghdfe sC_imp did `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_07_`y'_`g'.ster", replace
eststo sC_imp
reghdfe sF_imp did `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_08_`y'_`g'.ster", replace
eststo sF_imp
reghdfe sP_imp did `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_09_`y'_`g'.ster", replace
eststo sP_imp
reghdfe Q2  did `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_10_`y'_`g'.ster", replace
eststo Q2
esttab sC_imp sF_imp sP_imp  Q2, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab sC_imp sF_imp sP_imp  Q2 using "$P2_TABLES/09_nutrition_shares_table_01.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab sC_imp sF_imp sP_imp  Q2 using "$P2_TABLES/09_nutrition_shares_table_01.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

*===============================================================================
* %% PART 9C — EXTRA CONTEXT SPECIFICATION
**# PART 9C — EXTRA CONTEXT SPECIFICATION
*===============================================================================

* This original extra specification additionally requires index and comm.
capture confirm numeric variable index comm
if !_rc {
local RD1 " c.age##c.age i.job hhsize index comm  c.lnHHINC_real   "
reghdfe sC_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_11_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo sC_imp
reghdfe sF_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_12_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo sF_imp
reghdfe sP_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_13_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo sP_imp
reghdfe Q2    did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
estimates save "$P2_MODELS/09_nutrition_shares_model_14_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.low_kcal
eststo Q2
esttab sC_imp sF_imp sP_imp  Q2, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab sC_imp sF_imp sP_imp  Q2 using "$P2_TABLES/09_nutrition_shares_table_02.rtf", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

* Save this displayed table.
esttab sC_imp sF_imp sP_imp  Q2 using "$P2_TABLES/09_nutrition_shares_table_02.csv", replace star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")

}
else {
    display as text "Skipped extra share-context models: index or comm is absent. Standard share models were run."
}
