*===============================================================================
* PAPER 2 — BASELINE GROUPS AND NUTRITION COMPOSITION
* File: prep/05_baseline_groups.do
*
* FINAL BASELINE DESIGN
*   - Hunan (43) + Guizhou (52) only
*   - Pure consumers only: consumer_base == 1
*   - Clean pre-policy waves only: 1997 and 2000
*   - Household-wave means are constructed first
*   - 1997 and 2000 receive equal weight
*   - Cutoffs are calculated using ONE observation per household
*   - Missing baseline values remain missing
*
* IMPORTANT
*   lowS1_q25 is the household-level baseline group.
*   lowS1_q25_fixed is the preferred individual-level fixed baseline group:
*       2000 household if available;
*       otherwise 1997 household.
*
*   The same logic is used for baseline income.
*
*   Contemporaneous groups in Part 5H are exploratory only and should not
*   define the main causal heterogeneity analysis.
*===============================================================================


*===============================================================================
* 0. DEFINE HUNAN-GUIZHOU BASELINE POPULATION
*===============================================================================

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


*===============================================================================
* 0B. CLEAN VARIABLES SO THIS FILE CAN BE RERUN SAFELY
*===============================================================================

local baseline_vars ///
    kcal_pre_eligible ///
    hh_wave_kcal ///
    tag_hhwave ///
    hh_wave_kcal_once ///
    pre_kcal1 ///
    pre_kcal_hh ///
    qkcal_hh ///
    lowS1_q25 ///
    d3kcal_pre1 ///
    pre_kcal_hh1 ///
    pre_kcal_std1 ///
    q4 ///
    q5 ///
    q6 ///
    q10 ///
    low_q4 ///
    low_q5 ///
    low_q6 ///
    low_q10 ///
    q ///
    group3 ///
    inc_pre_eligible ///
    hh_wave_inc ///
    hh_wave_inc_once ///
    pre_inc1 ///
    pre_inc ///
    qinc ///
    lowINC_q25 ///
    pre_kcal ///
    pre_kcal2 ///
    lowS ///
    lowS1 ///
    lowS_at_2000 ///
    lowS_at_1997 ///
    lowS1_q25_fixed ///
    lowINC_at_2000 ///
    lowINC_at_1997 ///
    lowINC_q25_fixed ///
    kcal_carb ///
    kcal_fat ///
    kcal_protein ///
    total_kcal ///
    carb_share ///
    fat_share ///
    protein_share ///
    kcal_imp ///
    sC_imp ///
    sF_imp ///
    sP_imp ///
    Q2 ///
    low_kcal ///
    kcal_q ///
    low_income ///
    q_income ///
    check_low_min ///
    check_low_max ///
    check_inc_min ///
    check_inc_max

