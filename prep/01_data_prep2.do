*===============================================================================
* PAPER 2 — SAMPLE, OUTCOMES, AND EVENT VARIABLES
* File: prep/01_data_prep.do
*
* PURPOSE
*   Prepare Paper 2 analysis variables from the ORIGINAL input data.
*
* IMPORTANT
*   1. Run this file through main.do.
*   2. prep/00_checks.do should load and validate the original input data first.
*   3. Do NOT run this file on an already-prepared analysis-ready dataset.
*   4. This file creates sample flags; it does NOT drop non-consumer households.
*
* PURE-CONSUMER STRATEGY
*   The agricultural variables in CHNS are useful for detecting agricultural
*   production, but their zeros are extremely sparse and missing values are
*   common. Therefore, they are treated as POSITIVE EVIDENCE of production,
*   not as a complete producer/non-producer classification system.
*
*   Three nested baseline definitions are created:
*
*   A. consumer_base_occ
*      No observed farmer occupation before the policy.
*
*   B. consumer_base   [MAIN]
*      No observed farmer occupation before the policy
*      AND no observed CORE production evidence before the policy.
*
*      Core evidence:
*        farmsize > 0
*        HHFARM != 0     (negative farm income still implies farm activity)
*        farmconsume > 0
*        farmexp > 0
*
*   C. consumer_base_strict   [ROBUSTNESS]
*      Main definition
*      AND no observed broader agricultural evidence from
*        HHFISH, hhgard, HHLVST.
*
* IMPORTANT INTERPRETATION
*   consumer_base and consumer_base_strict are empirical pure-consumer PROXIES.
*   Missing production-module values are NOT automatically coded as zero.
*   Instead, households are excluded when positive production evidence exists.
*
* TIMING ASSUMPTION
*   The agricultural variables below are treated as lagged measures:
*   survey-wave t values refer to agricultural activity in t-1.
*   This assumption should be checked variable-by-variable against the CHNS
*   questionnaire/codebook.
*===============================================================================


*===============================================================================
* 0. PRE-RUN CHECKS
*===============================================================================

if "$P2_DATA_FILE" == "" {
    display as error ///
        "Paper 2 configuration is not initialized. Run main.do first."
    exit 198
}

capture confirm numeric variable job
if _rc {
    display as error "The active dataset has no numeric job variable."
    display as text ///
        "Run main.do so prep/00_checks.do loads and checks the original data."
    exit 111
}


*===============================================================================
* 1. HARMONIZED COMMUNITY ID FOR CLUSTERING
*===============================================================================

capture drop cluster_commid
gen cluster_commid = COMMID

capture confirm variable commid
if !_rc {
    replace cluster_commid = commid ///
        if missing(cluster_commid) & !missing(commid)
}

label variable cluster_commid "Community ID used for clustering"

quietly count if missing(cluster_commid)
display as text ///
    "Observations with missing cluster_commid: " r(N)


*===============================================================================
* 2. OPTIONAL ORIGINAL EXPENSE DIAGNOSTICS
*===============================================================================

capture confirm numeric variable H4 hhexpense
if !_rc {

    capture drop year_busexp diff have_exp

    gen year_busexp = H4 * 12
    gen diff = hhexpense - year_busexp

    * Keep missing expenditure as missing.
    gen have_exp = (hhexpense > 0) if !missing(hhexpense)

    tab wave

    capture confirm variable t1
    if !_rc {
        bysort t1: summarize hhexpense
    }
}


*===============================================================================
* 3. BASELINE PURE-CONSUMER PROXIES
*===============================================================================

*-------------------------------------------------------------------------------
* 3.1 Policy timing
*-------------------------------------------------------------------------------

* Current-period variables:
* 2004 is treated as the first policy-period wave.
local pre_end_current = 2003

* Lagged agricultural variables:
* under the t-1 interpretation, the 2004 survey may contain 2003 activity.
local pre_end_lagged = 2004


