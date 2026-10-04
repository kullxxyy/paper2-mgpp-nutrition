*===============================================================================
* PAPER 2 — ROBUSTNESS CHECKS
* File: analyses/07_robustness.do
*
* CURRENT STANDARD
*
* Purpose:
*   Check whether the main baseline-calorie heterogeneity results depend on:
*
*   A. Using a discrete bottom-quartile cutoff
*   B. Using the preferred specification without contemporaneous controls
*
* Robustness specifications retained:
*   1. Continuous individual baseline-calorie constraint
*   2. Median split of individual baseline calories
*   3. Preferred individual bottom-quartile DDD with controls
*
* Specifications intentionally removed:
*   - low_q4 / low_q5 / low_q6 / low_q10 cutoff searching
*   - group3 ad hoc categories
*   - ever_farmer / later-entry subgroup regressions
*   - never-entering household restrictions
*   - contemporaneous low-income groups
*   - contemporaneous calorie groups
*
* Sample:
*   Hunan vs Guizhou pure consumers
*
* Baseline nutrition:
*   Individual mean calorie intake in 1997 and 2000
*   Preferred robustness sample requires BOTH pre-policy observations
*
* Policy timing:
*   2004 = announcement wave
*   2005 = implementation in Hunan
*   2006/2009/2011 = observed post-implementation waves
*   2000 = omitted/reference year in dynamic specifications
*
* Estimation:
*   Individual FE + wave FE
*   SE clustered at community level
*
* IMPORTANT:
*   Robustness checks are not used to search for statistically significant
*   cutoffs. Their purpose is to assess sensitivity to reasonable alternative
*   definitions.
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED PACKAGES
*===============================================================================

local outcomes kcal carbo fat protn

* Controls used ONLY in robustness section C.
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


* Preferred cluster variable.
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
* 1. HUNAN-GUIZHOU PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in ///
    rb_sample_hg ///
    rb_treated_hg ///
    rb_sample_pc {

    capture drop `v'
}


capture confirm variable t1

if !_rc {

    gen byte rb_sample_hg = ///
        inlist(t1, 43, 52)

    gen byte rb_treated_hg = ///
        (t1 == 43) ///
        if rb_sample_hg == 1
}

else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists."
        exit 111
    }

    gen byte rb_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte rb_treated_hg = ///
        (province_code == 43) ///
        if rb_sample_hg == 1
}


capture confirm variable consumer_base

if _rc {
    display as error ///
        "consumer_base not found. Run pure-consumer preparation first."
    exit 111
}


gen byte rb_sample_pc = ///
    rb_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


display as text "============================================================"
display as text "07 ROBUSTNESS — HUNAN-GUIZHOU PURE-CONSUMER SAMPLE"
display as text "============================================================"

tab rb_treated_hg ///
    if rb_sample_pc == 1, ///
    missing

tab wave ///
    if rb_sample_pc == 1, ///
    missing


*===============================================================================
* 2. CONSTRUCT CURRENT INDIVIDUAL BASELINE-CALORIE MEASURES
*
* Baseline = 1997 and 2000 only.
*
* rb_pre_kcal_i:
*   individual mean baseline calories
*
* rb_kcal_constraint:
*   negative standardized baseline calories
*   higher value = lower baseline calories / more constrained
*
* rb_low_q25:
*   bottom quartile of individual baseline calories
*
* rb_low_median:
*   below-median individual baseline calories
*===============================================================================

foreach v in ///
    rb_pre97 ///
    rb_pre00 ///
    rb_pre_kcal_i ///
    rb_pre_n ///
    rb_pre_std ///
    rb_kcal_constraint ///
    rb_q4 ///
    rb_low_q25 ///
    rb_median_cut ///
    rb_low_median {

    capture drop `v'
}


capture confirm variable d3kcal

if _rc {
    display as error ///
        "d3kcal not found."
    exit 111
}


