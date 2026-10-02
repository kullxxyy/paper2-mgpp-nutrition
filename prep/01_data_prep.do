*===============================================================================
* PAPER 2 — SAMPLE, OUTCOMES AND EVENT VARIABLES
* File: prep/01_data_prep.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

* This module requires main.do's input checks and the Paper 2 input data.
if "$P2_DATA_FILE" == "" {
    display as error "Paper 2 configuration is not initialized. Run the entire main.do first."
    exit 198
}
capture confirm numeric variable job
if _rc {
    display as error "The active dataset has no numeric job variable."
    display as text "Run main.do so prep/00_checks.do loads and checks Paper 2 data."
    exit 111
}

*===============================================================================
* Harmonized community ID for clustering
*===============================================================================

gen cluster_commid = COMMID

capture confirm variable commid
if !_rc {
    replace cluster_commid = commid ///
        if missing(cluster_commid) & !missing(commid)
}

label variable cluster_commid "Community ID used for clustering"

quietly count if missing(cluster_commid)
display as text "Observations with missing cluster_commid: " r(N)

*===============================================================================
* %% PART 1A — ORIGINAL EXPENSE DIAGNOSTICS
**# PART 1A — ORIGINAL EXPENSE DIAGNOSTICS
*===============================================================================

* Optional original expense diagnostics (not needed by the estimators).
capture confirm numeric variable H4 hhexpense
if !_rc {
gen year_busexp=H4*12
gen diff=hhexpense-year_busexp
sort diff
*drop if diff==0 
*list F10A HHBUS hhexpense E5 year_busexp diff H2 E5 G5 h1d G16
gen have_exp=(hhexpense > 0)
*keep if hhexpense == 0
*drop if wave<2000 

tab wave
bysort t1: sum hhexpense

}

*===============================================================================
* %% PART 1B — BASELINE PURE-CONSUMER SAMPLE
**# PART 1B — BASELINE PURE-CONSUMER SAMPLE
*===============================================================================

*-----------------------------*
* 0) Define pre-policy timing
*-----------------------------*
* Current-period variables:
* 2004 is excluded because it is treated as the first policy-period wave.
local pre_end_current = 2003

* Lagged agricultural variables measured at wave t refer to t-1.
* Therefore, the 2004 survey can still contain information on 2003 activity.
local pre_end_lagged = 2004

*-----------------------------*
* 1) Farmer occupation at baseline
*-----------------------------*
* Individual is a farmer if primary occupation == 5.
* Keep missing job information as missing.
gen farmer_ind = (job == 5) if !missing(job)

* Household has a farmer in a given wave if at least one observed member is a farmer.
* If all household members' job information is missing, farmer_hh_wave remains missing.
bys hhid wave: egen farmer_hh_wave = max(farmer_ind)

* Baseline farmer status.
* 1 = farmer observed in at least one pre-policy wave
* 0 = observed in pre-policy waves, but no farmer found
* . = no usable pre-policy occupation information
bys hhid: egen base_farmer = ///
    max(cond(wave <= `pre_end_current', farmer_hh_wave, .))

*-----------------------------*
* 2) Lagged producer evidence
*-----------------------------*
foreach v in farmsize HHFARM farmconsume farmexp HHFISH hhgard HHLVST {
    replace `v' = . if inlist(`v', -9, -99, -999, -9999)
}

* Each variable equals:
* 1 = positive agricultural activity
* 0 = observed but no positive activity
* . = information missing

gen prod_land_l1 = (farmsize    > 0) if !missing(farmsize)
gen prod_inc_l1  = (HHFARM     > 0) if !missing(HHFARM)
gen prod_self_l1 = (farmconsume > 0) if !missing(farmconsume)
gen prod_exp_l1  = (farmexp     > 0) if !missing(farmexp)
gen prod_indf_l1 = (HHFISH      > 0) if !missing(HHFISH)
gen prod_indg_l1 = (hhgard      > 0) if !missing(hhgard)
gen prod_indl_l1 = (HHLVST      > 0) if !missing(HHLVST)

