*===============================================================================
* PAPER 2 — INCOME, WAGE AND AGRICULTURAL CHANNELS
* File: analyses/06_channels.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 6A — INCOME AND WAGES
**# PART 6A — INCOME AND WAGES
*===============================================================================

local RD1 "  i.job  hhsize market trans   n_child elderly_share male_share  "
reghdfe lnHHINC_real   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_01_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe lnHHINC_real ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_02_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

* monthly_wage is prepared in prep/01_data_prep.do.

local RD1 " i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe monthly_wage   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_03_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe monthly_wage ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_04_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

****nutrition share

*===============================================================================
* %% PART 6B — SELF-CONSUMPTION, EXPENSE AND OCCUPATIONS
**# PART 6B — SELF-CONSUMPTION, EXPENSE AND OCCUPATIONS
*===============================================================================

local RD1 "  hhsize market trans   n_child elderly_share male_share "
reghdfe ln_farmconsume did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_05_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job   hhsize market trans   n_child elderly_share male_share  "
reghdfe farmconsume   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_06_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job   hhsize market trans   n_child elderly_share male_share  "
reghdfe lnhhexpense_real   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_07_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

reghdfe lnhhexpense_real ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_08_`y'_`g'.ster", replace
test 1.lowS1_q25#1.evt_m7

// tab agri_part
// gen agri_part = hhexpense > 0 if !missing(hhexpense)
// local RD1 "  hhsize market trans   n_child elderly_share male_share "
// reghdfe agri_part did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
// lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe indbus   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_09_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age i.job  hhsize market trans   n_child elderly_share male_share  "
reghdfe farmer_ind   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_10_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25
sum farmer_ind

sum monthly_wage indwage farmer_ind indbus
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe monthly_wage   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_11_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe farmer_ind   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_12_`y'_`g'.ster", replace
lincom 1.did + 1.did#1.lowS1_q25

*===============================================================================
* %% PART 6C — AGRICULTURAL ENTRY EXPLORATION
**# PART 6C — AGRICULTURAL ENTRY EXPLORATION
*===============================================================================

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 did `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_13_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_14_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 evt_m7##i.lowS1_q25 evt_p0##i.lowS1_q25 evt_p2##i.lowS1_q25 evt_p5##i.lowS1_q25 evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_15_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal did##i.ever_farmer `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_16_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer $P2_ES_ENTRY_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_17_`y'_`g'.ster", replace

preserve 
keep if lowS1_q25==1
local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal did##i.ever_farmer `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_18_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer $P2_ES_ENTRY_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_19_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3carbo did##i.ever_farmer `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_20_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3carbo evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer $P2_ES_ENTRY_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_21_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3fat did##i.ever_farmer `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_22_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3fat evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer $P2_ES_ENTRY_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_23_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3protn did##i.ever_farmer `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_24_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3protn evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer $P2_ES_ENTRY_EXTRA `RD1', ///
    absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_25_`y'_`g'.ster", replace

restore

*===============================================================================
* %% PART 6D — HOUSEHOLD FARMER STATUS
**# PART 6D — HOUSEHOLD FARMER STATUS
*===============================================================================

replace farmer_hh_wave = 0 if missing(farmer_hh_wave)
tab farmer_hh_wave

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe farmer_hh_wave did `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_26_`y'_`g'.ster", replace

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe farmer_hh_wave did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_27_`y'_`g'.ster", replace
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.lowS1_q25

preserve
local outcomes farmer_hh_wave
local RD1 " c.age##c.age hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe `y' ///
        evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25 $P2_ES_KCAL_EXTRA  ///
        `RD1', absorb(hhid wave) cluster(COMMID)
    estimates save "$P2_MODELS/06_channels_model_28_`y'_`g'.ster", replace
    
    eststo ES_`y'

    test 1.lowS1_q25#1.evt_m7

}
restore

*===============================================================================
* %% PART 6E — POST-POLICY ENTRY DIAGNOSTICS
**# PART 6E — POST-POLICY ENTRY DIAGNOSTICS
*===============================================================================

bys hhid: egen post_enter = max(producer_l1*(wave>=2004))   // choose post window
bys hhid: egen treated_hh = max(treated)
tab post_enter treated_hh, row
local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share "
reg post_enter treated_hh `RD1', vce(cluster COMMID)
estimates save "$P2_MODELS/06_channels_model_29_`y'_`g'.ster", replace

local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share "
reghdfe producer_l1 did `RD1', absorb(hhid wave) cluster(COMMID)
estimates save "$P2_MODELS/06_channels_model_30_`y'_`g'.ster", replace

* ever_farmer and post_enter use post-policy behavior. These exploratory models
* should not be interpreted as causal baseline-subgroup comparisons.