bysort IDind: egen double rb_pre97 = max( ///
    cond( ///
        wave == 1997 ///
        & rb_sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen double rb_pre00 = max( ///
    cond( ///
        wave == 2000 ///
        & rb_sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


egen double rb_pre_kcal_i = rowmean( ///
    rb_pre97 ///
    rb_pre00 ///
)


gen byte rb_pre_n = ///
    !missing(rb_pre97) ///
    + !missing(rb_pre00)


* Create baseline groups on ONE observation per individual.
preserve

keep if ///
    rb_sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(rb_pre_kcal_i)

keep IDind rb_pre_kcal_i rb_pre_n

bysort IDind: keep if _n == 1

isid IDind


egen double rb_pre_std = std(rb_pre_kcal_i)

xtile rb_q4 = rb_pre_kcal_i, nq(4)

summarize rb_pre_kcal_i, detail

scalar RB_MEDIAN_KCAL = r(p50)


gen byte rb_low_q25 = ///
    (rb_q4 == 1) ///
    if !missing(rb_q4)


gen byte rb_low_median = ///
    (rb_pre_kcal_i <= scalar(RB_MEDIAN_KCAL)) ///
    if !missing(rb_pre_kcal_i)


keep ///
    IDind ///
    rb_pre_std ///
    rb_q4 ///
    rb_low_q25 ///
    rb_low_median

tempfile rb_groups
save `rb_groups'

restore


merge m:1 IDind ///
    using `rb_groups', ///
    nogen ///
    keep(master match)


gen double rb_kcal_constraint = ///
    -rb_pre_std ///
    if !missing(rb_pre_std)


label variable rb_kcal_constraint ///
    "Baseline calorie constraint: higher = lower baseline kcal"

label variable rb_low_q25 ///
    "Individual baseline calories: bottom 25%"

label variable rb_low_median ///
    "Individual baseline calories: below median"


*===============================================================================
* 3. PREFERRED ROBUSTNESS SAMPLE
*
* Require baseline calories observed in BOTH 1997 and 2000.
*===============================================================================

capture drop rb_sample_pre2

gen byte rb_sample_pre2 = ///
    rb_sample_pc == 1 ///
    & rb_pre_n == 2 ///
    & !missing(rb_kcal_constraint) ///
    & !missing(rb_low_q25) ///
    & !missing(rb_low_median)


capture drop __rb_tag

egen byte __rb_tag = tag(IDind) ///
    if rb_sample_pre2 == 1


display as text "============================================================"
display as text "ROBUSTNESS TWO-PRE-WAVE SAMPLE"
display as text "============================================================"

count if __rb_tag == 1

display as text ///
    "Number of individuals = " ///
    r(N)

tab rb_low_q25 rb_treated_hg ///
    if __rb_tag == 1, ///
    column

tab rb_low_median rb_treated_hg ///
    if __rb_tag == 1, ///
    column

drop __rb_tag


*===============================================================================
* 4. POLICY PERIOD VARIABLES
*
* 2004 = announcement
* 2006+ = implementation period
*===============================================================================

foreach v in ///
    rb_ann ///
    rb_impl ///
    rb_h_ann ///
    rb_h_impl {

    capture drop `v'
}


gen byte rb_ann = ///
    (wave == 2004)

gen byte rb_impl = ///
    (wave >= 2006)


gen byte rb_h_ann = ///
    rb_treated_hg * rb_ann ///
    if rb_sample_pre2 == 1

gen byte rb_h_impl = ///
    rb_treated_hg * rb_impl ///
    if rb_sample_pre2 == 1


*===============================================================================
* 5. ROBUSTNESS A — CONTINUOUS BASELINE-CALORIE CONSTRAINT
*
* Main question:
*   Does treatment response vary smoothly with baseline calorie constraint,
*   rather than depending on an arbitrary q25 cutoff?
*
* Positive DDD:
*   stronger treatment response among people with lower baseline calories.
*===============================================================================

foreach v in ///
    rb_c_ann ///
    rb_c_impl ///
    rb_ddd_c_ann ///
    rb_ddd_c_impl {

    capture drop `v'
}


gen double rb_c_ann = ///
    rb_kcal_constraint * rb_ann ///
    if rb_sample_pre2 == 1

gen double rb_c_impl = ///
    rb_kcal_constraint * rb_impl ///
    if rb_sample_pre2 == 1


gen double rb_ddd_c_ann = ///
    rb_treated_hg * rb_kcal_constraint * rb_ann ///
    if rb_sample_pre2 == 1

gen double rb_ddd_c_impl = ///
    rb_treated_hg * rb_kcal_constraint * rb_impl ///
    if rb_sample_pre2 == 1


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "CONTINUOUS CALORIE ROBUSTNESS: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        rb_h_ann ///
        rb_c_ann ///
        rb_ddd_c_ann ///
        rb_h_impl ///
        rb_c_impl ///
        rb_ddd_c_impl ///
        if rb_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo RB_CONT_`y'


    test rb_ddd_c_impl

    scalar rb_cont_impl_b_`y' = _b[rb_ddd_c_impl]
    scalar rb_cont_impl_p_`y' = r(p)


    test rb_ddd_c_ann

    scalar rb_cont_ann_b_`y' = _b[rb_ddd_c_ann]
    scalar rb_cont_ann_p_`y' = r(p)


    test rb_ddd_c_impl = rb_ddd_c_ann

    scalar rb_cont_diff_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/07_continuous_`y'.ster", ///
        replace
}


esttab ///
    RB_CONT_kcal ///
    RB_CONT_carbo ///
    RB_CONT_fat ///
    RB_CONT_protn ///
    using "$P2_TABLES/07_robust_continuous_kcal.rtf", ///
    replace ///
    keep( ///
        rb_ddd_c_ann ///
        rb_ddd_c_impl ///
    ) ///
    order( ///
        rb_ddd_c_ann ///
        rb_ddd_c_impl ///
    ) ///
    coeflabels( ///
        rb_ddd_c_ann ///
            "Hunan x Calorie constraint x Announcement 2004" ///
        rb_ddd_c_impl ///
            "Hunan x Calorie constraint x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness: continuous baseline-calorie constraint") ///
    addnotes( ///
        "Higher constraint index = lower baseline calories", ///
        "Baseline calories observed in both 1997 and 2000", ///
        "2004 is estimated separately as the announcement wave", ///
        "Implementation period: 2006, 2009, and 2011", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 5B. Dynamic continuous heterogeneity
*-------------------------------------------------------------------------------

foreach v in ///
    rb_h97 rb_h04 rb_h06 rb_h09 rb_h11 ///
    rb_c97 rb_c04 rb_c06 rb_c09 rb_c11 ///
    rb_dc97 rb_dc04 rb_dc06 rb_dc09 rb_dc11 {

    capture drop `v'
}


* Hunan x wave.
gen byte rb_h97 = rb_treated_hg * (wave == 1997) ///
    if rb_sample_pre2 == 1

gen byte rb_h04 = rb_treated_hg * (wave == 2004) ///
    if rb_sample_pre2 == 1

gen byte rb_h06 = rb_treated_hg * (wave == 2006) ///
    if rb_sample_pre2 == 1

gen byte rb_h09 = rb_treated_hg * (wave == 2009) ///
    if rb_sample_pre2 == 1

gen byte rb_h11 = rb_treated_hg * (wave == 2011) ///
    if rb_sample_pre2 == 1


* Constraint x wave.
gen double rb_c97 = rb_kcal_constraint * (wave == 1997) ///
    if rb_sample_pre2 == 1

gen double rb_c04 = rb_kcal_constraint * (wave == 2004) ///
    if rb_sample_pre2 == 1

gen double rb_c06 = rb_kcal_constraint * (wave == 2006) ///
    if rb_sample_pre2 == 1

gen double rb_c09 = rb_kcal_constraint * (wave == 2009) ///
    if rb_sample_pre2 == 1

gen double rb_c11 = rb_kcal_constraint * (wave == 2011) ///
    if rb_sample_pre2 == 1


* Hunan x Constraint x wave.
gen double rb_dc97 = ///
    rb_treated_hg * rb_kcal_constraint * (wave == 1997) ///
    if rb_sample_pre2 == 1

gen double rb_dc04 = ///
    rb_treated_hg * rb_kcal_constraint * (wave == 2004) ///
    if rb_sample_pre2 == 1

gen double rb_dc06 = ///
    rb_treated_hg * rb_kcal_constraint * (wave == 2006) ///
    if rb_sample_pre2 == 1

gen double rb_dc09 = ///
    rb_treated_hg * rb_kcal_constraint * (wave == 2009) ///
    if rb_sample_pre2 == 1

gen double rb_dc11 = ///
    rb_treated_hg * rb_kcal_constraint * (wave == 2011) ///
    if rb_sample_pre2 == 1


eststo clear

foreach y of local outcomes {

    reghdfe lnd3`y' ///
        rb_h97 rb_h04 rb_h06 rb_h09 rb_h11 ///
        rb_c97 rb_c04 rb_c06 rb_c09 rb_c11 ///
        rb_dc97 rb_dc04 rb_dc06 rb_dc09 rb_dc11 ///
        if rb_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo RB_CONT_ES_`y'


    test rb_dc97

    scalar rb_cont_pre_b_`y' = _b[rb_dc97]
    scalar rb_cont_pre_p_`y' = r(p)


    test rb_dc06 rb_dc09 rb_dc11

    scalar rb_cont_post_p_`y' = r(p)
}


esttab ///
    RB_CONT_ES_kcal ///
    RB_CONT_ES_carbo ///
    RB_CONT_ES_fat ///
    RB_CONT_ES_protn ///
    using "$P2_TABLES/07_robust_continuous_dynamic.rtf", ///
    replace ///
    keep( ///
        rb_dc97 ///
        rb_dc04 ///
        rb_dc06 ///
        rb_dc09 ///
        rb_dc11 ///
    ) ///
    order( ///
        rb_dc97 ///
        rb_dc04 ///
        rb_dc06 ///
        rb_dc09 ///
        rb_dc11 ///
    ) ///
    coeflabels( ///
        rb_dc97 "1997 x Hunan x Calorie constraint" ///
        rb_dc04 "2004 x Hunan x Calorie constraint" ///
        rb_dc06 "2006 x Hunan x Calorie constraint" ///
        rb_dc09 "2009 x Hunan x Calorie constraint" ///
        rb_dc11 "2011 x Hunan x Calorie constraint" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Dynamic robustness: continuous calorie constraint") ///
    addnotes( ///
        "Reference year: 2000", ///
        "1997 triple interaction is the differential pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 6. ROBUSTNESS B — MEDIAN SPLIT
*
* Purpose:
*   Check whether the main q25 result survives a broader definition of
*   nutritionally constrained individuals.
*
* This is ONE prespecified alternative cutoff, not a search across cutoffs.
*===============================================================================

foreach v in ///
    rb_m_ann ///
    rb_m_impl ///
    rb_ddd_m_ann ///
    rb_ddd_m_impl {

    capture drop `v'
}


gen byte rb_m_ann = ///
    rb_low_median * rb_ann ///
    if rb_sample_pre2 == 1

gen byte rb_m_impl = ///
    rb_low_median * rb_impl ///
    if rb_sample_pre2 == 1


gen byte rb_ddd_m_ann = ///
    rb_treated_hg * rb_low_median * rb_ann ///
    if rb_sample_pre2 == 1

gen byte rb_ddd_m_impl = ///
    rb_treated_hg * rb_low_median * rb_impl ///
    if rb_sample_pre2 == 1


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "MEDIAN-SPLIT ROBUSTNESS: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        rb_h_ann ///
        rb_m_ann ///
        rb_ddd_m_ann ///
        rb_h_impl ///
        rb_m_impl ///
        rb_ddd_m_impl ///
        if rb_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo RB_MED_`y'


    test rb_ddd_m_impl

    scalar rb_med_impl_b_`y' = _b[rb_ddd_m_impl]
    scalar rb_med_impl_p_`y' = r(p)


    lincom rb_h_impl + rb_ddd_m_impl

    scalar rb_med_low_b_`y' = r(estimate)
    scalar rb_med_low_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/07_median_`y'.ster", ///
        replace
}


esttab ///
    RB_MED_kcal ///
    RB_MED_carbo ///
    RB_MED_fat ///
    RB_MED_protn ///
    using "$P2_TABLES/07_robust_median_split.rtf", ///
    replace ///
    keep( ///
        rb_ddd_m_ann ///
        rb_ddd_m_impl ///
    ) ///
    order( ///
        rb_ddd_m_ann ///
        rb_ddd_m_impl ///
    ) ///
    coeflabels( ///
        rb_ddd_m_ann ///
            "Hunan x Below-median kcal x Announcement 2004" ///
        rb_ddd_m_impl ///
            "Hunan x Below-median kcal x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness: below-median baseline calories") ///
    addnotes( ///
        "Baseline calories are individual mean calories in 1997 and 2000", ///
        "Sample requires both pre-policy calorie observations", ///
        "Median split is a prespecified alternative to the q25 definition", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 6B. Dynamic median-split DDD
*-------------------------------------------------------------------------------

foreach v in ///
    rb_m97 rb_m04 rb_m06 rb_m09 rb_m11 ///
    rb_dm97 rb_dm04 rb_dm06 rb_dm09 rb_dm11 {

    capture drop `v'
}


gen byte rb_m97 = rb_low_median * (wave == 1997) ///
    if rb_sample_pre2 == 1

gen byte rb_m04 = rb_low_median * (wave == 2004) ///
    if rb_sample_pre2 == 1

gen byte rb_m06 = rb_low_median * (wave == 2006) ///
    if rb_sample_pre2 == 1

gen byte rb_m09 = rb_low_median * (wave == 2009) ///
    if rb_sample_pre2 == 1

gen byte rb_m11 = rb_low_median * (wave == 2011) ///
    if rb_sample_pre2 == 1


gen byte rb_dm97 = ///
    rb_treated_hg * rb_low_median * (wave == 1997) ///
    if rb_sample_pre2 == 1

gen byte rb_dm04 = ///
    rb_treated_hg * rb_low_median * (wave == 2004) ///
    if rb_sample_pre2 == 1

gen byte rb_dm06 = ///
    rb_treated_hg * rb_low_median * (wave == 2006) ///
    if rb_sample_pre2 == 1

gen byte rb_dm09 = ///
    rb_treated_hg * rb_low_median * (wave == 2009) ///
    if rb_sample_pre2 == 1

gen byte rb_dm11 = ///
    rb_treated_hg * rb_low_median * (wave == 2011) ///
    if rb_sample_pre2 == 1


eststo clear

foreach y of local outcomes {

    reghdfe lnd3`y' ///
        rb_h97 rb_h04 rb_h06 rb_h09 rb_h11 ///
        rb_m97 rb_m04 rb_m06 rb_m09 rb_m11 ///
        rb_dm97 rb_dm04 rb_dm06 rb_dm09 rb_dm11 ///
        if rb_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo RB_MED_ES_`y'


    test rb_dm97

    scalar rb_med_pre_b_`y' = _b[rb_dm97]
    scalar rb_med_pre_p_`y' = r(p)


    test rb_dm06 rb_dm09 rb_dm11

    scalar rb_med_post_p_`y' = r(p)
}


esttab ///
    RB_MED_ES_kcal ///
    RB_MED_ES_carbo ///
    RB_MED_ES_fat ///
    RB_MED_ES_protn ///
    using "$P2_TABLES/07_robust_median_dynamic.rtf", ///
    replace ///
    keep( ///
        rb_dm97 ///
        rb_dm04 ///
        rb_dm06 ///
        rb_dm09 ///
        rb_dm11 ///
    ) ///
    order( ///
        rb_dm97 ///
        rb_dm04 ///
        rb_dm06 ///
        rb_dm09 ///
        rb_dm11 ///
    ) ///
    coeflabels( ///
        rb_dm97 "1997 x Hunan x Below-median kcal" ///
        rb_dm04 "2004 x Hunan x Below-median kcal" ///
        rb_dm06 "2006 x Hunan x Below-median kcal" ///
        rb_dm09 "2009 x Hunan x Below-median kcal" ///
        rb_dm11 "2011 x Hunan x Below-median kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Dynamic robustness: below-median baseline calories") ///
    addnotes( ///
        "Reference year: 2000", ///
        "1997 triple interaction is the differential pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 7. ROBUSTNESS C — PREFERRED Q25 DDD WITH CONTEMPORANEOUS CONTROLS
*
* Purpose:
*   Check whether the preferred q25 implementation DDD is sensitive to the
*   inclusion of standard time-varying controls.
*
* Current household income is NOT included because it may be affected by policy.
*===============================================================================

foreach v in ///
    rb_q_ann ///
    rb_q_impl ///
    rb_ddd_q_ann ///
    rb_ddd_q_impl {

    capture drop `v'
}


gen byte rb_q_ann = ///
    rb_low_q25 * rb_ann ///
    if rb_sample_pre2 == 1

gen byte rb_q_impl = ///
    rb_low_q25 * rb_impl ///
    if rb_sample_pre2 == 1


gen byte rb_ddd_q_ann = ///
    rb_treated_hg * rb_low_q25 * rb_ann ///
    if rb_sample_pre2 == 1

gen byte rb_ddd_q_impl = ///
    rb_treated_hg * rb_low_q25 * rb_impl ///
    if rb_sample_pre2 == 1


eststo clear

foreach y of local outcomes {

    display as text ""
    display as text "============================================================"
    display as text "Q25 + CONTROLS ROBUSTNESS: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        rb_h_ann ///
        rb_q_ann ///
        rb_ddd_q_ann ///
        rb_h_impl ///
        rb_q_impl ///
        rb_ddd_q_impl ///
        `RD1' ///
        if rb_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo RB_CTRL_`y'


    test rb_ddd_q_impl

    scalar rb_ctrl_impl_b_`y' = _b[rb_ddd_q_impl]
    scalar rb_ctrl_impl_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/07_q25_controls_`y'.ster", ///
        replace
}


esttab ///
    RB_CTRL_kcal ///
    RB_CTRL_carbo ///
    RB_CTRL_fat ///
    RB_CTRL_protn ///
    using "$P2_TABLES/07_robust_q25_controls.rtf", ///
    replace ///
    keep( ///
        rb_ddd_q_ann ///
        rb_ddd_q_impl ///
    ) ///
    order( ///
        rb_ddd_q_ann ///
        rb_ddd_q_impl ///
    ) ///
    coeflabels( ///
        rb_ddd_q_ann ///
            "Hunan x Low kcal x Announcement 2004" ///
        rb_ddd_q_impl ///
            "Hunan x Low kcal x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness: preferred q25 specification with controls") ///
    addnotes( ///
        "Low-kcal group = bottom quartile of individual baseline calories", ///
        "Baseline calories observed in both 1997 and 2000", ///
        "Current household income is not included as a control", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 8. COMPACT ROBUSTNESS SUMMARY
*===============================================================================

display as text ""
display as text "=========================================================================="
display as text "PAPER 2 ROBUSTNESS SUMMARY"
display as text "=========================================================================="

foreach y of local outcomes {

    display as text ""
    display as text "OUTCOME: `y'"
    display as text "--------------------------------------------------------------------------"

    display as text ///
        "CONTINUOUS: implementation DDD = " ///
        %8.4f scalar(rb_cont_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(rb_cont_impl_p_`y')

    display as text ///
        "CONTINUOUS: pretrend p          = " ///
        %7.4f scalar(rb_cont_pre_p_`y')

    display as text ///
        "CONTINUOUS: joint post p        = " ///
        %7.4f scalar(rb_cont_post_p_`y')

    display as text ///
        "MEDIAN: implementation DDD     = " ///
        %8.4f scalar(rb_med_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(rb_med_impl_p_`y')

    display as text ///
        "MEDIAN: low-group total effect = " ///
        %8.4f scalar(rb_med_low_b_`y') ///
        "   p = " ///
        %7.4f scalar(rb_med_low_p_`y')

    display as text ///
        "MEDIAN: pretrend p             = " ///
        %7.4f scalar(rb_med_pre_p_`y')

    display as text ///
        "MEDIAN: joint post p           = " ///
        %7.4f scalar(rb_med_post_p_`y')

    display as text ///
        "Q25 + CONTROLS: implementation DDD = " ///
        %8.4f scalar(rb_ctrl_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(rb_ctrl_impl_p_`y')

    display as text "--------------------------------------------------------------------------"
}


display as text "=========================================================================="
display as text "END OF 07 ROBUSTNESS CHECKS"
display as text "=========================================================================="


*===============================================================================
* INTERPRETATION NOTES
*
* 1. Continuous baseline-calorie heterogeneity asks whether the treatment
*    response changes smoothly with initial nutritional constraint.
*
* 2. The median split is the only alternative discrete cutoff retained.
*    It is used to show that conclusions do not rely exclusively on q25.
*
* 3. The preferred q25 specification with controls checks covariate sensitivity.
*
* 4. No q4/q5/q6/q10 search is performed.
*
* 5. No post-treatment subgroup such as ever_farmer or post_enter is used.
*
* 6. No contemporaneous income/calorie subgroup is used for causal heterogeneity.
*
* 7. With only one clean pre-treatment lead (1997 relative to 2000), pretrend
*    tests are limited diagnostics rather than proof of parallel trends.
*===============================================================================
