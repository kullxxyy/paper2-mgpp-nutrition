*===============================================================================
* PAPER 2 — BASELINE GROUPS AND NUTRITION COMPOSITION
* File: prep/05_baseline_groups.do
*
* FINAL BASELINE DESIGN USED HERE:
*   - Hunan (43) and Guizhou (52) only
*   - Pure consumers only: consumer_base == 1
*   - Clean pre-policy waves only: 1997 and 2000
*   - Household-level cutoffs are calculated using one observation per household
*   - 1997 and 2000 household-wave means receive equal weight
*   - Missing baseline group values remain missing (never recoded to 0)
*
* NOTE:
*   PART 5H is exploratory only. Contemporaneous groups must not be used as
*   the main causal heterogeneity definition.
*===============================================================================
display as error "==============================================="
display as error "RUNNING CURRENT 05_baseline_groups.do"
display as error "FILE VERSION: 2026-10-04 TEST"
display as error "==============================================="

*===============================================================================
* 0. SETTINGS AND CLEANUP
*===============================================================================

* Hunan / Guizhou analysis-population flag
capture drop baseline_hg

capture confirm variable t1
if !_rc {
    gen byte baseline_hg = inlist(t1, 43, 52)
}
else {
    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists. Cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte baseline_hg = inlist(province_code, 43, 52)
}

capture confirm variable consumer_base
if _rc {
    display as error ///
        "consumer_base not found. Run the pure-consumer preparation first."
    exit 111
}

* Make this file safely rerunnable.
local created_vars ///
    hh_wave_kcal tag_hhwave ///
    pre_kcal1 pre_kcal_hh qkcal_hh lowS1_q25 ///
    d3kcal_pre1 pre_kcal_hh1 pre_kcal_std1 ///
    q4 q5 q6 q10 low_q4 low_q5 low_q6 low_q10 ///
    q group3 ///
    pre_inc1 pre_inc qinc lowINC_q25 ///
    pre_kcal pre_kcal2 lowS lowS1 ///
    kcal_carb kcal_fat kcal_protein total_kcal ///
    carb_share fat_share protein_share ///
    kcal_imp sC_imp sF_imp sP_imp Q2 ///
    low_kcal kcal_q low_income q_income

foreach v of local created_vars {
    capture drop `v'
}


*===============================================================================
* %% PART 5A — HOUSEHOLD BASELINE-CALORIE QUARTILES
*
* Main low-calorie definition:
*   bottom 25% of baseline household calorie intake
*
* Baseline:
*   1997 and 2000 only
*
* Sample used to construct cutoff:
*   Hunan + Guizhou pure consumers only
*
* Construction:
*   1. Calculate mean individual kcal within each household-wave.
*   2. Average the household-wave means across 1997 and 2000.
*      This gives the two pre-policy waves equal weight.
*   3. Calculate quartiles using one observation per household.
*===============================================================================

* Household-wave mean kcal among the eligible baseline population.
bysort hhid wave: egen hh_wave_kcal = mean( ///
    cond( ///
        baseline_hg == 1 ///
        & consumer_base == 1 ///
        & inlist(wave, 1997, 2000), ///
        d3kcal, ///
        . ///
    ) ///
)

* One row per household-wave so household size does not determine wave weight.
egen tag_hhwave = tag(hhid wave)

* Equal-weight mean across available clean pre-policy waves.
bysort hhid: egen pre_kcal_hh = mean( ///
    cond( ///
        tag_hhwave == 1 ///
        & inlist(wave, 1997, 2000) ///
        & !missing(hh_wave_kcal), ///
        hh_wave_kcal, ///
        . ///
    ) ///
)

* Backward-compatible name used in older code.
gen pre_kcal1 = pre_kcal_hh

label variable pre_kcal_hh ///
    "Mean household calorie intake across 1997/2000"

preserve

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile qkcal_hh = pre_kcal_hh, nq(4)

    keep hhid pre_kcal_hh qkcal_hh

    tempfile kcal_qfile
    save `kcal_qfile'

restore

merge m:1 hhid using `kcal_qfile', ///
    nogen ///
    update replace ///
    keep(master match)

* Missing quartile stays missing.
gen byte lowS1_q25 = ///
    (qkcal_hh == 1) ///
    if !missing(qkcal_hh)

label variable lowS1_q25 ///
    "Low baseline calories: bottom 25% among Hunan-Guizhou pure consumers"


*===============================================================================
* %% PART 5B — CONTINUOUS BASELINE CALORIES
*
* Standardization is calculated using one observation per eligible household.
*===============================================================================

gen d3kcal_pre1 = ///
    d3kcal ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000)

* Backward-compatible alias.
gen pre_kcal_hh1 = pre_kcal_hh

preserve

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    egen pre_kcal_std1 = std(pre_kcal_hh)

    keep hhid pre_kcal_std1

    tempfile kcal_std_file
    save `kcal_std_file'

restore

merge m:1 hhid using `kcal_std_file', ///
    nogen ///
    keep(master match)

*===============================================================================
* PART 5C — ALTERNATIVE BASELINE-CALORIE CUTS
*===============================================================================

preserve

keep hhid pre_kcal_hh

drop if missing(hhid) | missing(pre_kcal_hh)

bysort hhid: keep if _n == 1

isid hhid


* Check usable household sample
count

local N_hh = r(N)

display as result ///
    "Unique households for baseline calorie cuts = `N_hh'"


* Do not construct quantiles when the sample has collapsed.
if `N_hh' < 20 {

    display as error ""
    display as error "============================================================"
    display as error "ERROR: BASELINE HOUSEHOLD SAMPLE TOO SMALL"
    display as error "Unique households = `N_hh'"
    display as error ""
    display as error "Do not construct q4/q5/q6/q10."
    display as error "Check upstream sample construction."
    display as error "============================================================"

    restore

    exit 2001
}


