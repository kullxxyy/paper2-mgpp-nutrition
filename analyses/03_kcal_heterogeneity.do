*===============================================================================
* PAPER 2 — FINAL BASELINE-CALORIE HETEROGENEITY
* File: analyses/03_kcal_heterogeneity.do
*
* FINAL ORGANIZATION
*
* MAIN:
*   Individual baseline calorie status, bottom 25%.
*   Baseline kcal must be observed in BOTH 1997 and 2000.
*   The bottom-quartile cutoff is calculated ONLY among those two-pre-wave
*   individuals, using one record per individual.
*
* ROBUSTNESS A:
*   Continuous individual baseline-calorie constraint, using the SAME
*   two-pre-wave individuals.
*
* ROBUSTNESS B:
*   Existing household baseline-calorie bottom quartile
*   (lowS1_q25_fixed), if available.
*
* POLICY TIMING:
*   1997 = clean pre-policy diagnostic
*   2000 = omitted reference
*   2004 = announcement / transition wave, modeled separately
*   2006/2009/2011 = implementation-period observations
*
* ESTIMATION:
*   Individual FE + wave FE
*   Community-clustered standard errors
*   No contemporaneous controls in the preferred models
*
* IMPORTANT:
*   The preferred main group is defined ONCE and is used for all four outcomes.
*   It is NOT redefined outcome-by-outcome.
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED VARIABLES
*===============================================================================

local outcomes kcal carbo fat protn

foreach v in ///
    IDind hhid wave cluster_commid consumer_base ///
    d3kcal lnd3kcal lnd3carbo lnd3fat lnd3protn {

    capture confirm variable `v'

    if _rc {
        display as error "Required variable `v' not found."
        display as text  "Run main.do through prep/05_baseline_groups.do first."
        exit 111
    }
}

capture which reghdfe
if _rc {
    display as error "reghdfe is not installed."
    exit 199
}

capture which esttab
if _rc {
    display as error "esttab is not installed."
    exit 199
}


*===============================================================================
* 1. HUNAN / GUIZHOU ANALYSIS POPULATION
*===============================================================================

capture drop h3_sample_hg h3_treated_hg

capture confirm variable t1

if !_rc {

    gen byte h3_sample_hg = inlist(t1, 43, 52)

    gen byte h3_treated_hg = ///
        (t1 == 43) ///
        if h3_sample_hg == 1
}
else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists. Cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte h3_sample_hg = inlist(province_code, 43, 52)

    gen byte h3_treated_hg = ///
        (province_code == 43) ///
        if h3_sample_hg == 1
}

label define h3_hg ///
    0 "Guizhou" ///
    1 "Hunan", ///
    replace

label values h3_treated_hg h3_hg

label variable h3_sample_hg ///
    "Hunan-Guizhou analysis population"

label variable h3_treated_hg ///
    "Hunan treatment indicator"


*===============================================================================
* 2. PREFERRED BASELINE CALORIE GROUP
*
* Requirement:
*   - Hunan / Guizhou
*   - baseline pure-consumer proxy
*   - individual kcal observed in BOTH 1997 and 2000
*
* Cutoff:
*   - calculated only among the above two-pre-wave individuals
*   - one observation per individual
*===============================================================================