*-------------------------------------------------------------------------------
* 3.2 Farmer occupation: individual -> household-wave -> baseline household
*-------------------------------------------------------------------------------

capture drop farmer_ind farmer_hh_wave base_farmer

* Individual is a farmer when primary occupation == 5.
gen farmer_ind = (job == 5) if !missing(job)

* Household-wave status:
*   1 = at least one observed member is a farmer
*   0 = job information is observed and no observed member is a farmer
*   . = all household members' job information is missing
bysort hhid wave: egen farmer_hh_wave = max(farmer_ind)

* Baseline household farmer status.
bysort hhid: egen base_farmer = ///
    max(cond(wave <= `pre_end_current', farmer_hh_wave, .))

label variable base_farmer ///
    "Baseline farmer occupation status"


*-------------------------------------------------------------------------------
* 3.3 Preserve and clean agricultural variables
*-------------------------------------------------------------------------------

capture drop ///
    farmsize_raw HHFARM_raw farmconsume_raw farmexp_raw ///
    HHFISH_raw hhgard_raw HHLVST_raw

clonevar farmsize_raw    = farmsize
clonevar HHFARM_raw      = HHFARM
clonevar farmconsume_raw = farmconsume
clonevar farmexp_raw     = farmexp
clonevar HHFISH_raw      = HHFISH
clonevar hhgard_raw      = hhgard
clonevar HHLVST_raw      = HHLVST

foreach v in farmsize HHFARM farmconsume farmexp HHFISH hhgard HHLVST {

    capture confirm numeric variable `v'
    if _rc {
        display as error ///
            "Required agricultural variable `v' is missing or non-numeric."
        exit 111
    }

    * Known CHNS special missing values.
    replace `v' = . if inlist(`v', -9, -99, -999, -9999)
}


*-------------------------------------------------------------------------------
* 3.4 Row-level POSITIVE production-evidence indicators
*-------------------------------------------------------------------------------

capture drop ///
    ev_land_l1 ev_farminc_l1 ev_self_l1 ev_farmexp_l1 ///
    ev_fish_l1 ev_garden_l1 ev_livestock_l1

* Core evidence.
gen ev_land_l1 = (farmsize > 0) ///
    if !missing(farmsize)

* IMPORTANT:
* Farm income can be negative because a farming household can make a loss.
* Any nonzero observed HHFARM therefore provides evidence of farm activity.
gen ev_farminc_l1 = (HHFARM != 0) ///
    if !missing(HHFARM)

gen ev_self_l1 = (farmconsume > 0) ///
    if !missing(farmconsume)

gen ev_farmexp_l1 = (farmexp > 0) ///
    if !missing(farmexp)

* Broader agricultural evidence used only for the strict definition.
gen ev_fish_l1 = (HHFISH > 0) ///
    if !missing(HHFISH)

gen ev_garden_l1 = (hhgard > 0) ///
    if !missing(hhgard)

gen ev_livestock_l1 = (HHLVST > 0) ///
    if !missing(HHLVST)


*-------------------------------------------------------------------------------
* 3.5 Aggregate evidence to household-wave level
*-------------------------------------------------------------------------------

capture drop ///
    ev_land_hh ev_farminc_hh ev_self_hh ev_farmexp_hh ///
    ev_fish_hh ev_garden_hh ev_livestock_hh

bysort hhid wave: egen ev_land_hh      = max(ev_land_l1)
bysort hhid wave: egen ev_farminc_hh   = max(ev_farminc_l1)
bysort hhid wave: egen ev_self_hh      = max(ev_self_l1)
bysort hhid wave: egen ev_farmexp_hh   = max(ev_farmexp_l1)

bysort hhid wave: egen ev_fish_hh      = max(ev_fish_l1)
bysort hhid wave: egen ev_garden_hh    = max(ev_garden_l1)
bysort hhid wave: egen ev_livestock_hh = max(ev_livestock_l1)


*-------------------------------------------------------------------------------
* 3.6 Household-wave CORE production evidence
*-------------------------------------------------------------------------------

capture drop core_prod_info_n producer_core_hh_wave

* Number of core indicators observed in this household-wave.
egen core_prod_info_n = rownonmiss( ///
    ev_land_hh ev_farminc_hh ev_self_hh ev_farmexp_hh)

* Evidence status:
*   1 = at least one core source indicates production
*   0 = at least one core source is observed and all observed sources are zero
*   . = all core sources are missing
egen producer_core_hh_wave = rowmax( ///
    ev_land_hh ev_farminc_hh ev_self_hh ev_farmexp_hh)

label variable producer_core_hh_wave ///
    "Core agricultural-production evidence, household-wave"


*-------------------------------------------------------------------------------
* 3.7 Household-wave STRICT/BROAD production evidence
*-------------------------------------------------------------------------------

capture drop strict_prod_info_n producer_strict_hh_wave

egen strict_prod_info_n = rownonmiss( ///
    ev_land_hh ev_farminc_hh ev_self_hh ev_farmexp_hh ///
    ev_fish_hh ev_garden_hh ev_livestock_hh)

egen producer_strict_hh_wave = rowmax( ///
    ev_land_hh ev_farminc_hh ev_self_hh ev_farmexp_hh ///
    ev_fish_hh ev_garden_hh ev_livestock_hh)

label variable producer_strict_hh_wave ///
    "Broad agricultural-production evidence, household-wave"


*-------------------------------------------------------------------------------
* 3.8 Baseline production evidence
*-------------------------------------------------------------------------------

capture drop ///
    base_producer base_producer_core base_producer_strict

bysort hhid: egen base_producer_core = ///
    max(cond(wave <= `pre_end_lagged', producer_core_hh_wave, .))

bysort hhid: egen base_producer_strict = ///
    max(cond(wave <= `pre_end_lagged', producer_strict_hh_wave, .))

* Backward-compatible alias used by older analysis files.
gen base_producer = base_producer_core

label variable base_producer_core ///
    "Baseline core production evidence"
label variable base_producer_strict ///
    "Baseline broad production evidence"
label variable base_producer ///
    "Baseline core production evidence (legacy alias)"


*-------------------------------------------------------------------------------
* 3.9 Baseline consumer definitions
*-------------------------------------------------------------------------------

capture drop ///
    consumer_base_occ consumer_base consumer_base_strict

* A. Occupation-only benchmark.
gen consumer_base_occ = .

replace consumer_base_occ = 1 ///
    if base_farmer == 0

replace consumer_base_occ = 0 ///
    if base_farmer == 1

label define cons_occ ///
    0 "Baseline farmer household" ///
    1 "Baseline non-farmer household", replace

label values consumer_base_occ cons_occ


* B. MAIN pure-consumer proxy.
*
* A household is included when:
*   - baseline occupation data identify it as non-farmer, AND
*   - there is NO POSITIVE core production evidence.
*
* Note:
*   base_producer_core == . does NOT automatically mean "non-producer."
*   It means no usable core production-module evidence.
*   The household is retained because occupation data identify it as non-farmer,
*   while any positive production evidence overrides that classification.
gen consumer_base = .

replace consumer_base = 1 ///
    if base_farmer == 0 ///
    & (base_producer_core == 0 | missing(base_producer_core))

replace consumer_base = 0 ///
    if base_farmer == 1 | base_producer_core == 1

label define cons_main ///
    0 "Not baseline pure-consumer proxy" ///
    1 "Baseline pure-consumer proxy: main/core", replace

label values consumer_base cons_main


* C. STRICT robustness definition.
*
* Same occupation requirement as the main definition, but any positive
* evidence from fishery, gardening, or livestock also excludes the household.
gen consumer_base_strict = .

replace consumer_base_strict = 1 ///
    if base_farmer == 0 ///
    & (base_producer_strict == 0 | missing(base_producer_strict))

replace consumer_base_strict = 0 ///
    if base_farmer == 1 | base_producer_strict == 1

label define cons_strict ///
    0 "Not baseline pure-consumer proxy" ///
    1 "Baseline pure-consumer proxy: strict/broad", replace

label values consumer_base_strict cons_strict

* Logical check:
* every strict pure-consumer household must also satisfy the main definition.
assert consumer_base == 1 if consumer_base_strict == 1


*-------------------------------------------------------------------------------
* 3.10 Household-level diagnostics
*-------------------------------------------------------------------------------

capture drop tag_hh tag_hhw

egen tag_hh  = tag(hhid)
egen tag_hhw = tag(hhid wave)

display as text "------------------------------------------------------------"
display as text "BASELINE SAMPLE DIAGNOSTICS"
display as text "------------------------------------------------------------"

tab base_farmer if tag_hh, missing
tab base_producer_core if tag_hh, missing
tab base_producer_strict if tag_hh, missing

tab base_farmer base_producer_core if tag_hh, missing

tab consumer_base_occ if tag_hh, missing
tab consumer_base if tag_hh, missing
tab consumer_base_strict if tag_hh, missing

quietly count if tag_hh & consumer_base_occ == 1
display as text ///
    "Occupation-only non-farmer households = " r(N)

quietly count if tag_hh & consumer_base == 1
display as text ///
    "Main pure-consumer proxy households = " r(N)

quietly count if tag_hh & consumer_base_strict == 1
display as text ///
    "Strict pure-consumer proxy households = " r(N)

* Treated/control composition of the main sample.
tab treated if tag_hh & consumer_base == 1, missing

* Observation counts.
quietly count if consumer_base == 1
display as text ///
    "Main pure-consumer proxy observations = " r(N)

quietly count if consumer_base_strict == 1
display as text ///
    "Strict pure-consumer proxy observations = " r(N)

display as text "------------------------------------------------------------"


*-------------------------------------------------------------------------------
* 3.11 Information-coverage diagnostics
*-------------------------------------------------------------------------------

capture drop ///
    base_core_info_max base_strict_info_max ///
    pre_core_info_wave pre_strict_info_wave ///
    n_pre_core_info_waves n_pre_strict_info_waves

bysort hhid: egen base_core_info_max = ///
    max(cond(wave <= `pre_end_lagged', core_prod_info_n, .))

bysort hhid: egen base_strict_info_max = ///
    max(cond(wave <= `pre_end_lagged', strict_prod_info_n, .))

gen pre_core_info_wave = ///
    (wave <= `pre_end_lagged' & core_prod_info_n > 0) if tag_hhw

gen pre_strict_info_wave = ///
    (wave <= `pre_end_lagged' & strict_prod_info_n > 0) if tag_hhw

bysort hhid: egen n_pre_core_info_waves = ///
    total(pre_core_info_wave)

bysort hhid: egen n_pre_strict_info_waves = ///
    total(pre_strict_info_wave)

label variable n_pre_core_info_waves ///
    "No. baseline waves with observed core production-module information"

label variable n_pre_strict_info_waves ///
    "No. baseline waves with observed broad production-module information"

* Diagnostics only.
* Do NOT automatically restrict the main sample by these variables because
* production-module missingness may reflect questionnaire skip patterns.
tab n_pre_core_info_waves if tag_hh, missing
tab n_pre_strict_info_waves if tag_hh, missing


*-------------------------------------------------------------------------------
* 3.12 Current consumer proxies
*-------------------------------------------------------------------------------

capture drop consumer consumer_strict

* Main current consumer proxy.
gen consumer = .

replace consumer = 1 ///
    if farmer_hh_wave == 0 ///
    & (producer_core_hh_wave == 0 | missing(producer_core_hh_wave))

replace consumer = 0 ///
    if farmer_hh_wave == 1 | producer_core_hh_wave == 1

label variable consumer ///
    "Current pure-consumer proxy: main/core"


* Strict current consumer proxy.
gen consumer_strict = .

replace consumer_strict = 1 ///
    if farmer_hh_wave == 0 ///
    & (producer_strict_hh_wave == 0 | missing(producer_strict_hh_wave))

replace consumer_strict = 0 ///
    if farmer_hh_wave == 1 | producer_strict_hh_wave == 1

label variable consumer_strict ///
    "Current pure-consumer proxy: strict/broad"


*-------------------------------------------------------------------------------
* 3.13 Post-policy entry into production
*-------------------------------------------------------------------------------

capture drop ever_producer ever_producer_strict ever_farmer

* Because production measures are treated as t-1,
* 2006 is the first survey wave with clearly post-policy production evidence
* if policy exposure begins in 2004.
bysort hhid: egen ever_producer = ///
    max(cond(wave >= 2006, producer_core_hh_wave, .))

bysort hhid: egen ever_producer_strict = ///
    max(cond(wave >= 2006, producer_strict_hh_wave, .))

label variable ever_producer ///
    "Ever post-policy core production evidence"

label variable ever_producer_strict ///
    "Ever post-policy broad production evidence"

* Legacy alias so older downstream files continue to run.
gen ever_farmer = ever_producer

label variable ever_farmer ///
    "Legacy alias of ever_producer"


*===============================================================================
* 4. WINSORIZATION
*===============================================================================

capture drop d3kcal_raw d3carbo_raw d3fat_raw d3protn_raw

* Preserve un-winsorized outcomes.
clonevar d3kcal_raw  = d3kcal
clonevar d3carbo_raw = d3carbo
clonevar d3fat_raw   = d3fat
clonevar d3protn_raw = d3protn

* Main specification: common 1st/99th percentile winsorization.
winsor2 d3kcal,  cuts(1 99) replace
winsor2 d3carbo, cuts(1 99) replace
winsor2 d3fat,   cuts(1 99) replace
winsor2 d3protn, cuts(1 99) replace


*===============================================================================
* 5. DEMOGRAPHICS AND LOG OUTCOMES
*===============================================================================

capture drop ///
    child elderly male ///
    n_age_obs n_gender_obs ///
    n_child n_elderly n_male ///
    elderly_share male_share

* Child and elderly indicators.
gen child = (age < 18) if !missing(age)
gen elderly = (age >= 65) if !missing(age)

* Household-wave counts.
bysort hhid wave: egen n_age_obs = count(age)
bysort hhid wave: egen n_child   = total(child)
bysort hhid wave: egen n_elderly = total(elderly)

* egen total() returns 0 when all inputs are missing; restore missing.
replace n_child   = . if n_age_obs == 0
replace n_elderly = . if n_age_obs == 0

* Gender.
gen male = (gender == 1) if !missing(gender)

bysort hhid wave: egen n_gender_obs = count(gender)
bysort hhid wave: egen n_male = total(male)

replace n_male = . if n_gender_obs == 0

* Shares.
gen elderly_share = n_elderly / hhsize ///
    if !missing(n_elderly) & !missing(hhsize) & hhsize > 0

gen male_share = n_male / hhsize ///
    if !missing(n_male) & !missing(hhsize) & hhsize > 0


*-------------------------------------------------------------------------------
* 5.1 Log nutrition outcomes
*-------------------------------------------------------------------------------

capture drop lnd3kcal lnd3carbo lnd3fat lnd3protn

gen lnd3kcal = ln(d3kcal) ///
    if d3kcal > 0 & d3kcal < .

gen lnd3carbo = ln(d3carbo) ///
    if d3carbo > 0 & d3carbo < .

gen lnd3fat = ln(d3fat) ///
    if d3fat > 0 & d3fat < .

gen lnd3protn = ln(d3protn) ///
    if d3protn > 0 & d3protn < .


*-------------------------------------------------------------------------------
* 5.2 Log household expenditure/income
*-------------------------------------------------------------------------------

capture drop lnhhexpense_real lnHHINC_real

quietly count if hhexpense_real <= -1 & !missing(hhexpense_real)
display as text ///
    "hhexpense_real invalid for ln(x+1): " r(N)

quietly count if HHINC_real <= -1 & !missing(HHINC_real)
display as text ///
    "HHINC_real invalid for ln(x+1): " r(N)

gen lnhhexpense_real = ln(hhexpense_real + 1) ///
    if hhexpense_real > -1 & hhexpense_real < .

gen lnHHINC_real = ln(HHINC_real + 1) ///
    if HHINC_real > -1 & HHINC_real < .


*===============================================================================
* 6. WAGES AND FARM CONSUMPTION
*===============================================================================

capture confirm variable C8
if !_rc {

    capture drop monthly_wage ln_monthly_wage

    gen monthly_wage = C8

    replace monthly_wage = . ///
        if inlist(monthly_wage, -9, -99, -999, -9999)

    gen ln_monthly_wage = ln(monthly_wage) ///
        if monthly_wage > 0 & monthly_wage < .
}

capture drop ln_farmconsume

gen ln_farmconsume = ln(1 + farmconsume) ///
    if farmconsume >= 0 & farmconsume < .


*===============================================================================
* 7. PANEL DECLARATION
*===============================================================================

xtset IDind wave
xtdescribe


*===============================================================================
* 8. EVENT-TIME INDICATORS
*===============================================================================

capture drop ///
    event_time evt_m7 evt_m4 evt_p0 evt_p2 evt_p5 evt_p7 evt_p11

* Event time relative to 2004.
gen event_time = wave - 2004

* Treated-group event-time indicators.
gen evt_m7 = (treated == 1 & event_time == -7)   // 1997
gen evt_m4 = (treated == 1 & event_time == -4)   // 2000, reference
gen evt_p0 = (treated == 1 & event_time ==  0)   // 2004
gen evt_p2 = (treated == 1 & event_time ==  2)   // 2006
gen evt_p5 = (treated == 1 & event_time ==  5)   // 2009
gen evt_p7 = (treated == 1 & event_time ==  7)   // 2011

* Normalize at 2000.
drop evt_m4


*-------------------------------------------------------------------------------
* 8.1 Optional 2015 event-time indicator
*-------------------------------------------------------------------------------

if $P2_ES_ADD_2015 {

    gen evt_p11 = (treated == 1 & event_time == 11)

    global P2_ES_EXTRA       "evt_p11"
    global P2_ES_KCAL_EXTRA  "evt_p11##i.lowS1_q25"
    global P2_ES_INC_EXTRA   "evt_p11##i.lowINC_q25"
    global P2_ES_DDD_EXTRA   "evt_p11##i.lowS1_q25##i.lowINC_q25"
    global P2_ES_MED_EXTRA   "evt_p11##i.lowS1"
    global P2_ES_ENTRY_EXTRA "evt_p11##i.ever_farmer"
}
else {

    global P2_ES_EXTRA       ""
    global P2_ES_KCAL_EXTRA  ""
    global P2_ES_INC_EXTRA   ""
    global P2_ES_DDD_EXTRA   ""
    global P2_ES_MED_EXTRA   ""
    global P2_ES_ENTRY_EXTRA ""
}


*===============================================================================
* END OF prep/01_data_prep.do
*
* RECOMMENDED ESTIMATION USAGE
*
* Main Paper 2 pure-consumer proxy:
*   ... if consumer_base == 1, vce(cluster cluster_commid)
*
* Occupation-only benchmark:
*   ... if consumer_base_occ == 1, vce(cluster cluster_commid)
*
* Strict robustness:
*   ... if consumer_base_strict == 1, vce(cluster cluster_commid)
*
* IMPORTANT
*   n_pre_core_info_waves and n_pre_strict_info_waves are diagnostics.
*   Do not mechanically restrict the sample with them unless the CHNS skip
*   patterns have been verified from the questionnaire/codebook.
*===============================================================================