* Alternative calorie cutoffs
xtile q4  = pre_kcal_hh, nq(4)
xtile q5  = pre_kcal_hh, nq(5)
xtile q6  = pre_kcal_hh, nq(6)
xtile q10 = pre_kcal_hh, nq(10)


keep hhid q4 q5 q6 q10

tempfile alt_kcal_file

save `alt_kcal_file', replace

restore


merge m:1 hhid using `alt_kcal_file', ///
    nogen ///
    keep(master match)


gen byte low_q4 = ///
    (q4 == 1) ///
    if !missing(q4)

gen byte low_q5 = ///
    (q5 == 1) ///
    if !missing(q5)

gen byte low_q6 = ///
    (q6 == 1) ///
    if !missing(q6)

gen byte low_q10 = ///
    (q10 == 1) ///
    if !missing(q10)
    
*===============================================================================
* %% PART 5D — THREE CALORIE GROUPS
*
* 1 = bottom quartile
* 2 = second quartile
* 3 = upper half (Q3 + Q4)
*===============================================================================

gen q = qkcal_hh if !missing(qkcal_hh)

gen byte group3 = .

replace group3 = 1 if qkcal_hh == 1
replace group3 = 2 if qkcal_hh == 2
replace group3 = 3 if inrange(qkcal_hh, 3, 4)

label define g3 ///
    1 "bottom" ///
    2 "midlow" ///
    3 "upper", ///
    replace

label values group3 g3


*===============================================================================
* %% PART 5E — BASELINE-INCOME GROUP
*
* Uses the same clean pre-policy years (1997 and 2000) and the same
* Hunan-Guizhou pure-consumer population.
*
* Household-wave values receive equal weight across the two pre-policy waves.
*===============================================================================

bysort hhid wave: egen pre_inc1 = mean( ///
    cond( ///
        baseline_hg == 1 ///
        & consumer_base == 1 ///
        & inlist(wave, 1997, 2000), ///
        lnHHINC_real, ///
        . ///
    ) ///
)

bysort hhid: egen pre_inc = mean( ///
    cond( ///
        tag_hhwave == 1 ///
        & inlist(wave, 1997, 2000) ///
        & !missing(pre_inc1), ///
        pre_inc1, ///
        . ///
    ) ///
)

preserve

    keep hhid pre_inc

    drop if missing(pre_inc)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile qinc = pre_inc, nq(4)

    keep hhid pre_inc qinc

    tempfile income_groups
    save `income_groups'

restore

merge m:1 hhid using `income_groups', ///
    nogen ///
    update replace ///
    keep(master match)

gen byte lowINC_q25 = ///
    (qinc == 1) ///
    if !missing(qinc)

label variable lowINC_q25 ///
    "Low baseline income: bottom 25% among Hunan-Guizhou pure consumers"


*===============================================================================
* %% PART 5F — MEDIAN BASELINE-CALORIE GROUP
*
* Robustness only.
* Quartiles/halves are calculated with one observation per household.
*===============================================================================

gen pre_kcal = pre_kcal_hh
gen pre_kcal2 = pre_kcal_hh