foreach v in ///
    h3_kcal97 ///
    h3_kcal00 ///
    h3_pre_kcal ///
    h3_pre_n ///
    h3_pre_std ///
    h3_constraint_std ///
    h3_qkcal ///
    h3_low_q25 ///
    h3_sample_main {

    capture drop `v'
}


bysort IDind: egen double h3_kcal97 = max( ///
    cond( ///
        wave == 1997 ///
        & h3_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen double h3_kcal00 = max( ///
    cond( ///
        wave == 2000 ///
        & h3_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


gen byte h3_pre_n = ///
    !missing(h3_kcal97) ///
    + !missing(h3_kcal00)


gen double h3_pre_kcal = ///
    (h3_kcal97 + h3_kcal00) / 2 ///
    if h3_pre_n == 2


preserve

    keep if ///
        h3_sample_hg == 1 ///
        & h3_pre_n == 2 ///
        & !missing(h3_pre_kcal)

    keep IDind h3_pre_kcal

    bysort IDind: keep if _n == 1

    isid IDind

    quietly count
    local N_pre2 = r(N)

    display as result ///
        "Two-pre-wave individuals used to define baseline kcal q25 = `N_pre2'"

    if `N_pre2' < 4 {
        display as error ///
            "ERROR: fewer than 4 individuals define the preferred q25 cutoff."
        restore
        exit 2001
    }

    if `N_pre2' < 20 {
        display as error ///
            "WARNING: fewer than 20 individuals define the preferred q25 cutoff."
    }

    xtile h3_qkcal = h3_pre_kcal, nq(4)

    egen double h3_pre_std = std(h3_pre_kcal)

    gen byte h3_low_q25 = ///
        (h3_qkcal == 1) ///
        if !missing(h3_qkcal)

    keep ///
        IDind ///
        h3_qkcal ///
        h3_low_q25 ///
        h3_pre_std

    tempfile h3_pre2_groups
    save `h3_pre2_groups', replace

restore


merge m:1 IDind using `h3_pre2_groups', ///
    nogen ///
    keep(master match)


gen double h3_constraint_std = ///
    -h3_pre_std ///
    if !missing(h3_pre_std)


* The individual enters the analysis because of PRE-POLICY qualification.
* Do not re-screen the person using post-policy consumer status.
gen byte h3_sample_main = ///
    h3_sample_hg == 1 ///
    & h3_pre_n == 2 ///
    & !missing(h3_low_q25)


label variable h3_pre_kcal ///
    "Mean individual calories in 1997 and 2000"

label variable h3_low_q25 ///
    "Bottom 25% individual baseline calories, two-pre-wave sample"

label variable h3_constraint_std ///
    "Baseline calorie constraint: higher = lower baseline kcal"

label variable h3_sample_main ///
    "Preferred two-pre-wave heterogeneity sample"


*===============================================================================
* 3. PREFERRED SAMPLE DIAGNOSTICS
*===============================================================================

display as text ""
display as result "============================================================"
display as result "PREFERRED TWO-PRE-WAVE HETEROGENEITY SAMPLE"
display as result "============================================================"

capture drop __h3_idtag
egen byte __h3_idtag = tag(IDind) ///
    if h3_sample_main == 1

quietly count if __h3_idtag == 1
display as result "Unique individuals = " r(N)

quietly count if h3_sample_main == 1
display as result "Person-wave observations = " r(N)

tab h3_low_q25 h3_treated_hg ///
    if __h3_idtag == 1, ///
    column

summarize h3_pre_kcal ///
    if __h3_idtag == 1, ///
    detail

drop __h3_idtag


* Verify preferred group is time-invariant.
capture drop __h3_qmin __h3_qmax

bysort IDind: egen byte __h3_qmin = min(h3_low_q25)
bysort IDind: egen byte __h3_qmax = max(h3_low_q25)

assert __h3_qmin == __h3_qmax ///
    if !missing(__h3_qmin, __h3_qmax)

drop __h3_qmin __h3_qmax


*===============================================================================
* 4. POLICY TIMING
*
* 2004 is modeled separately.
* Main implementation period = 2006 / 2009 / 2011.
*===============================================================================

