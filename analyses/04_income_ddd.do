*===============================================================================
* PAPER 2 — BASELINE-INCOME HETEROGENEITY AND JOINT CALORIE × INCOME ANALYSIS
* File: analyses/04_income_ddd.do
*
* CURRENT STANDARD
*
* Sample:
*   Hunan vs Guizhou pure consumers
*
* Baseline income:
*   Individual-level mean household income in 1997 and 2000
*   Preferred income sample requires income observed in BOTH 1997 and 2000
*
* Policy timing:
*   2004 = announcement wave, estimated separately
*   2005 = implementation in Hunan
*   2006/2009/2011 = observed post-implementation waves
*   2000 = omitted/reference year in dynamic specifications
*
* Estimation:
*   Individual FE + wave FE
*   SE clustered at community level
*   No contemporaneous controls in preferred specifications
*
* Additional analysis:
*   Joint baseline calorie × baseline income heterogeneity uses the CURRENT
*   individual low-calorie definition (lowKCAL_i_q25), not old lowS1_q25.
*   The highest-order interaction is a FOUR-WAY interaction:
*       Hunan × Post × Low calorie × Low income
*
* IMPORTANT:
*   Preferred specifications are chosen for measurement/identification reasons,
*   not statistical significance.
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED PACKAGES
*===============================================================================

local outcomes kcal carbo fat protn

* Controls are used ONLY in a robustness specification.
* Current income is intentionally excluded because income itself is the
* heterogeneity dimension and may be affected by treatment.
local RD1 ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"


capture which reghdfe
if _rc {
    display as error "reghdfe is not installed."
    exit 199
}

capture which esttab
if _rc {
    display as error "esttab/eststo is not installed. Install estout first."
    exit 199
}


if "$P2_TABLES" == "" {
    display as error ///
        "Global P2_TABLES is empty. Run config.do/main.do first."
    exit 198
}

if "$P2_MODELS" == "" {
    display as error ///
        "Global P2_MODELS is empty. Run config.do/main.do first."
    exit 198
}


* Ensure the preferred community cluster variable exists.
capture confirm variable cluster_commid

if _rc {

    capture confirm variable COMMID

    if _rc {
        display as error ///
            "Neither cluster_commid nor COMMID exists."
        exit 111
    }

    capture confirm numeric variable COMMID

    if !_rc {
        gen long cluster_commid = COMMID
    }
    else {
        encode COMMID, gen(cluster_commid)
    }
}


*===============================================================================
* 1. DEFINE HUNAN-GUIZHOU PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in inc_sample_hg inc_treated_hg inc_sample_pc {
    capture drop `v'
}


capture confirm variable t1

if !_rc {

    gen byte inc_sample_hg = ///
        inlist(t1, 43, 52)

    gen byte inc_treated_hg = ///
        (t1 == 43) ///
        if inc_sample_hg == 1
}

else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists."
        exit 111
    }

    gen byte inc_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte inc_treated_hg = ///
        (province_code == 43) ///
        if inc_sample_hg == 1
}


capture confirm variable consumer_base

if _rc {
    display as error ///
        "consumer_base not found. Run the pure-consumer preparation first."
    exit 111
}


gen byte inc_sample_pc = ///
    inc_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


capture label define inc_hg_treat ///
    0 "Guizhou" ///
    1 "Hunan"

if _rc {
    label define inc_hg_treat ///
        0 "Guizhou" ///
        1 "Hunan", ///
        replace
}

label values inc_treated_hg inc_hg_treat


display as text "============================================================"
display as text "04 INCOME DDD — HUNAN-GUIZHOU PURE-CONSUMER SAMPLE"
display as text "============================================================"

tab inc_treated_hg ///
    if inc_sample_pc == 1, ///
    missing

tab wave ///
    if inc_sample_pc == 1, ///
    missing


*===============================================================================
* 2. CONSTRUCT INDIVIDUAL BASELINE INCOME
*
* Baseline = 1997 and 2000 only.
*
* pre_inc_i:
*   Individual's mean observed log real household income over 1997/2000.
*
* lowINC_i_q25:
*   Bottom quartile of the individual baseline-income distribution.
*
* The grouping variable is fixed over time.
*===============================================================================

capture confirm variable lnHHINC_real

if _rc {
    display as error ///
        "lnHHINC_real not found."
    exit 111
}


foreach v in ///
    inc_pre97_i ///
    inc_pre00_i ///
    inc_pre_i ///
    inc_pre_n_i ///
    inc_q_i ///
    lowINC_i_q25 ///
    inc_tag_pre {

    capture drop `v'
}


bysort IDind: egen double inc_pre97_i = max( ///
    cond( ///
        wave == 1997 ///
        & inc_sample_pc == 1 ///
        & !missing(lnHHINC_real), ///
        lnHHINC_real, ///
        . ///
    ) ///
)


bysort IDind: egen double inc_pre00_i = max( ///
    cond( ///
        wave == 2000 ///
        & inc_sample_pc == 1 ///
        & !missing(lnHHINC_real), ///
        lnHHINC_real, ///
        . ///
    ) ///
)


egen double inc_pre_i = rowmean( ///
    inc_pre97_i ///
    inc_pre00_i ///
)


gen byte inc_pre_n_i = ///
    !missing(inc_pre97_i) ///
    + !missing(inc_pre00_i)