foreach v of local baseline_vars {
    capture drop `v'
}


*===============================================================================
* %% PART 5A — HOUSEHOLD BASELINE-CALORIE QUARTILES
*
* Main definition:
*   baseline household calories = equal-weight average of the household-wave
*   mean in 1997 and the household-wave mean in 2000.
*
* Cutoff sample:
*   Hunan + Guizhou pure consumers only.
*===============================================================================

* Individual calorie observation eligible for baseline construction.
gen double kcal_pre_eligible = ///
    d3kcal ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000)


* First aggregate to household-wave level.
bysort hhid wave: egen hh_wave_kcal = mean(kcal_pre_eligible)


* Keep only one copy of each household-wave mean.
egen byte tag_hhwave = tag(hhid wave)

gen double hh_wave_kcal_once = ///
    hh_wave_kcal ///
    if tag_hhwave == 1 ///
    & inlist(wave, 1997, 2000) ///
    & baseline_hg == 1 ///
    & consumer_base == 1


* Then average across available clean pre-policy waves.
* Because there is one nonmissing value per household-wave,
* 1997 and 2000 receive equal weight.
bysort hhid: egen pre_kcal_hh = mean(hh_wave_kcal_once)


* Backward-compatible alias used in older code.
gen double pre_kcal1 = pre_kcal_hh


label variable pre_kcal_hh ///
    "Mean household calories across 1997/2000, equal wave weights"


* Household-level quartiles.
preserve

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile qkcal_hh = pre_kcal_hh, nq(4)

    keep hhid qkcal_hh

    tempfile kcal_quartiles
    save `kcal_quartiles'

restore


merge m:1 hhid using `kcal_quartiles', ///
    nogen ///
    keep(master match)


* Missing baseline group remains missing.
gen byte lowS1_q25 = ///
    (qkcal_hh == 1) ///
    if !missing(qkcal_hh)


label variable lowS1_q25 ///
    "Bottom 25% baseline calories among Hunan-Guizhou pure consumers"


*===============================================================================
* %% PART 5B — CONTINUOUS BASELINE CALORIES
*===============================================================================

gen double d3kcal_pre1 = ///
    d3kcal ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000)


* Backward-compatible name.
gen double pre_kcal_hh1 = pre_kcal_hh


* Standardize at the household level, not observation level.
preserve

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    egen pre_kcal_std1 = std(pre_kcal_hh)

    keep hhid pre_kcal_std1

    tempfile kcal_standardized
    save `kcal_standardized'

restore


merge m:1 hhid using `kcal_standardized', ///
    nogen ///
    keep(master match)


label variable pre_kcal_std1 ///
    "Standardized baseline household calories"


*===============================================================================
* %% PART 5C — ALTERNATIVE BASELINE-CALORIE CUTS
*
* Robustness definitions only.
*===============================================================================

preserve

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile q4  = pre_kcal_hh, nq(4)
    xtile q5  = pre_kcal_hh, nq(5)
    xtile q6  = pre_kcal_hh, nq(6)
    xtile q10 = pre_kcal_hh, nq(10)

    keep hhid q4 q5 q6 q10

    tempfile kcal_altcuts
    save `kcal_altcuts'

restore


merge m:1 hhid using `kcal_altcuts', ///
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
* 3 = upper half
*===============================================================================

gen byte q = qkcal_hh if !missing(qkcal_hh)

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
* Same clean pre-policy definition as calories:
*   Hunan + Guizhou pure consumers
*   1997 and 2000 only
*   household-wave first
*   equal weight across available pre-policy waves
*===============================================================================

gen double inc_pre_eligible = ///
    lnHHINC_real ///
    if baseline_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000)


bysort hhid wave: egen hh_wave_inc = mean(inc_pre_eligible)


gen double hh_wave_inc_once = ///
    hh_wave_inc ///
    if tag_hhwave == 1 ///
    & inlist(wave, 1997, 2000) ///
    & baseline_hg == 1 ///
    & consumer_base == 1


bysort hhid: egen pre_inc = mean(hh_wave_inc_once)


* Backward-compatible alias.
gen double pre_inc1 = pre_inc


preserve

    keep hhid pre_inc

    drop if missing(pre_inc)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile qinc = pre_inc, nq(4)

    keep hhid qinc

    tempfile income_quartiles
    save `income_quartiles'

restore


merge m:1 hhid using `income_quartiles', ///
    nogen ///
    keep(master match)


gen byte lowINC_q25 = ///
    (qinc == 1) ///
    if !missing(qinc)


label variable lowINC_q25 ///
    "Bottom 25% baseline income among Hunan-Guizhou pure consumers"


*===============================================================================
* %% PART 5F — MEDIAN BASELINE-CALORIE GROUP
*
* Robustness only.
* Cutoff is calculated with one observation per household.
*===============================================================================

gen double pre_kcal = pre_kcal_hh
gen double pre_kcal2 = pre_kcal_hh


preserve

    keep hhid pre_kcal2

    drop if missing(pre_kcal2)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile lowS = pre_kcal2, nq(2)

    keep hhid lowS

    tempfile kcal_median_group
    save `kcal_median_group'

restore


merge m:1 hhid using `kcal_median_group', ///
    nogen ///
    keep(master match)


gen byte lowS1 = ///
    (lowS == 1) ///
    if !missing(lowS)


label variable lowS1 ///
    "Bottom half of baseline household calories"


*===============================================================================
* %% PART 5G — FIX BASELINE GROUPS AT THE INDIVIDUAL LEVEL
*
* Preferred pre-policy household:
*   2000 household if observed;
*   otherwise 1997 household.
*
* These fixed variables are preferred for individual-FE heterogeneity models.
*===============================================================================

*---------------------------------------
* Fixed baseline calorie group
*---------------------------------------

bysort IDind: egen lowS_at_2000 = max( ///
    cond( ///
        wave == 2000 ///
        & baseline_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowS1_q25), ///
        lowS1_q25, ///
        . ///
    ) ///
)


bysort IDind: egen lowS_at_1997 = max( ///
    cond( ///
        wave == 1997 ///
        & baseline_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowS1_q25), ///
        lowS1_q25, ///
        . ///
    ) ///
)


gen byte lowS1_q25_fixed = lowS_at_2000

replace lowS1_q25_fixed = lowS_at_1997 ///
    if missing(lowS1_q25_fixed)


label variable lowS1_q25_fixed ///
    "Fixed baseline low-calorie status: 2000 household, fallback 1997"


drop lowS_at_2000 lowS_at_1997


*---------------------------------------
* Fixed baseline income group
*---------------------------------------

bysort IDind: egen lowINC_at_2000 = max( ///
    cond( ///
        wave == 2000 ///
        & baseline_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowINC_q25), ///
        lowINC_q25, ///
        . ///
    ) ///
)


bysort IDind: egen lowINC_at_1997 = max( ///
    cond( ///
        wave == 1997 ///
        & baseline_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowINC_q25), ///
        lowINC_q25, ///
        . ///
    ) ///
)


gen byte lowINC_q25_fixed = lowINC_at_2000

replace lowINC_q25_fixed = lowINC_at_1997 ///
    if missing(lowINC_q25_fixed)


label variable lowINC_q25_fixed ///
    "Fixed baseline low-income status: 2000 household, fallback 1997"


drop lowINC_at_2000 lowINC_at_1997


*===============================================================================
* %% PART 5H — MACRONUTRIENT SHARES AND QUALITY INDEX
*===============================================================================

gen double kcal_carb = d3carbo * 4
gen double kcal_fat = d3fat * 9
gen double kcal_protein = d3protn * 4


gen double total_kcal = ///
    kcal_carb ///
    + kcal_fat ///
    + kcal_protein


gen double carb_share = ///
    kcal_carb / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)


gen double fat_share = ///
    kcal_fat / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)


gen double protein_share = ///
    kcal_protein / total_kcal ///
    if total_kcal > 0 ///
    & !missing(total_kcal)


gen double kcal_imp = ///
    4*d3carbo ///
    + 9*d3fat ///
    + 4*d3protn


gen double sC_imp = ///
    (4*d3carbo) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)


gen double sF_imp = ///
    (9*d3fat) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)


gen double sP_imp = ///
    (4*d3protn) / kcal_imp ///
    if kcal_imp > 0 ///
    & !missing(kcal_imp)


gen double Q2 = ///
    ln( ///
        (9*(d3fat + 0.1) + 4*(d3protn + 0.1)) ///
        / ///
        (4*(d3carbo + 0.1)) ///
    ) ///
    if !missing(d3fat, d3protn, d3carbo)


*===============================================================================
* %% PART 5I — CONTEMPORANEOUS EXPLORATORY GROUPS
*
* EXPLORATORY ONLY.
* These use contemporaneous outcomes/income and therefore may be affected by
* treatment. Do NOT use these as the main causal heterogeneity groups.
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


* Contemporaneous income median — exploratory only.
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
* %% PART 5J — DIAGNOSTICS
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


tab lowS1_q25_fixed ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    missing


tab lowINC_q25 ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    missing


tab lowINC_q25_fixed ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    missing


summarize pre_kcal_hh ///
    if baseline_hg == 1 ///
    & consumer_base == 1, ///
    detail


* Missing quartile must remain missing in the household-level flag.
assert missing(lowS1_q25) ///
    if missing(qkcal_hh)

assert missing(lowINC_q25) ///
    if missing(qinc)


* Verify fixed calorie group is time-invariant.
bysort IDind: egen check_low_min = min(lowS1_q25_fixed)
bysort IDind: egen check_low_max = max(lowS1_q25_fixed)

quietly count ///
    if check_low_min != check_low_max ///
    & !missing(check_low_min, check_low_max)

display as text ///
    "Individuals whose fixed calorie group changes across waves = " ///
    r(N)

assert check_low_min == check_low_max ///
    if !missing(check_low_min, check_low_max)


drop check_low_min check_low_max


* Verify fixed income group is time-invariant.
bysort IDind: egen check_inc_min = min(lowINC_q25_fixed)
bysort IDind: egen check_inc_max = max(lowINC_q25_fixed)

quietly count ///
    if check_inc_min != check_inc_max ///
    & !missing(check_inc_min, check_inc_max)

display as text ///
    "Individuals whose fixed income group changes across waves = " ///
    r(N)

assert check_inc_min == check_inc_max ///
    if !missing(check_inc_min, check_inc_max)


drop check_inc_min check_inc_max


display as text ///
    "============================================================"


*===============================================================================
* END OF prep/05_baseline_groups.do
*===============================================================================