foreach v in ///
    h3_ann2004 ///
    h3_post_impl ///
    h3_hann ///
    h3_lann ///
    h3_ddd_ann ///
    h3_himpl ///
    h3_limpl ///
    h3_ddd_impl {

    capture drop `v'
}


gen byte h3_ann2004 = ///
    (wave == 2004) ///
    if h3_sample_hg == 1


gen byte h3_post_impl = ///
    (wave >= 2006) ///
    if h3_sample_hg == 1


gen byte h3_hann = ///
    h3_treated_hg * h3_ann2004 ///
    if h3_sample_main == 1


gen byte h3_lann = ///
    h3_low_q25 * h3_ann2004 ///
    if h3_sample_main == 1


gen byte h3_ddd_ann = ///
    h3_treated_hg * h3_low_q25 * h3_ann2004 ///
    if h3_sample_main == 1


gen byte h3_himpl = ///
    h3_treated_hg * h3_post_impl ///
    if h3_sample_main == 1


gen byte h3_limpl = ///
    h3_low_q25 * h3_post_impl ///
    if h3_sample_main == 1


gen byte h3_ddd_impl = ///
    h3_treated_hg * h3_low_q25 * h3_post_impl ///
    if h3_sample_main == 1


label variable h3_hann ///
    "Hunan x Announcement 2004"

label variable h3_lann ///
    "Low baseline kcal x Announcement 2004"

label variable h3_ddd_ann ///
    "Hunan x Low kcal x Announcement 2004 (DDD)"

label variable h3_himpl ///
    "Hunan x Implementation period"

label variable h3_limpl ///
    "Low baseline kcal x Implementation period"

label variable h3_ddd_impl ///
    "Hunan x Low kcal x Implementation period (DDD)"


*===============================================================================
* 5. MAIN POOLED IMPLEMENTATION-PERIOD DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    display as text ""
    display as result "============================================================"
    display as result "MAIN IMPLEMENTATION-PERIOD DDD: `y'"
    display as result "============================================================"

    reghdfe lnd3`y' ///
        h3_hann ///
        h3_lann ///
        h3_ddd_ann ///
        h3_himpl ///
        h3_limpl ///
        h3_ddd_impl ///
        if h3_sample_main == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo H3_MAIN_IMPL_`y'


    test h3_ddd_impl

    scalar h3_impl_b_`y' = _b[h3_ddd_impl]
    scalar h3_impl_p_`y' = r(p)


    test h3_ddd_ann

    scalar h3_ann_b_`y' = _b[h3_ddd_ann]
    scalar h3_ann_p_`y' = r(p)


    * Total Hunan effect for low-kcal individuals during implementation.
    lincom h3_himpl + h3_ddd_impl

    scalar h3_low_impl_b_`y' = r(estimate)
    scalar h3_low_impl_p_`y' = r(p)


    * Compare announcement and implementation heterogeneity.
    test h3_ddd_impl = h3_ddd_ann

    scalar h3_impl_vs_ann_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/03_MAIN_IMPL_`y'.ster", ///
        replace
}


esttab ///
    H3_MAIN_IMPL_kcal ///
    H3_MAIN_IMPL_carbo ///
    H3_MAIN_IMPL_fat ///
    H3_MAIN_IMPL_protn ///
    using "$P2_TABLES/03_main_pre2_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        h3_hann ///
        h3_lann ///
        h3_ddd_ann ///
        h3_himpl ///
        h3_limpl ///
        h3_ddd_impl ///
    ) ///
    order( ///
        h3_hann ///
        h3_lann ///
        h3_ddd_ann ///
        h3_himpl ///
        h3_limpl ///
        h3_ddd_impl ///
    ) ///
    coeflabels( ///
        h3_hann ///
            "Hunan x Announcement 2004" ///
        h3_lann ///
            "Low baseline kcal x Announcement 2004" ///
        h3_ddd_ann ///
            "Hunan x Low kcal x Announcement 2004 (DDD)" ///
        h3_himpl ///
            "Hunan x Implementation period" ///
        h3_limpl ///
            "Low baseline kcal x Implementation period" ///
        h3_ddd_impl ///
            "Hunan x Low kcal x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: preferred two-pre-wave DDD" ///
    ) ///
    addnotes( ///
        "Preferred low-calorie group: bottom quartile of individual mean kcal in 1997/2000", ///
        "Both 1997 and 2000 kcal must be observed to define the group", ///
        "2004 is modeled separately as the announcement wave", ///
        "Implementation period: 2006, 2009, 2011", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 6. MAIN DYNAMIC DDD
*
* Reference year = 2000.
*
* Correct fully saturated dynamic DDD includes:
*   Hunan x Year
*   Low kcal x Year
*   Hunan x Low kcal x Year
*
* Main pretrend diagnostic:
*   1997 triple interaction = 0
*===============================================================================

foreach v in ///
    h3_h97 h3_h04 h3_h06 h3_h09 h3_h11 ///
    h3_l97 h3_l04 h3_l06 h3_l09 h3_l11 ///
    h3_d97 h3_d04 h3_d06 h3_d09 h3_d11 {

    capture drop `v'
}