label variable inc_pre_i ///
    "Individual mean baseline log real household income, 1997/2000"

label variable inc_pre_n_i ///
    "Number of clean pre-policy income observations"


* Calculate quartiles using ONE observation per individual.
preserve

keep if ///
    inc_sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(inc_pre_i)

keep IDind inc_pre_i inc_pre_n_i

bysort IDind: keep if _n == 1

isid IDind

xtile inc_q_i = inc_pre_i, nq(4)

keep IDind inc_q_i

tempfile income_groups
save `income_groups'

restore


merge m:1 IDind ///
    using `income_groups', ///
    nogen ///
    keep(master match)


gen byte lowINC_i_q25 = ///
    (inc_q_i == 1) ///
    if !missing(inc_q_i)


label variable lowINC_i_q25 ///
    "Individual baseline income: bottom 25%"


* Verify time invariance.
foreach v in __inc_min __inc_max {
    capture drop `v'
}

bysort IDind: egen byte __inc_min = min(lowINC_i_q25)
bysort IDind: egen byte __inc_max = max(lowINC_i_q25)

assert __inc_min == __inc_max ///
    if !missing(__inc_min, __inc_max)

drop __inc_min
drop __inc_max


egen byte inc_tag_pre = tag(IDind) ///
    if inc_sample_pc == 1 ///
    & !missing(inc_pre_i)


display as text "============================================================"
display as text "BASELINE-INCOME DIAGNOSTICS"
display as text "============================================================"

tab inc_pre_n_i ///
    if inc_tag_pre == 1, ///
    missing

summarize inc_pre_i ///
    if inc_tag_pre == 1, ///
    detail

tab lowINC_i_q25 inc_treated_hg ///
    if inc_tag_pre == 1, ///
    column


*===============================================================================
* 3. DEFINE INCOME ANALYSIS SAMPLES
*
* Preferred sample:
*   income observed in BOTH 1997 and 2000.
*
* All-available-baseline sample:
*   retained only for robustness.
*===============================================================================

foreach v in ///
    sample_income_all ///
    sample_income_pre2 {

    capture drop `v'
}


gen byte sample_income_all = ///
    inc_sample_pc == 1 ///
    & !missing(lowINC_i_q25)


gen byte sample_income_pre2 = ///
    sample_income_all == 1 ///
    & inc_pre_n_i == 2


display as text "============================================================"
display as text "PREFERRED TWO-PRE-WAVE INCOME SAMPLE"
display as text "============================================================"

capture drop __tag_income_pre2

egen byte __tag_income_pre2 = tag(IDind) ///
    if sample_income_pre2 == 1

count if __tag_income_pre2 == 1

display as text ///
    "Number of individuals with income in both 1997 and 2000 = " ///
    r(N)

tab inc_treated_hg ///
    if __tag_income_pre2 == 1, ///
    missing

tab lowINC_i_q25 inc_treated_hg ///
    if __tag_income_pre2 == 1, ///
    column

drop __tag_income_pre2


*===============================================================================
* 4. POLICY PERIOD VARIABLES
*
* 2004 = announcement wave.
* 2006+ = observed implementation period.
*===============================================================================

foreach v in ///
    inc_ann2004 ///
    inc_post_impl {

    capture drop `v'
}


gen byte inc_ann2004 = ///
    (wave == 2004)

gen byte inc_post_impl = ///
    (wave >= 2006)


label variable inc_ann2004 ///
    "Announcement wave: 2004"

label variable inc_post_impl ///
    "Implementation period: 2006+"


*===============================================================================
* 5. PREFERRED POOLED INCOME-HETEROGENEITY DDD
*
* Fully saturated period-specific DDD:
*
*   Hunan × Period
*   Low income × Period
*   Hunan × Low income × Period
*
* Announcement and implementation periods are separated.
*===============================================================================

foreach v in ///
    inc_hunan_ann ///
    inc_low_ann ///
    inc_ddd_ann ///
    inc_hunan_impl ///
    inc_low_impl ///
    inc_ddd_impl {

    capture drop `v'
}


* Announcement terms.
gen byte inc_hunan_ann = ///
    inc_treated_hg * inc_ann2004 ///
    if sample_income_pre2 == 1

gen byte inc_low_ann = ///
    lowINC_i_q25 * inc_ann2004 ///
    if sample_income_pre2 == 1

gen byte inc_ddd_ann = ///
    inc_treated_hg * lowINC_i_q25 * inc_ann2004 ///
    if sample_income_pre2 == 1


* Implementation terms.
gen byte inc_hunan_impl = ///
    inc_treated_hg * inc_post_impl ///
    if sample_income_pre2 == 1

gen byte inc_low_impl = ///
    lowINC_i_q25 * inc_post_impl ///
    if sample_income_pre2 == 1

gen byte inc_ddd_impl = ///
    inc_treated_hg * lowINC_i_q25 * inc_post_impl ///
    if sample_income_pre2 == 1


label variable inc_hunan_ann ///
    "Hunan x Announcement 2004"

label variable inc_low_ann ///
    "Low baseline income x Announcement 2004"

label variable inc_ddd_ann ///
    "Hunan x Low income x Announcement 2004 (DDD)"

label variable inc_hunan_impl ///
    "Hunan x Implementation period"

label variable inc_low_impl ///
    "Low baseline income x Implementation period"

