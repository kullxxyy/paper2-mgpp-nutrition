*===============================================================================
* PAPER 2 — BASELINE GROUPS AND NUTRITION COMPOSITION
* File: prep/05_baseline_groups.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 5A — HOUSEHOLD BASELINE-CALORIE QUARTILES
**# PART 5A — HOUSEHOLD BASELINE-CALORIE QUARTILES
*===============================================================================

bys hhid: egen pre_kcal1 = mean(d3kcal) if wave<2004
bys hhid: egen pre_kcal_hh = max(pre_kcal1)
preserve
keep hhid pre_kcal_hh
drop if missing(pre_kcal_hh)
bys hhid: keep if _n == 1
xtile qkcal_hh = pre_kcal_hh, nq(4)
tempfile qfile
save `qfile'
restore
merge m:1 hhid using `qfile', nogen
gen lowS1_q25 = (qkcal_hh == 1)
label var lowS1_q25 "Low subsistence: bottom 25% of pre-policy household calories"

*===============================================================================
* %% PART 5B — CONTINUOUS BASELINE CALORIES
**# PART 5B — CONTINUOUS BASELINE CALORIES
*===============================================================================

gen d3kcal_pre1 = d3kcal if wave < 2004
bys hhid: egen pre_kcal_hh1 = mean(d3kcal_pre1)

egen pre_kcal_std1 = std(pre_kcal_hh1)

*===============================================================================
* %% PART 5C — ALTERNATIVE BASELINE-CALORIE CUTS
**# PART 5C — ALTERNATIVE BASELINE-CALORIE CUTS
*===============================================================================

preserve
keep hhid pre_kcal_hh
drop if missing(pre_kcal_hh)
bys hhid: keep if _n == 1
isid hhid

xtile q4 = pre_kcal_hh, nq(4)
xtile q5 = pre_kcal_hh, nq(5)
xtile q6 = pre_kcal_hh, nq(6)
xtile q10 = pre_kcal_hh, nq(10)

tempfile qfile
save `qfile'
restore

merge m:1 hhid using `qfile', nogen

gen low_q4  = (q4==1)
gen low_q5  = (q5==1)
gen low_q6  = (q6==1)
gen low_q10 = (q10==1)

*===============================================================================
* %% PART 5D — THREE CALORIE GROUPS
**# PART 5D — THREE CALORIE GROUPS
*===============================================================================

gen q = qkcal_hh if !missing(qkcal_hh)
gen group3 = .
replace group3 = 1 if q==1
replace group3 = 2 if q==2
replace group3 = 3 if q>=3

label define g3 1 "bottom" 2 "midlow" 3 "upper"
label values group3 g3

*===============================================================================
* %% PART 5E — BASELINE-INCOME GROUP
**# PART 5E — BASELINE-INCOME GROUP
*===============================================================================

bys hhid: egen pre_inc1 = mean(lnHHINC_real) if wave < 2004
bys hhid: egen pre_inc = max(pre_inc1)

* Bottom quartile of baseline income
if $P2_INCOME_HH_Q {
    preserve
    keep hhid pre_inc
    drop if missing(pre_inc)
    bys hhid: keep if _n == 1
    xtile qinc = pre_inc, nq(4)
    tempfile income_groups
    save `income_groups'
    restore
    merge m:1 hhid using `income_groups', nogen keep(master match)
}
else {
    xtile qinc = pre_inc, nq(4)
}
gen lowINC_q25 = (qinc==1)
label var lowINC_q25 "Low income: bottom 25% pre-policy"

*===============================================================================
* %% PART 5F — MEDIAN BASELINE-CALORIE GROUP
**# PART 5F — MEDIAN BASELINE-CALORIE GROUP
*===============================================================================

bys hhid: egen pre_kcal = mean(d3kcal) if wave<2004   // adjust to your pre period definition
bys hhid: egen pre_kcal2 = max(pre_kcal)
xtile lowS = pre_kcal2, nq(2)
gen lowS1 = (lowS==1)   // bottom half of baseline calories

*===============================================================================
* %% PART 5G — MACRONUTRIENT SHARES AND QUALITY INDEX
**# PART 5G — MACRONUTRIENT SHARES AND QUALITY INDEX
*===============================================================================

gen kcal_carb = d3carbo * 4
gen kcal_fat = d3fat * 9
gen kcal_protein = d3protn * 4

gen total_kcal = kcal_carb + kcal_fat + kcal_protein

gen carb_share = kcal_carb / total_kcal
gen fat_share = kcal_fat / total_kcal
gen protein_share = kcal_protein / total_kcal
gen kcal_imp = 4*d3carbo + 9*d3fat + 4*d3protn
gen sC_imp = (4*d3carbo)/kcal_imp
gen sF_imp = (9*d3fat)/kcal_imp
gen sP_imp = (4*d3protn)/kcal_imp
gen Q2 = ln((9*(d3fat+0.1) + 4*(d3protn+0.1)) / (4*(d3carbo+0.1)))

*===============================================================================
* %% PART 5H — CONTEMPORANEOUS EXPLORATORY GROUPS
**# PART 5H — CONTEMPORANEOUS EXPLORATORY GROUPS
*===============================================================================

summarize kcal_imp, detail
local med_kcal = r(p50)
* Indicator for low-calorie (near-subsistence) households
gen low_kcal = kcal_imp < `med_kcal'

summ kcal_imp, detail
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)

gen kcal_q = .
replace kcal_q = 1 if kcal_imp <  `p25'
replace kcal_q = 2 if kcal_imp >= `p25' & kcal_imp < `p50'
replace kcal_q = 3 if kcal_imp >= `p50' & kcal_imp < `p75'
replace kcal_q = 4 if kcal_imp >= `p75'
sum lnHHINC_real, detail
gen low_income = (lnHHINC_real <= r(p50))
label define lowinc 0 "High income" 1 "Low income"
label values low_income lowinc
* Quartiles
xtile q_income = lnHHINC_real, nq(4)
fvset base 1 q_income
label define qinc 1 "Q1 (lowest)" 2 "Q2" 3 "Q3" 4 "Q4 (highest)", replace
label values q_income qinc

* Source compatibility: missing baseline group values become 0 in binary flags,
* and q>=3 / kcal_imp>=p75 also include Stata numeric missing. See CHANGES.md.
* These definitions have not been silently reclassified in this format refactor.