gen byte h3_h97 = ///
    h3_treated_hg * (wave == 1997) ///
    if h3_sample_main == 1

gen byte h3_h04 = ///
    h3_treated_hg * (wave == 2004) ///
    if h3_sample_main == 1

gen byte h3_h06 = ///
    h3_treated_hg * (wave == 2006) ///
    if h3_sample_main == 1

gen byte h3_h09 = ///
    h3_treated_hg * (wave == 2009) ///
    if h3_sample_main == 1

gen byte h3_h11 = ///
    h3_treated_hg * (wave == 2011) ///
    if h3_sample_main == 1


gen byte h3_l97 = ///
    h3_low_q25 * (wave == 1997) ///
    if h3_sample_main == 1

gen byte h3_l04 = ///
    h3_low_q25 * (wave == 2004) ///
    if h3_sample_main == 1

gen byte h3_l06 = ///
    h3_low_q25 * (wave == 2006) ///
    if h3_sample_main == 1

gen byte h3_l09 = ///
    h3_low_q25 * (wave == 2009) ///
    if h3_sample_main == 1

gen byte h3_l11 = ///
    h3_low_q25 * (wave == 2011) ///
    if h3_sample_main == 1


gen byte h3_d97 = ///
    h3_treated_hg * h3_low_q25 * (wave == 1997) ///
    if h3_sample_main == 1

gen byte h3_d04 = ///
    h3_treated_hg * h3_low_q25 * (wave == 2004) ///
    if h3_sample_main == 1

gen byte h3_d06 = ///
    h3_treated_hg * h3_low_q25 * (wave == 2006) ///
    if h3_sample_main == 1

gen byte h3_d09 = ///
    h3_treated_hg * h3_low_q25 * (wave == 2009) ///
    if h3_sample_main == 1

gen byte h3_d11 = ///
    h3_treated_hg * h3_low_q25 * (wave == 2011) ///
    if h3_sample_main == 1


eststo clear


foreach y of local outcomes {

    display as text ""
    display as result "============================================================"
    display as result "MAIN DYNAMIC DDD: `y'"
    display as result "REFERENCE = 2000"
    display as result "============================================================"

    reghdfe lnd3`y' ///
        h3_h97 h3_h04 h3_h06 h3_h09 h3_h11 ///
        h3_l97 h3_l04 h3_l06 h3_l09 h3_l11 ///
        h3_d97 h3_d04 h3_d06 h3_d09 h3_d11 ///
        if h3_sample_main == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo H3_MAIN_ES_`y'


    * Differential pretrend: 1997 relative to 2000.
    test h3_d97

    scalar h3_pre_b_`y' = _b[h3_d97]
    scalar h3_pre_p_`y' = r(p)


    * Dynamic DDD coefficients.
    scalar h3_d04_b_`y' = _b[h3_d04]
    scalar h3_d06_b_`y' = _b[h3_d06]
    scalar h3_d09_b_`y' = _b[h3_d09]
    scalar h3_d11_b_`y' = _b[h3_d11]


    test h3_d04
    scalar h3_d04_p_`y' = r(p)

    test h3_d06
    scalar h3_d06_p_`y' = r(p)

    test h3_d09
    scalar h3_d09_p_`y' = r(p)

    test h3_d11
    scalar h3_d11_p_`y' = r(p)


    * Joint implementation-period heterogeneity test.
    test h3_d06 h3_d09 h3_d11

    scalar h3_joint_impl_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/03_MAIN_ES_`y'.ster", ///
        replace
}


esttab ///
    H3_MAIN_ES_kcal ///
    H3_MAIN_ES_carbo ///
    H3_MAIN_ES_fat ///
    H3_MAIN_ES_protn ///
    using "$P2_TABLES/03_main_pre2_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        h3_d97 ///
        h3_d04 ///
        h3_d06 ///
        h3_d09 ///
        h3_d11 ///
    ) ///
    order( ///
        h3_d97 ///
        h3_d04 ///
        h3_d06 ///
        h3_d09 ///
        h3_d11 ///
    ) ///
    coeflabels( ///
        h3_d97 ///
            "1997 x Hunan x Low baseline kcal" ///
        h3_d04 ///
            "2004 x Hunan x Low baseline kcal" ///
        h3_d06 ///
            "2006 x Hunan x Low baseline kcal" ///
        h3_d09 ///
            "2009 x Hunan x Low baseline kcal" ///
        h3_d11 ///
            "2011 x Hunan x Low baseline kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD by preferred baseline-calorie status" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "1997 triple interaction is the differential-pretrend diagnostic", ///
        "2004 is the announcement wave", ///
        "2006, 2009, and 2011 are implementation-period observations", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 7. ROBUSTNESS A — CONTINUOUS INDIVIDUAL BASELINE CALORIES
*
* Same preferred two-pre-wave individuals.
* Higher h3_constraint_std = lower baseline calorie intake.
*===============================================================================

foreach v in ///
    h3_cann ///
    h3_cdann ///
    h3_cimpl ///
    h3_cdimpl ///
    h3_c97 h3_c04 h3_c06 h3_c09 h3_c11 ///
    h3_cd97 h3_cd04 h3_cd06 h3_cd09 h3_cd11 {

    capture drop `v'
}