preserve

    keep hhid pre_kcal2

    drop if missing(pre_kcal2)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile lowS = pre_kcal2, nq(2)

    keep hhid lowS

    tempfile median_kcal_file
    save `median_kcal_file'

restore

merge m:1 hhid using `median_kcal_file', ///
    nogen ///
    keep(master match)

gen byte lowS1 = ///
    (lowS == 1) ///
    if !missing(lowS)

label variable lowS1 ///
    "Low baseline calories: bottom half"


*===============================================================================
* %% PART 5G — MACRONUTRIENT SHARES AND QUALITY INDEX
*===============================================================================

gen kcal_carb = d3carbo * 4
gen kcal_fat = d3fat * 9
gen kcal_protein = d3protn * 4

gen total_kcal = ///
    kcal_carb ///
    + kcal_fat ///
    + kcal_protein

gen carb_share = ///
    kcal_carb / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)

gen fat_share = ///
    kcal_fat / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)

gen protein_share = ///
    kcal_protein / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)

gen kcal_imp = ///
    4*d3carbo ///
    + 9*d3fat ///
    + 4*d3protn

gen sC_imp = ///
    (4*d3carbo) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)

gen sF_imp = ///
    (9*d3fat) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)

gen sP_imp = ///
    (4*d3protn) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)

gen Q2 = ln( ///
    (9*(d3fat + 0.1) + 4*(d3protn + 0.1)) ///
    / ///
    (4*(d3carbo + 0.1)) ///
)


*===============================================================================
* %% PART 5H — CONTEMPORANEOUS EXPLORATORY GROUPS
*
* IMPORTANT:
*   These groups use contemporaneous outcomes/income and may therefore be
*   affected by treatment. They are exploratory only and must NOT define the
*   main causal heterogeneity groups.
*===============================================================================

summarize kcal_imp ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(kcal_imp), ///
    detail

local med_kcal = r(p50)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)

gen byte low_kcal = ///
    (kcal_imp < `med_kcal') ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(kcal_imp)

gen byte kcal_q = .

replace kcal_q = 1 ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & kcal_imp < `p25' ///
    & !missing(kcal_imp)

replace kcal_q = 2 ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & kcal_imp >= `p25' ///
    & kcal_imp < `p50' ///
    & !missing(kcal_imp)

replace kcal_q = 3 ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & kcal_imp >= `p50' ///
    & kcal_imp < `p75' ///
    & !missing(kcal_imp)

replace kcal_q = 4 ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & kcal_imp >= `p75' ///
    & !missing(kcal_imp)


* Contemporaneous income median: exploratory only.
summarize lnHHINC_real ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(lnHHINC_real), ///
    detail

local med_income = r(p50)

gen byte low_income = ///
    (lnHHINC_real <= `med_income') ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(lnHHINC_real)

label define lowinc ///
    0 "High income" ///
    1 "Low income", ///
    replace

label values low_income lowinc

xtile q_income = lnHHINC_real ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(lnHHINC_real), ///
    nq(4)

fvset base 1 q_income

label define qinc4 ///
    1 "Q1 (lowest)" ///
    2 "Q2" ///
    3 "Q3" ///
    4 "Q4 (highest)", ///
    replace

label values q_income qinc4


*===============================================================================
* %% PART 5I — DIAGNOSTICS
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "BASELINE-GROUP DIAGNOSTICS"

display as text ///
    "============================================================"

tab lowS1_q25 ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    missing

tab lowINC_q25 ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    missing

summarize pre_kcal_hh ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    detail

* Verify that missing quartiles have not been silently recoded as non-low.
assert missing(lowS1_q25) if missing(qkcal_hh)
assert missing(lowINC_q25) if missing(qinc)

* Check whether a person's household-based baseline group changes across waves.
capture drop lowS_min_check
capture drop lowS_max_check

bysort IDind: egen lowS_min_check = min(lowS1_q25)
bysort IDind: egen lowS_max_check = max(lowS1_q25)

quietly count ///
    if lowS_min_check != lowS_max_check ///
    & !missing(lowS_min_check, lowS_max_check)

local n_group_switch = r(N)

display as text ///
    "Individuals whose household-based baseline group changes across waves = " ///
    `n_group_switch'

if `n_group_switch' > 0 {
    display as error ///
        "WARNING: lowS1_q25 is not time-invariant for some individuals."
    display as error ///
        "Before final DDD estimation, anchor baseline group to a pre-policy household."
}

drop lowS_min_check lowS_max_check

display as text ///
    "============================================================"

*===============================================================================
* END OF prep/05_baseline_groups.do
*===============================================================================
