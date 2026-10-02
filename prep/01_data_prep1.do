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

*-----------------------------
* 0) Set last pre-policy year
*-----------------------------
local pre_end = 2003
* Source timing retained: baseline excludes 2004.

*-----------------------------
* 1) Farmer member at baseline (pre-policy)
*-----------------------------
gen farmer_ind = (job == 5) if !missing(job)
bys hhid wave: egen farmer_hh_wave = max(farmer_ind)
bys hhid: egen base_farmer = max(farmer_hh_wave==1 & wave<=`pre_end')

*-----------------------------
* 2) Last-year producer evidence at baseline (pre-policy)
*    (measured at wave t, refers to t-1, but we still classify using pre-policy waves)
*-----------------------------
gen prod_land_l1 = (farmsize    > 0) if !missing(farmsize)
gen prod_inc_l1  = (HHFARM  > 0) if !missing(HHFARM)
gen prod_self_l1 = (farmconsume > 0) if !missing(farmconsume)
gen prod_exp_l1  = (farmexp     > 0) if !missing(farmexp)
gen prod_indf_l1 = (HHFISH     > 0) if !missing(HHFISH)
gen prod_indg_l1 = (hhgard     > 0) if !missing(hhgard)
gen prod_indl_l1 = (HHLVST     > 0) if !missing(HHLVST)

egen producer_l1 = rowmax(prod_land_l1 prod_inc_l1 prod_self_l1 prod_exp_l1 ///
                          prod_indf_l1 prod_indg_l1 prod_indl_l1)

bys hhid: egen base_producer = max(producer_l1==1 & wave<=`pre_end')

* Current-period producer evidence (at wave t)
replace producer_l1 = 0 if missing(producer_l1)
label define prod 0 "No ag activity" 1 "Ag activity"
label values producer_l1 prod
bysort hhid: egen ever_farmer = max(producer_l1 * (wave>=2004))

*-----------------------------
* 3) Define baseline pure consumer & keep fixed sample
*-----------------------------
gen consumer_base = (base_farmer==0 & base_producer==0)
label define cons 0 "Not baseline pure consumer" 1 "Baseline pure consumer", replace
label values consumer_base cons

tab consumer_base, missing
keep if consumer_base==1

xtset IDind wave
xtdescribe
tab wave 
tab producer_l1  t1 

preserve
keep if wave==2004 
tab wave t1 
restore 
gen consumer = (producer_l1==0 & farmer_hh_wave==0)

*===============================================================================
* %% PART 1C — WINSORIZATION
**# PART 1C — WINSORIZATION
*===============================================================================

*** extreme values 
* Calories and carbohydrates
winsor2 d3kcal,  cuts(1 99) replace
winsor2 d3carbo, cuts(1 99) replace

* Fat (more aggressive)
winsor2 d3fat,   cuts(2.5 97.5) replace

* Protein (light)
winsor2 d3protn, cuts(1 99) replace

sum d3kcal d3carbo d3fat d3protn

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