gen double h3_cann = ///
    h3_constraint_std * h3_ann2004 ///
    if h3_sample_main == 1


gen double h3_cdann = ///
    h3_treated_hg * h3_constraint_std * h3_ann2004 ///
    if h3_sample_main == 1


gen double h3_cimpl = ///
    h3_constraint_std * h3_post_impl ///
    if h3_sample_main == 1


gen double h3_cdimpl = ///
    h3_treated_hg * h3_constraint_std * h3_post_impl ///
    if h3_sample_main == 1


eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        h3_hann ///
        h3_cann ///
        h3_cdann ///
        h3_himpl ///
        h3_cimpl ///
        h3_cdimpl ///
        if h3_sample_main == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo H3_CONT_IMPL_`y'

    test h3_cdimpl

    scalar h3_cont_impl_b_`y' = _b[h3_cdimpl]
    scalar h3_cont_impl_p_`y' = r(p)
}


esttab ///
    H3_CONT_IMPL_kcal ///
    H3_CONT_IMPL_carbo ///
    H3_CONT_IMPL_fat ///
    H3_CONT_IMPL_protn ///
    using "$P2_TABLES/03_robust_continuous_pre2_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        h3_hann ///
        h3_cann ///
        h3_cdann ///
        h3_himpl ///
        h3_cimpl ///
        h3_cdimpl ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Robustness: continuous individual baseline-calorie constraint" ///
    ) ///
    addnotes( ///
        "Same individuals as the preferred two-pre-wave q25 specification", ///
        "Higher calorie-constraint index means lower baseline calories", ///
        "2004 announcement modeled separately", ///
        "Implementation period: 2006, 2009, 2011", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


* Dynamic continuous DDD.
gen double h3_c97 = ///
    h3_constraint_std * (wave == 1997) ///
    if h3_sample_main == 1

gen double h3_c04 = ///
    h3_constraint_std * (wave == 2004) ///
    if h3_sample_main == 1

gen double h3_c06 = ///
    h3_constraint_std * (wave == 2006) ///
    if h3_sample_main == 1

gen double h3_c09 = ///
    h3_constraint_std * (wave == 2009) ///
    if h3_sample_main == 1

gen double h3_c11 = ///
    h3_constraint_std * (wave == 2011) ///
    if h3_sample_main == 1


gen double h3_cd97 = ///
    h3_treated_hg * h3_constraint_std * (wave == 1997) ///
    if h3_sample_main == 1

gen double h3_cd04 = ///
    h3_treated_hg * h3_constraint_std * (wave == 2004) ///
    if h3_sample_main == 1

gen double h3_cd06 = ///
    h3_treated_hg * h3_constraint_std * (wave == 2006) ///
    if h3_sample_main == 1

gen double h3_cd09 = ///
    h3_treated_hg * h3_constraint_std * (wave == 2009) ///
    if h3_sample_main == 1

gen double h3_cd11 = ///
    h3_treated_hg * h3_constraint_std * (wave == 2011) ///
    if h3_sample_main == 1


eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        h3_h97 h3_h04 h3_h06 h3_h09 h3_h11 ///
        h3_c97 h3_c04 h3_c06 h3_c09 h3_c11 ///
        h3_cd97 h3_cd04 h3_cd06 h3_cd09 h3_cd11 ///
        if h3_sample_main == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo H3_CONT_ES_`y'

    test h3_cd97

    scalar h3_cont_pre_b_`y' = _b[h3_cd97]
    scalar h3_cont_pre_p_`y' = r(p)

    test h3_cd06 h3_cd09 h3_cd11

    scalar h3_cont_joint_impl_p_`y' = r(p)
}


esttab ///
    H3_CONT_ES_kcal ///
    H3_CONT_ES_carbo ///
    H3_CONT_ES_fat ///
    H3_CONT_ES_protn ///
    using "$P2_TABLES/03_robust_continuous_pre2_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        h3_cd97 ///
        h3_cd04 ///
        h3_cd06 ///
        h3_cd09 ///
        h3_cd11 ///
    ) ///
    order( ///
        h3_cd97 ///
        h3_cd04 ///
        h3_cd06 ///
        h3_cd09 ///
        h3_cd11 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic robustness: continuous baseline-calorie constraint" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "Same preferred two-pre-wave individuals", ///
        "Higher calorie-constraint index means lower baseline calories", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 8. ROBUSTNESS B — HOUSEHOLD BASELINE-CALORIE Q25
*
* Uses lowS1_q25_fixed from prep/05_baseline_groups.do if available.
* This is NOT the preferred heterogeneity definition.
*
* IMPORTANT:
*   This robustness has its OWN Hunan x time terms. It does not inherit the
*   preferred individual-q25 sample by accident.
*===============================================================================

capture confirm variable lowS1_q25_fixed

if !_rc {

    foreach v in ///
        h3_hh_sample ///
        h3_hh_hann ///
        h3_hh_lann ///
        h3_hh_ddd_ann ///
        h3_hh_himpl ///
        h3_hh_limpl ///
        h3_hh_ddd_impl ///
        h3_hh_h97 h3_hh_h04 h3_hh_h06 h3_hh_h09 h3_hh_h11 ///
        h3_hh_l97 h3_hh_l04 h3_hh_l06 h3_hh_l09 h3_hh_l11 ///
        h3_hh_d97 h3_hh_d04 h3_hh_d06 h3_hh_d09 h3_hh_d11 {

        capture drop `v'
    }


    gen byte h3_hh_sample = ///
        h3_sample_hg == 1 ///
        & !missing(lowS1_q25_fixed)


    * Announcement-year interactions.
    gen byte h3_hh_hann = ///
        h3_treated_hg * h3_ann2004 ///
        if h3_hh_sample == 1

    gen byte h3_hh_lann = ///
        lowS1_q25_fixed * h3_ann2004 ///
        if h3_hh_sample == 1

    gen byte h3_hh_ddd_ann = ///
        h3_treated_hg * lowS1_q25_fixed * h3_ann2004 ///
        if h3_hh_sample == 1


    * Implementation-period interactions.
    gen byte h3_hh_himpl = ///
        h3_treated_hg * h3_post_impl ///
        if h3_hh_sample == 1

    gen byte h3_hh_limpl = ///
        lowS1_q25_fixed * h3_post_impl ///
        if h3_hh_sample == 1

    gen byte h3_hh_ddd_impl = ///
        h3_treated_hg * lowS1_q25_fixed * h3_post_impl ///
        if h3_hh_sample == 1


    eststo clear


    foreach y of local outcomes {

        reghdfe lnd3`y' ///
            h3_hh_hann ///
            h3_hh_lann ///
            h3_hh_ddd_ann ///
            h3_hh_himpl ///
            h3_hh_limpl ///
            h3_hh_ddd_impl ///
            if h3_hh_sample == 1, ///
            absorb(IDind wave) ///
            vce(cluster cluster_commid)

        eststo H3_HH_IMPL_`y'

        test h3_hh_ddd_impl

        scalar h3_hh_impl_b_`y' = _b[h3_hh_ddd_impl]
        scalar h3_hh_impl_p_`y' = r(p)
    }


    esttab ///
        H3_HH_IMPL_kcal ///
        H3_HH_IMPL_carbo ///
        H3_HH_IMPL_fat ///
        H3_HH_IMPL_protn ///
        using "$P2_TABLES/03_robust_household_q25_implementation_DDD.rtf", ///
        replace ///
        keep( ///
            h3_hh_hann ///
            h3_hh_lann ///
            h3_hh_ddd_ann ///
            h3_hh_himpl ///
            h3_hh_limpl ///
            h3_hh_ddd_impl ///
        ) ///
        order( ///
            h3_hh_hann ///
            h3_hh_lann ///
            h3_hh_ddd_ann ///
            h3_hh_himpl ///
            h3_hh_limpl ///
            h3_hh_ddd_impl ///
        ) ///
        coeflabels( ///
            h3_hh_hann "Hunan x Announcement 2004" ///
            h3_hh_lann "Household low-kcal x Announcement 2004" ///
            h3_hh_ddd_ann "Hunan x Household low-kcal x Announcement 2004 (DDD)" ///
            h3_hh_himpl "Hunan x Implementation period" ///
            h3_hh_limpl "Household low-kcal x Implementation period" ///
            h3_hh_ddd_impl "Hunan x Household low-kcal x Implementation period (DDD)" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Robustness: household baseline-calorie bottom quartile" ///
        )


    * Dynamic Hunan x year terms.
    gen byte h3_hh_h97 = ///
        h3_treated_hg * (wave == 1997) ///
        if h3_hh_sample == 1

    gen byte h3_hh_h04 = ///
        h3_treated_hg * (wave == 2004) ///
        if h3_hh_sample == 1

    gen byte h3_hh_h06 = ///
        h3_treated_hg * (wave == 2006) ///
        if h3_hh_sample == 1

    gen byte h3_hh_h09 = ///
        h3_treated_hg * (wave == 2009) ///
        if h3_hh_sample == 1

    gen byte h3_hh_h11 = ///
        h3_treated_hg * (wave == 2011) ///
        if h3_hh_sample == 1


    * Household low-kcal x year terms.
    gen byte h3_hh_l97 = ///
        lowS1_q25_fixed * (wave == 1997) ///
        if h3_hh_sample == 1

    gen byte h3_hh_l04 = ///
        lowS1_q25_fixed * (wave == 2004) ///
        if h3_hh_sample == 1

    gen byte h3_hh_l06 = ///
        lowS1_q25_fixed * (wave == 2006) ///
        if h3_hh_sample == 1

    gen byte h3_hh_l09 = ///
        lowS1_q25_fixed * (wave == 2009) ///
        if h3_hh_sample == 1

    gen byte h3_hh_l11 = ///
        lowS1_q25_fixed * (wave == 2011) ///
        if h3_hh_sample == 1


    * Dynamic household-q25 DDD terms.
    gen byte h3_hh_d97 = ///
        h3_treated_hg * lowS1_q25_fixed * (wave == 1997) ///
        if h3_hh_sample == 1

    gen byte h3_hh_d04 = ///
        h3_treated_hg * lowS1_q25_fixed * (wave == 2004) ///
        if h3_hh_sample == 1

    gen byte h3_hh_d06 = ///
        h3_treated_hg * lowS1_q25_fixed * (wave == 2006) ///
        if h3_hh_sample == 1

    gen byte h3_hh_d09 = ///
        h3_treated_hg * lowS1_q25_fixed * (wave == 2009) ///
        if h3_hh_sample == 1

    gen byte h3_hh_d11 = ///
        h3_treated_hg * lowS1_q25_fixed * (wave == 2011) ///
        if h3_hh_sample == 1


    eststo clear


    foreach y of local outcomes {

        reghdfe lnd3`y' ///
            h3_hh_h97 h3_hh_h04 h3_hh_h06 h3_hh_h09 h3_hh_h11 ///
            h3_hh_l97 h3_hh_l04 h3_hh_l06 h3_hh_l09 h3_hh_l11 ///
            h3_hh_d97 h3_hh_d04 h3_hh_d06 h3_hh_d09 h3_hh_d11 ///
            if h3_hh_sample == 1, ///
            absorb(IDind wave) ///
            vce(cluster cluster_commid)

        eststo H3_HH_ES_`y'

        test h3_hh_d97

        scalar h3_hh_pre_b_`y' = _b[h3_hh_d97]
        scalar h3_hh_pre_p_`y' = r(p)
    }


    esttab ///
        H3_HH_ES_kcal ///
        H3_HH_ES_carbo ///
        H3_HH_ES_fat ///
        H3_HH_ES_protn ///
        using "$P2_TABLES/03_robust_household_q25_dynamic_DDD.rtf", ///
        replace ///
        keep( ///
            h3_hh_d97 ///
            h3_hh_d04 ///
            h3_hh_d06 ///
            h3_hh_d09 ///
            h3_hh_d11 ///
        ) ///
        order( ///
            h3_hh_d97 ///
            h3_hh_d04 ///
            h3_hh_d06 ///
            h3_hh_d09 ///
            h3_hh_d11 ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Dynamic robustness: household baseline-calorie bottom quartile" ///
        )
}
else {

    display as text ///
        "NOTE: lowS1_q25_fixed not found; household-q25 robustness skipped."
}