label variable inc_ddd_impl ///
    "Hunan x Low income x Implementation period (DDD)"


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "PREFERRED INCOME DDD: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        inc_hunan_ann ///
        inc_low_ann ///
        inc_ddd_ann ///
        inc_hunan_impl ///
        inc_low_impl ///
        inc_ddd_impl ///
        if sample_income_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_MAIN_`y'


    * Main heterogeneity parameter during implementation.
    test inc_ddd_impl

    scalar inc_main_impl_b_`y' = _b[inc_ddd_impl]
    scalar inc_main_impl_p_`y' = r(p)


    * Announcement-period heterogeneity.
    test inc_ddd_ann

    scalar inc_main_ann_b_`y' = _b[inc_ddd_ann]
    scalar inc_main_ann_p_`y' = r(p)


    * Total Hunan effect for LOW-income individuals during implementation.
    lincom inc_hunan_impl + inc_ddd_impl

    scalar inc_low_impl_b_`y'  = r(estimate)
    scalar inc_low_impl_se_`y' = r(se)
    scalar inc_low_impl_p_`y'  = r(p)


    * Total Hunan effect for LOW-income individuals in 2004.
    lincom inc_hunan_ann + inc_ddd_ann

    scalar inc_low_ann_b_`y'  = r(estimate)
    scalar inc_low_ann_se_`y' = r(se)
    scalar inc_low_ann_p_`y'  = r(p)


    * Is implementation heterogeneity different from announcement heterogeneity?
    test inc_ddd_impl = inc_ddd_ann

    scalar inc_impl_vs_ann_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/04_income_main_`y'.ster", ///
        replace
}