* Number of available agricultural indicators.
egen prod_info_n = rownonmiss( ///
    farmsize HHFARM farmconsume farmexp HHFISH hhgard HHLVST)

* Household-wave producer indicator.
* rowmax() returns:
* 1 if any observed indicator shows agricultural activity,
* 0 if indicators are observed but none shows activity,
* . if all indicators are missing.
egen producer_l1 = rowmax( ///
    prod_land_l1 prod_inc_l1 prod_self_l1 prod_exp_l1 ///
    prod_indf_l1 prod_indg_l1 prod_indl_l1)

label define prod ///
    0 "No observed ag activity" ///
    1 "Observed ag activity", replace

label values producer_l1 prod

* Baseline producer status.
* Because these variables refer to t-1,
* the 2004 wave is allowed to provide information on 2003 production.
bys hhid: egen base_producer = ///
    max(cond(wave <= `pre_end_lagged', producer_l1, .))

*-----------------------------*
* 3) Define baseline pure consumer
*-----------------------------*

* Conservative classification:
* 1 only when both baseline farmer and producer status are clearly zero.
* 0 whenever there is positive farming/production evidence.
* Missing remains missing when baseline information is insufficient.

gen consumer_base = .

replace consumer_base = 1 ///
    if base_farmer == 0 & base_producer == 0

replace consumer_base = 0 ///
    if base_farmer == 1 | base_producer == 1

label define cons ///
    0 "Not baseline pure consumer" ///
    1 "Baseline pure consumer", replace

label values consumer_base cons


*-----------------------------*
* 4) Baseline diagnostics
*-----------------------------*

tab consumer_base, missing

quietly count if missing(base_farmer)
display as text ///
    "Households/observations with unknown baseline farmer status: " r(N)

quietly count if missing(base_producer)
display as text ///
    "Households/observations with unknown baseline producer status: " r(N)

quietly count if missing(consumer_base)
display as text ///
    "Observations with insufficient baseline information: " r(N)

tab prod_info_n wave, missing
tab prod_info_n if wave<=2004, missing


* Household-wave agricultural information coverage
bys hhid wave: egen hh_prod_info = max(prod_info_n)

egen tag_hhw = tag(hhid wave)

tab hh_prod_info wave if tag_hhw, missing
tab hh_prod_info if tag_hhw & wave<=2004, missing

* Maximum number of available producer indicators
* observed in any pre-policy household-wave
bys hhid: egen base_prod_info_max = ///
    max(cond(wave <= 2004, hh_prod_info, .))

* Tag one observation per household
egen tag_hh = tag(hhid)

tab base_prod_info_max if tag_hh, missing

egen tag_hhw2 = tag(hhid wave)

gen pre_prodinfo_wave = ///
    (wave <= 2004 & hh_prod_info > 0) if tag_hhw2

bys hhid: egen n_pre_prodinfo_waves = total(pre_prodinfo_wave)

tab n_pre_prodinfo_waves if tag_hh, missing
*-----------------------------*
* 5) Keep fixed baseline pure-consumer sample
*-----------------------------*

keep if consumer_base == 1

xtset IDind wave
xtdescribe

*-----------------------------*
* 6) Current consumer status
*-----------------------------*

* Do not treat missing agricultural information as zero.
gen consumer = .

replace consumer = 1 ///
    if producer_l1 == 0 & farmer_hh_wave == 0

replace consumer = 0 ///
    if producer_l1 == 1 | farmer_hh_wave == 1


*-----------------------------*
* 7) Post-policy entry into production
*-----------------------------*

* producer_l1 is measured at wave t but refers to t-1.
* Therefore, 2006 is the first survey wave containing clearly post-policy
* production information if policy exposure begins in 2004.

bys hhid: egen ever_farmer = ///
    max(cond(wave >= 2006, producer_l1, .))

label variable ever_farmer ///
    "Ever observed producer in post-policy lagged production data"

    
*===============================================================================
* %% PART 1C — WINSORIZATION
**# PART 1C — WINSORIZATION
*===============================================================================

*** extreme values 
* Keep original nutrition outcomes
clonevar d3kcal_raw  = d3kcal
clonevar d3carbo_raw = d3carbo
clonevar d3fat_raw   = d3fat
clonevar d3protn_raw = d3protn

* Winsorize main outcomes
winsor2 d3kcal,  cuts(1 99) replace
winsor2 d3carbo, cuts(1 99) replace
winsor2 d3fat,   cuts(1 99) replace
winsor2 d3protn, cuts(1 99) replace

*===============================================================================
* %% PART 1D — DEMOGRAPHICS AND LOG OUTCOMES
**# PART 1D — DEMOGRAPHICS AND LOG OUTCOMES
*===============================================================================

gen child = age < 18 if !missing(age)
bys hhid wave: egen n_child = total(child)

gen elderly = age >= 65 if !missing(age)
bys hhid wave: egen n_elderly = total(elderly)

gen elderly_share = n_elderly / hhsize

gen male = gender == 1 if !missing(gender)
bys hhid wave: egen n_male = total(male)

gen male_share = n_male / hhsize
sum  n_child elderly_share male_share 

***Summary statistics 
***descriptive statistics about the  difference 
***control vs treated ttest 

gen lnd3kcal=ln(d3kcal)
gen lnd3carbo=ln(d3carbo)
gen lnd3fat=ln(d3fat)
gen lnd3protn=ln(d3protn)

gen lnhhexpense_real=ln(hhexpense_real+1)
gen lnHHINC_real=ln(HHINC_real+1)

*===============================================================================
* %% PART 1E — WAGES AND CONSUMPTION
**# PART 1E — WAGES AND CONSUMPTION
*===============================================================================

* Keep the original C8 column; create the shared wage outcome if it exists.
capture confirm variable C8
if !_rc {
    gen monthly_wage = C8
    replace monthly_wage = . if inlist(monthly_wage, -9999, -999, -9)
    gen ln_monthly_wage = ln(monthly_wage)
}
gen ln_farmconsume = ln(1 + farmconsume)

*===============================================================================
* %% PART 1F — EVENT-TIME INDICATORS
**# PART 1F — EVENT-TIME INDICATORS
*===============================================================================

******analysis 
***
* Event time relative to 2004
gen event_time = wave - 2004

* Only real event times in your data
gen evt_m7 = (treated==1 & event_time==-7)   // 1997
gen evt_m4 = (treated==1 & event_time==-4)   // 2000 (baseline)
gen evt_p0 = (treated==1 & event_time==0)    // 2004 (transition)
gen evt_p2 = (treated==1 & event_time==2)    // 2006
gen evt_p5 = (treated==1 & event_time==5)    // 2009
gen evt_p7 = (treated==1 & event_time==7)    // 2011

* Normalize at 2000
drop evt_m4

* Optional correction for an additional observed survey wave, off by default.
if $P2_ES_ADD_2015 {
    gen evt_p11 = (treated==1 & event_time==11)
    global P2_ES_EXTRA "evt_p11"
    global P2_ES_KCAL_EXTRA "evt_p11##i.lowS1_q25"
    global P2_ES_INC_EXTRA "evt_p11##i.lowINC_q25"
    global P2_ES_DDD_EXTRA "evt_p11##i.lowS1_q25##i.lowINC_q25"
    global P2_ES_MED_EXTRA "evt_p11##i.lowS1"
    global P2_ES_ENTRY_EXTRA "evt_p11##i.ever_farmer"
}
else {
    global P2_ES_EXTRA ""
    global P2_ES_KCAL_EXTRA ""
    global P2_ES_INC_EXTRA ""
    global P2_ES_DDD_EXTRA ""
    global P2_ES_MED_EXTRA ""
    global P2_ES_ENTRY_EXTRA ""
}