*===============================================================================
* 9. COMPACT SUMMARY
*===============================================================================

display as text ""
display as result "======================================================================"
display as result "FINAL BASELINE-CALORIE HETEROGENEITY SUMMARY"
display as result "======================================================================"

display as text ///
    "Preferred group: individual baseline kcal bottom 25%, calculated only among"
display as text ///
    "individuals with kcal observed in BOTH 1997 and 2000."

foreach y of local outcomes {

    display as text ""
    display as result "OUTCOME: `y'"

    display as text ///
        "Main implementation DDD          = " ///
        %9.4f scalar(h3_impl_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_impl_p_`y')

    display as text ///
        "Main pretrend DDD 1997 vs 2000   = " ///
        %9.4f scalar(h3_pre_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_pre_p_`y')

    display as text ///
        "Dynamic DDD 2004                 = " ///
        %9.4f scalar(h3_d04_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_d04_p_`y')

    display as text ///
        "Dynamic DDD 2006                 = " ///
        %9.4f scalar(h3_d06_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_d06_p_`y')

    display as text ///
        "Dynamic DDD 2009                 = " ///
        %9.4f scalar(h3_d09_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_d09_p_`y')

    display as text ///
        "Dynamic DDD 2011                 = " ///
        %9.4f scalar(h3_d11_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_d11_p_`y')

    display as text ///
        "Joint 2006/2009/2011 DDD test p  = " ///
        %9.4f scalar(h3_joint_impl_p_`y')

    display as text ///
        "Continuous implementation DDD    = " ///
        %9.4f scalar(h3_cont_impl_b_`y') ///
        "   p = " ///
        %9.4f scalar(h3_cont_impl_p_`y')

    capture confirm scalar h3_hh_impl_b_`y'

    if !_rc {

        display as text ///
            "Household-q25 implementation DDD = " ///
            %9.4f scalar(h3_hh_impl_b_`y') ///
            "   p = " ///
            %9.4f scalar(h3_hh_impl_p_`y')
    }
}

display as result "======================================================================"
display as result "END OF analyses/03_kcal_heterogeneity.do"
display as result "======================================================================"