esttab ///
    INC_MAIN_kcal ///
    INC_MAIN_carbo ///
    INC_MAIN_fat ///
    INC_MAIN_protn ///
    using "$P2_TABLES/04_income_main_DDD.rtf", ///
    replace ///
    keep( ///
        inc_hunan_ann ///
        inc_low_ann ///
        inc_ddd_ann ///
        inc_hunan_impl ///
        inc_low_impl ///
        inc_ddd_impl ///
    ) ///
    order( ///
        inc_hunan_ann ///
        inc_low_ann ///
        inc_ddd_ann ///
        inc_hunan_impl ///
        inc_low_impl ///
        inc_ddd_impl ///
    ) ///
    coeflabels( ///
        inc_hunan_ann ///
            "Hunan x Announcement 2004" ///
        inc_low_ann ///
            "Low income x Announcement 2004" ///
        inc_ddd_ann ///
            "Hunan x Low income x Announcement 2004 (DDD)" ///
        inc_hunan_impl ///
            "Hunan x Implementation period" ///
        inc_low_impl ///
            "Low income x Implementation period" ///
        inc_ddd_impl ///
            "Hunan x Low income x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Baseline-income heterogeneity: preferred two-pre-wave DDD") ///
    addnotes( ///
        "Baseline income is the individual mean of log real household income in 1997 and 2000", ///
        "Preferred sample requires income observed in both pre-policy waves", ///
        "2004 is treated separately as the announcement wave", ///
        "Implementation period: 2006, 2009, and 2011", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 6. DYNAMIC INCOME-HETEROGENEITY DDD
*
* 2000 = omitted/reference year.
* 1997 = clean pre-treatment lead.
* 2004 = announcement.
* 2006/2009/2011 = implementation observations.
*===============================================================================

foreach v in ///
    inc_h97 inc_h04 inc_h06 inc_h09 inc_h11 ///
    inc_l97 inc_l04 inc_l06 inc_l09 inc_l11 ///
    inc_d97 inc_d04 inc_d06 inc_d09 inc_d11 {

    capture drop `v'
}


* Hunan x wave.
gen byte inc_h97 = inc_treated_hg * (wave == 1997) ///
    if sample_income_pre2 == 1

gen byte inc_h04 = inc_treated_hg * (wave == 2004) ///
    if sample_income_pre2 == 1

gen byte inc_h06 = inc_treated_hg * (wave == 2006) ///
    if sample_income_pre2 == 1

gen byte inc_h09 = inc_treated_hg * (wave == 2009) ///
    if sample_income_pre2 == 1

gen byte inc_h11 = inc_treated_hg * (wave == 2011) ///
    if sample_income_pre2 == 1


* Low income x wave.
gen byte inc_l97 = lowINC_i_q25 * (wave == 1997) ///
    if sample_income_pre2 == 1

gen byte inc_l04 = lowINC_i_q25 * (wave == 2004) ///
    if sample_income_pre2 == 1

gen byte inc_l06 = lowINC_i_q25 * (wave == 2006) ///
    if sample_income_pre2 == 1

gen byte inc_l09 = lowINC_i_q25 * (wave == 2009) ///
    if sample_income_pre2 == 1

gen byte inc_l11 = lowINC_i_q25 * (wave == 2011) ///
    if sample_income_pre2 == 1


* Hunan x Low income x wave = dynamic DDD.
gen byte inc_d97 = ///
    inc_treated_hg * lowINC_i_q25 * (wave == 1997) ///
    if sample_income_pre2 == 1

gen byte inc_d04 = ///
    inc_treated_hg * lowINC_i_q25 * (wave == 2004) ///
    if sample_income_pre2 == 1

gen byte inc_d06 = ///
    inc_treated_hg * lowINC_i_q25 * (wave == 2006) ///
    if sample_income_pre2 == 1

gen byte inc_d09 = ///
    inc_treated_hg * lowINC_i_q25 * (wave == 2009) ///
    if sample_income_pre2 == 1

gen byte inc_d11 = ///
    inc_treated_hg * lowINC_i_q25 * (wave == 2011) ///
    if sample_income_pre2 == 1


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "DYNAMIC INCOME DDD: `y'"
    display as text "Reference year = 2000"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        inc_h97 inc_h04 inc_h06 inc_h09 inc_h11 ///
        inc_l97 inc_l04 inc_l06 inc_l09 inc_l11 ///
        inc_d97 inc_d04 inc_d06 inc_d09 inc_d11 ///
        if sample_income_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_ES_`y'


    * Differential pretrend diagnostic.
    test inc_d97

    scalar inc_pre_b_`y' = _b[inc_d97]
    scalar inc_pre_p_`y' = r(p)


    * Announcement-year dynamic DDD.
    test inc_d04

    scalar inc_dyn04_b_`y' = _b[inc_d04]
    scalar inc_dyn04_p_`y' = r(p)


    * Joint implementation-period DDD.
    test inc_d06 inc_d09 inc_d11

    scalar inc_postjoint_p_`y' = r(p)


    display as text ///
        "1997 pretrend p-value = " ///
        %9.4f scalar(inc_pre_p_`y')

    display as text ///
        "Joint 2006/2009/2011 DDD p-value = " ///
        %9.4f scalar(inc_postjoint_p_`y')


    estimates save ///
        "$P2_MODELS/04_income_event_`y'.ster", ///
        replace
}


esttab ///
    INC_ES_kcal ///
    INC_ES_carbo ///
    INC_ES_fat ///
    INC_ES_protn ///
    using "$P2_TABLES/04_income_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        inc_d97 ///
        inc_d04 ///
        inc_d06 ///
        inc_d09 ///
        inc_d11 ///
    ) ///
    order( ///
        inc_d97 ///
        inc_d04 ///
        inc_d06 ///
        inc_d09 ///
        inc_d11 ///
    ) ///
    coeflabels( ///
        inc_d97 "1997 x Hunan x Low income" ///
        inc_d04 "2004 x Hunan x Low income" ///
        inc_d06 "2006 x Hunan x Low income" ///
        inc_d09 "2009 x Hunan x Low income" ///
        inc_d11 "2011 x Hunan x Low income" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Dynamic DDD by baseline income") ///
    addnotes( ///
        "Reference year: 2000", ///
        "1997 triple interaction is the differential pretrend diagnostic", ///
        "2004 is the announcement wave", ///
        "2006, 2009, and 2011 are post-implementation observations", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 7. ROBUSTNESS A — ALL AVAILABLE BASELINE-INCOME OBSERVATIONS
*
* This uses individuals with at least one baseline-income observation.
* It does NOT replace the preferred two-pre-wave sample.
*===============================================================================

foreach v in ///
    inca_hunan_ann ///
    inca_low_ann ///
    inca_ddd_ann ///
    inca_hunan_impl ///
    inca_low_impl ///
    inca_ddd_impl {

    capture drop `v'
}


gen byte inca_hunan_ann = ///
    inc_treated_hg * inc_ann2004 ///
    if sample_income_all == 1

gen byte inca_low_ann = ///
    lowINC_i_q25 * inc_ann2004 ///
    if sample_income_all == 1

gen byte inca_ddd_ann = ///
    inc_treated_hg * lowINC_i_q25 * inc_ann2004 ///
    if sample_income_all == 1


gen byte inca_hunan_impl = ///
    inc_treated_hg * inc_post_impl ///
    if sample_income_all == 1

gen byte inca_low_impl = ///
    lowINC_i_q25 * inc_post_impl ///
    if sample_income_all == 1

gen byte inca_ddd_impl = ///
    inc_treated_hg * lowINC_i_q25 * inc_post_impl ///
    if sample_income_all == 1


eststo clear

foreach y of local outcomes {

    reghdfe lnd3`y' ///
        inca_hunan_ann ///
        inca_low_ann ///
        inca_ddd_ann ///
        inca_hunan_impl ///
        inca_low_impl ///
        inca_ddd_impl ///
        if sample_income_all == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_ALL_`y'

    test inca_ddd_impl

    scalar inc_all_impl_b_`y' = _b[inca_ddd_impl]
    scalar inc_all_impl_p_`y' = r(p)
}


esttab ///
    INC_ALL_kcal ///
    INC_ALL_carbo ///
    INC_ALL_fat ///
    INC_ALL_protn ///
    using "$P2_TABLES/04_income_robust_allbaseline_DDD.rtf", ///
    replace ///
    keep( ///
        inca_ddd_ann ///
        inca_ddd_impl ///
    ) ///
    order( ///
        inca_ddd_ann ///
        inca_ddd_impl ///
    ) ///
    coeflabels( ///
        inca_ddd_ann ///
            "Hunan x Low income x Announcement 2004" ///
        inca_ddd_impl ///
            "Hunan x Low income x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Income heterogeneity robustness: all available baseline income")


*===============================================================================
* 8. ROBUSTNESS B — CONTEMPORANEOUS CONTROLS
*
* Preferred sample is unchanged.
* Controls are NOT used in the main specification.
* Current household income is intentionally NOT controlled for.
*===============================================================================

eststo clear

foreach y of local outcomes {

    reghdfe lnd3`y' ///
        inc_hunan_ann ///
        inc_low_ann ///
        inc_ddd_ann ///
        inc_hunan_impl ///
        inc_low_impl ///
        inc_ddd_impl ///
        `RD1' ///
        if sample_income_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_CTRL_`y'

    test inc_ddd_impl

    scalar inc_ctrl_impl_b_`y' = _b[inc_ddd_impl]
    scalar inc_ctrl_impl_p_`y' = r(p)
}


esttab ///
    INC_CTRL_kcal ///
    INC_CTRL_carbo ///
    INC_CTRL_fat ///
    INC_CTRL_protn ///
    using "$P2_TABLES/04_income_robust_controls_DDD.rtf", ///
    replace ///
    keep( ///
        inc_ddd_ann ///
        inc_ddd_impl ///
    ) ///
    order( ///
        inc_ddd_ann ///
        inc_ddd_impl ///
    ) ///
    coeflabels( ///
        inc_ddd_ann ///
            "Hunan x Low income x Announcement 2004" ///
        inc_ddd_impl ///
            "Hunan x Low income x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Income heterogeneity robustness: contemporaneous controls") ///
    addnotes( ///
        "Preferred two-pre-wave sample", ///
        "Current household income is not included as a control", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 9. PREPARE CURRENT INDIVIDUAL LOW-CALORIE GROUP FOR JOINT ANALYSIS
*
* If lowKCAL_i_q25 and pre_kcal_n_i already exist from 03b, reuse them.
* Otherwise construct them here using the SAME definition:
*   mean individual calories in 1997/2000;
*   bottom quartile across individuals.
*===============================================================================

local need_kcal_group = 0

capture confirm variable lowKCAL_i_q25
if _rc {
    local need_kcal_group = 1
}

capture confirm variable pre_kcal_n_i
if _rc {
    local need_kcal_group = 1
}


if `need_kcal_group' == 1 {

    foreach v in ///
        pre_kcal97_i ///
        pre_kcal00_i ///
        pre_kcal_i ///
        pre_kcal_n_i ///
        qkcal_i ///
        lowKCAL_i_q25 {

        capture drop `v'
    }


    bysort IDind: egen double pre_kcal97_i = max( ///
        cond( ///
            wave == 1997 ///
            & inc_sample_pc == 1 ///
            & !missing(d3kcal), ///
            d3kcal, ///
            . ///
        ) ///
    )


    bysort IDind: egen double pre_kcal00_i = max( ///
        cond( ///
            wave == 2000 ///
            & inc_sample_pc == 1 ///
            & !missing(d3kcal), ///
            d3kcal, ///
            . ///
        ) ///
    )


    egen double pre_kcal_i = rowmean( ///
        pre_kcal97_i ///
        pre_kcal00_i ///
    )


    gen byte pre_kcal_n_i = ///
        !missing(pre_kcal97_i) ///
        + !missing(pre_kcal00_i)


    preserve

    keep if ///
        inc_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(pre_kcal_i)

    keep IDind pre_kcal_i pre_kcal_n_i

    bysort IDind: keep if _n == 1

    isid IDind

    xtile qkcal_i = pre_kcal_i, nq(4)

    keep IDind qkcal_i

    tempfile calorie_groups_04
    save `calorie_groups_04'

    restore


    merge m:1 IDind ///
        using `calorie_groups_04', ///
        nogen ///
        keep(master match)


    gen byte lowKCAL_i_q25 = ///
        (qkcal_i == 1) ///
        if !missing(qkcal_i)


    label variable lowKCAL_i_q25 ///
        "Individual baseline calories: bottom 25%"
}


*===============================================================================
* 10. JOINT CALORIE × INCOME HETEROGENEITY
*
* Strict sample:
*   baseline calories observed in BOTH 1997 and 2000
*   baseline income observed in BOTH 1997 and 2000
*
* This replaces the OLD:
*   did##i.lowS1_q25##i.lowINC_q25
*
* with the CURRENT individual definitions:
*   lowKCAL_i_q25
*   lowINC_i_q25
*
* The highest-order coefficient is a FOUR-WAY interaction:
*   Hunan × Period × Low calorie × Low income
*===============================================================================

capture drop sample_joint_pre2

gen byte sample_joint_pre2 = ///
    inc_sample_pc == 1 ///
    & inc_pre_n_i == 2 ///
    & pre_kcal_n_i == 2 ///
    & !missing(lowINC_i_q25) ///
    & !missing(lowKCAL_i_q25)


display as text "============================================================"
display as text "STRICT JOINT CALORIE × INCOME SAMPLE"
display as text "============================================================"

capture drop __tag_joint_pre2

egen byte __tag_joint_pre2 = tag(IDind) ///
    if sample_joint_pre2 == 1

count if __tag_joint_pre2 == 1

display as text ///
    "Number of strict joint-sample individuals = " ///
    r(N)

tab lowKCAL_i_q25 lowINC_i_q25 ///
    if __tag_joint_pre2 == 1, ///
    row column

drop __tag_joint_pre2


*-------------------------------------------------------------------------------
* 10A. POOLED JOINT HETEROGENEITY — FULL LOWER-ORDER SATURATION
*-------------------------------------------------------------------------------

foreach v in ///
    j_h_ann ///
    j_k_ann ///
    j_i_ann ///
    j_hk_ann ///
    j_hi_ann ///
    j_ki_ann ///
    j_hki_ann ///
    j_h_impl ///
    j_k_impl ///
    j_i_impl ///
    j_hk_impl ///
    j_hi_impl ///
    j_ki_impl ///
    j_hki_impl {

    capture drop `v'
}


* Announcement 2004.
gen byte j_h_ann = ///
    inc_treated_hg * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_k_ann = ///
    lowKCAL_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_i_ann = ///
    lowINC_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_hk_ann = ///
    inc_treated_hg * lowKCAL_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_hi_ann = ///
    inc_treated_hg * lowINC_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_ki_ann = ///
    lowKCAL_i_q25 * lowINC_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1

gen byte j_hki_ann = ///
    inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * inc_ann2004 ///
    if sample_joint_pre2 == 1


* Implementation period.
gen byte j_h_impl = ///
    inc_treated_hg * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_k_impl = ///
    lowKCAL_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_i_impl = ///
    lowINC_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_hk_impl = ///
    inc_treated_hg * lowKCAL_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_hi_impl = ///
    inc_treated_hg * lowINC_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_ki_impl = ///
    lowKCAL_i_q25 * lowINC_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1

gen byte j_hki_impl = ///
    inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * inc_post_impl ///
    if sample_joint_pre2 == 1


label variable j_hki_ann ///
    "Hunan x Low kcal x Low income x Announcement 2004"

label variable j_hki_impl ///
    "Hunan x Low kcal x Low income x Implementation period"


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "JOINT CALORIE × INCOME FOUR-WAY MODEL: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        j_h_ann ///
        j_k_ann ///
        j_i_ann ///
        j_hk_ann ///
        j_hi_ann ///
        j_ki_ann ///
        j_hki_ann ///
        j_h_impl ///
        j_k_impl ///
        j_i_impl ///
        j_hk_impl ///
        j_hi_impl ///
        j_ki_impl ///
        j_hki_impl ///
        if sample_joint_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo JOINT_MAIN_`y'


    * Highest-order implementation heterogeneity.
    test j_hki_impl

    scalar joint_impl_b_`y' = _b[j_hki_impl]
    scalar joint_impl_p_`y' = r(p)


    * Highest-order announcement heterogeneity.
    test j_hki_ann

    scalar joint_ann_b_`y' = _b[j_hki_ann]
    scalar joint_ann_p_`y' = r(p)


    * Announcement vs implementation highest-order interaction.
    test j_hki_impl = j_hki_ann

    scalar joint_impl_vs_ann_p_`y' = r(p)


    * Total Hunan implementation effect for LOW-KCAL & LOW-INCOME group.
    lincom ///
        j_h_impl ///
        + j_hk_impl ///
        + j_hi_impl ///
        + j_hki_impl

    scalar joint_lowboth_impl_b_`y'  = r(estimate)
    scalar joint_lowboth_impl_se_`y' = r(se)
    scalar joint_lowboth_impl_p_`y'  = r(p)


    estimates save ///
        "$P2_MODELS/04_joint_calorie_income_`y'.ster", ///
        replace
}


esttab ///
    JOINT_MAIN_kcal ///
    JOINT_MAIN_carbo ///
    JOINT_MAIN_fat ///
    JOINT_MAIN_protn ///
    using "$P2_TABLES/04_joint_calorie_income_main.rtf", ///
    replace ///
    keep( ///
        j_hk_ann ///
        j_hi_ann ///
        j_hki_ann ///
        j_hk_impl ///
        j_hi_impl ///
        j_hki_impl ///
    ) ///
    order( ///
        j_hk_ann ///
        j_hi_ann ///
        j_hki_ann ///
        j_hk_impl ///
        j_hi_impl ///
        j_hki_impl ///
    ) ///
    coeflabels( ///
        j_hk_ann ///
            "Hunan x Low kcal x Announcement 2004" ///
        j_hi_ann ///
            "Hunan x Low income x Announcement 2004" ///
        j_hki_ann ///
            "Hunan x Low kcal x Low income x Announcement 2004" ///
        j_hk_impl ///
            "Hunan x Low kcal x Implementation period" ///
        j_hi_impl ///
            "Hunan x Low income x Implementation period" ///
        j_hki_impl ///
            "Hunan x Low kcal x Low income x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Joint baseline calorie and income heterogeneity") ///
    addnotes( ///
        "Highest-order coefficient is a four-way interaction", ///
        "Strict sample requires both 1997 and 2000 calorie and income observations", ///
        "2004 is treated separately as the announcement wave", ///
        "Implementation period: 2006, 2009, and 2011", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 11. DYNAMIC JOINT CALORIE × INCOME HETEROGENEITY
*
* Fully saturated by wave.
* 2000 is omitted/reference year.
*
* q97/q04/q06/q09/q11 are the highest-order terms:
*   Hunan × Low calorie × Low income × Year
*===============================================================================

foreach v in ///
    jh97 jh04 jh06 jh09 jh11 ///
    jk97 jk04 jk06 jk09 jk11 ///
    ji97 ji04 ji06 ji09 ji11 ///
    jhk97 jhk04 jhk06 jhk09 jhk11 ///
    jhi97 jhi04 jhi06 jhi09 jhi11 ///
    jki97 jki04 jki06 jki09 jki11 ///
    jq97 jq04 jq06 jq09 jq11 {

    capture drop `v'
}


* Hunan x wave.
gen byte jh97 = inc_treated_hg * (wave == 1997) if sample_joint_pre2 == 1
gen byte jh04 = inc_treated_hg * (wave == 2004) if sample_joint_pre2 == 1
gen byte jh06 = inc_treated_hg * (wave == 2006) if sample_joint_pre2 == 1
gen byte jh09 = inc_treated_hg * (wave == 2009) if sample_joint_pre2 == 1
gen byte jh11 = inc_treated_hg * (wave == 2011) if sample_joint_pre2 == 1


* Low calorie x wave.
gen byte jk97 = lowKCAL_i_q25 * (wave == 1997) if sample_joint_pre2 == 1
gen byte jk04 = lowKCAL_i_q25 * (wave == 2004) if sample_joint_pre2 == 1
gen byte jk06 = lowKCAL_i_q25 * (wave == 2006) if sample_joint_pre2 == 1
gen byte jk09 = lowKCAL_i_q25 * (wave == 2009) if sample_joint_pre2 == 1
gen byte jk11 = lowKCAL_i_q25 * (wave == 2011) if sample_joint_pre2 == 1


* Low income x wave.
gen byte ji97 = lowINC_i_q25 * (wave == 1997) if sample_joint_pre2 == 1
gen byte ji04 = lowINC_i_q25 * (wave == 2004) if sample_joint_pre2 == 1
gen byte ji06 = lowINC_i_q25 * (wave == 2006) if sample_joint_pre2 == 1
gen byte ji09 = lowINC_i_q25 * (wave == 2009) if sample_joint_pre2 == 1
gen byte ji11 = lowINC_i_q25 * (wave == 2011) if sample_joint_pre2 == 1


* Hunan x Low calorie x wave.
gen byte jhk97 = inc_treated_hg * lowKCAL_i_q25 * (wave == 1997) if sample_joint_pre2 == 1
gen byte jhk04 = inc_treated_hg * lowKCAL_i_q25 * (wave == 2004) if sample_joint_pre2 == 1
gen byte jhk06 = inc_treated_hg * lowKCAL_i_q25 * (wave == 2006) if sample_joint_pre2 == 1
gen byte jhk09 = inc_treated_hg * lowKCAL_i_q25 * (wave == 2009) if sample_joint_pre2 == 1
gen byte jhk11 = inc_treated_hg * lowKCAL_i_q25 * (wave == 2011) if sample_joint_pre2 == 1


* Hunan x Low income x wave.
gen byte jhi97 = inc_treated_hg * lowINC_i_q25 * (wave == 1997) if sample_joint_pre2 == 1
gen byte jhi04 = inc_treated_hg * lowINC_i_q25 * (wave == 2004) if sample_joint_pre2 == 1
gen byte jhi06 = inc_treated_hg * lowINC_i_q25 * (wave == 2006) if sample_joint_pre2 == 1
gen byte jhi09 = inc_treated_hg * lowINC_i_q25 * (wave == 2009) if sample_joint_pre2 == 1
gen byte jhi11 = inc_treated_hg * lowINC_i_q25 * (wave == 2011) if sample_joint_pre2 == 1


* Low calorie x Low income x wave.
gen byte jki97 = lowKCAL_i_q25 * lowINC_i_q25 * (wave == 1997) if sample_joint_pre2 == 1
gen byte jki04 = lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2004) if sample_joint_pre2 == 1
gen byte jki06 = lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2006) if sample_joint_pre2 == 1
gen byte jki09 = lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2009) if sample_joint_pre2 == 1
gen byte jki11 = lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2011) if sample_joint_pre2 == 1


* Highest-order: Hunan x Low calorie x Low income x wave.
gen byte jq97 = inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * (wave == 1997) ///
    if sample_joint_pre2 == 1

gen byte jq04 = inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2004) ///
    if sample_joint_pre2 == 1

gen byte jq06 = inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2006) ///
    if sample_joint_pre2 == 1

gen byte jq09 = inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2009) ///
    if sample_joint_pre2 == 1

gen byte jq11 = inc_treated_hg * lowKCAL_i_q25 * lowINC_i_q25 * (wave == 2011) ///
    if sample_joint_pre2 == 1


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "DYNAMIC JOINT CALORIE × INCOME MODEL: `y'"
    display as text "Reference year = 2000"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        jh97 jh04 jh06 jh09 jh11 ///
        jk97 jk04 jk06 jk09 jk11 ///
        ji97 ji04 ji06 ji09 ji11 ///
        jhk97 jhk04 jhk06 jhk09 jhk11 ///
        jhi97 jhi04 jhi06 jhi09 jhi11 ///
        jki97 jki04 jki06 jki09 jki11 ///
        jq97 jq04 jq06 jq09 jq11 ///
        if sample_joint_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo JOINT_ES_`y'


    * Highest-order pretrend diagnostic.
    test jq97

    scalar joint_pre_b_`y' = _b[jq97]
    scalar joint_pre_p_`y' = r(p)


    * Highest-order announcement effect.
    test jq04

    scalar joint_dyn04_b_`y' = _b[jq04]
    scalar joint_dyn04_p_`y' = r(p)


    * Joint test of post-implementation highest-order interactions.
    test jq06 jq09 jq11

    scalar joint_postjoint_p_`y' = r(p)


    display as text ///
        "Highest-order 1997 pretrend p-value = " ///
        %9.4f scalar(joint_pre_p_`y')

    display as text ///
        "Joint highest-order 2006/09/11 p-value = " ///
        %9.4f scalar(joint_postjoint_p_`y')


    estimates save ///
        "$P2_MODELS/04_joint_calorie_income_event_`y'.ster", ///
        replace
}


esttab ///
    JOINT_ES_kcal ///
    JOINT_ES_carbo ///
    JOINT_ES_fat ///
    JOINT_ES_protn ///
    using "$P2_TABLES/04_joint_calorie_income_dynamic.rtf", ///
    replace ///
    keep( ///
        jq97 ///
        jq04 ///
        jq06 ///
        jq09 ///
        jq11 ///
    ) ///
    order( ///
        jq97 ///
        jq04 ///
        jq06 ///
        jq09 ///
        jq11 ///
    ) ///
    coeflabels( ///
        jq97 "1997 x Hunan x Low kcal x Low income" ///
        jq04 "2004 x Hunan x Low kcal x Low income" ///
        jq06 "2006 x Hunan x Low kcal x Low income" ///
        jq09 "2009 x Hunan x Low kcal x Low income" ///
        jq11 "2011 x Hunan x Low kcal x Low income" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Dynamic joint calorie and income heterogeneity") ///
    addnotes( ///
        "Highest-order terms are four-way interactions", ///
        "Reference year: 2000", ///
        "1997 highest-order interaction is the pretrend diagnostic", ///
        "2004 is the announcement wave", ///
        "2006, 2009, and 2011 are post-implementation observations", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 12. COMPACT RESULTS SUMMARY
*===============================================================================

display as text ""
display as text "=========================================================================="
display as text "04 INCOME / JOINT HETEROGENEITY SUMMARY"
display as text "=========================================================================="

foreach y of local outcomes {

    display as text ""
    display as text "OUTCOME: `y'"
    display as text "--------------------------------------------------------------------------"

    display as text ///
        "INCOME MAIN: 1997 pretrend DDD   = " ///
        %8.4f scalar(inc_pre_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_pre_p_`y')

    display as text ///
        "INCOME MAIN: Announcement DDD    = " ///
        %8.4f scalar(inc_main_ann_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_main_ann_p_`y')

    display as text ///
        "INCOME MAIN: Implementation DDD  = " ///
        %8.4f scalar(inc_main_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_main_impl_p_`y')

    display as text ///
        "INCOME MAIN: Low-group total DID = " ///
        %8.4f scalar(inc_low_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_low_impl_p_`y')

    display as text ///
        "INCOME MAIN: Impl = Ann test p   = " ///
        %7.4f scalar(inc_impl_vs_ann_p_`y')

    display as text ///
        "INCOME MAIN: Joint post test p   = " ///
        %7.4f scalar(inc_postjoint_p_`y')

    display as text ///
        "ROBUST ALL-BASELINE: Impl DDD    = " ///
        %8.4f scalar(inc_all_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_all_impl_p_`y')

    display as text ///
        "ROBUST CONTROLS: Impl DDD        = " ///
        %8.4f scalar(inc_ctrl_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(inc_ctrl_impl_p_`y')

    display as text ///
        "JOINT: 1997 highest-order pretrend = " ///
        %8.4f scalar(joint_pre_b_`y') ///
        "   p = " ///
        %7.4f scalar(joint_pre_p_`y')

    display as text ///
        "JOINT: Announcement four-way     = " ///
        %8.4f scalar(joint_ann_b_`y') ///
        "   p = " ///
        %7.4f scalar(joint_ann_p_`y')

    display as text ///
        "JOINT: Implementation four-way   = " ///
        %8.4f scalar(joint_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(joint_impl_p_`y')

    display as text ///
        "JOINT: Low-kcal + low-inc total  = " ///
        %8.4f scalar(joint_lowboth_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(joint_lowboth_impl_p_`y')

    display as text ///
        "JOINT: Joint post four-way p     = " ///
        %7.4f scalar(joint_postjoint_p_`y')

    display as text "--------------------------------------------------------------------------"
}


display as text "=========================================================================="
display as text "END OF 04 INCOME / JOINT HETEROGENEITY ANALYSIS"
display as text "=========================================================================="


*===============================================================================
* INTERPRETATION NOTES
*
* 1. The preferred income specification uses individuals whose baseline income
*    is observed in BOTH 1997 and 2000.
*
* 2. 2004 is estimated separately as the announcement wave. The pooled
*    implementation period contains 2006, 2009, and 2011.
*
* 3. Main specifications use individual FE + wave FE and no contemporaneous
*    controls.
*
* 4. The income DDD coefficient answers whether the Hunan treatment response is
*    different for initially low-income individuals.
*
* 5. The joint calorie × income model uses CURRENT individual baseline groups.
*    It does not use the old household lowS1_q25 definition.
*
* 6. The highest-order calorie × income term is a FOUR-WAY interaction, not a
*    simple DDD. Interpret it as additional treatment-response heterogeneity
*    among people who are jointly low-calorie and low-income, beyond the
*    lower-order heterogeneity components.
*
* 7. With only one clean pre-treatment lead (1997 relative to 2000), pretrend
*    tests are limited diagnostics rather than proof of parallel trends.
*
* 8. Do not select preferred specifications based on statistical significance.
*===============================================================================
