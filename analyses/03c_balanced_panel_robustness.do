*===============================================================================
* PAPER 2 — BALANCED-PANEL HETEROGENEITY ROBUSTNESS
* File: analyses/03c_balanced_panel_robustness.do
*
* PURPOSE
*   Check whether the preferred baseline-calorie heterogeneity results are
*   sensitive to panel composition / outcome availability.
*
* IMPORTANT DESIGN CHOICE
*   The low-calorie group is NOT redefined outcome-by-outcome.
*
*   It is always:
*       individual mean kcal in 1997 and 2000,
*       both waves required,
*       bottom 25% calculated among the same two-pre-wave baseline population.
*
*   The robustness exercises change ONLY the estimation sample:
*
*   A. PRE-PERIOD BALANCED:
*      outcome y observed in both 1997 and 2000.
*
*   B. SIX-WAVE BALANCED:
*      outcome y observed in all six waves:
*      1997 / 2000 / 2004 / 2006 / 2009 / 2011.
*
*   Six-wave balance uses post-treatment retention and is therefore APPENDIX
*   robustness only, not the preferred identifying sample.
*
* POLICY TIMING
*   1997 = clean pre-policy diagnostic
*   2000 = omitted reference
*   2004 = announcement wave, modeled separately
*   2006/2009/2011 = implementation-period observations
*
* ESTIMATION
*   Individual FE + wave FE
*   Community-clustered standard errors
*   No contemporaneous controls
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED VARIABLES
*===============================================================================

local outcomes kcal carbo fat protn

foreach v in ///
    IDind wave cluster_commid consumer_base ///
    d3kcal lnd3kcal lnd3carbo lnd3fat lnd3protn {

    capture confirm variable `v'

    if _rc {
        display as error "Required variable `v' not found."
        exit 111
    }
}


*===============================================================================
* 1. HUNAN / GUIZHOU POPULATION
*===============================================================================

capture drop h3c_sample_hg h3c_treated_hg

capture confirm variable t1

if !_rc {

    gen byte h3c_sample_hg = inlist(t1, 43, 52)

    gen byte h3c_treated_hg = ///
        (t1 == 43) ///
        if h3c_sample_hg == 1
}
else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists. Cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte h3c_sample_hg = inlist(province_code, 43, 52)

    gen byte h3c_treated_hg = ///
        (province_code == 43) ///
        if h3c_sample_hg == 1
}


*===============================================================================
* 2. RECREATE THE SAME PREFERRED BASELINE GROUP
*
* This definition matches analyses/03_kcal_heterogeneity.do.
*===============================================================================

foreach v in ///
    h3c_kcal97 ///
    h3c_kcal00 ///
    h3c_pre_n ///
    h3c_pre_kcal ///
    h3c_qkcal ///
    h3c_low_q25 ///
    h3c_base_sample {

    capture drop `v'
}


bysort IDind: egen double h3c_kcal97 = max( ///
    cond( ///
        wave == 1997 ///
        & h3c_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen double h3c_kcal00 = max( ///
    cond( ///
        wave == 2000 ///
        & h3c_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


gen byte h3c_pre_n = ///
    !missing(h3c_kcal97) ///
    + !missing(h3c_kcal00)


gen double h3c_pre_kcal = ///
    (h3c_kcal97 + h3c_kcal00) / 2 ///
    if h3c_pre_n == 2


preserve

    keep if ///
        h3c_sample_hg == 1 ///
        & h3c_pre_n == 2 ///
        & !missing(h3c_pre_kcal)

    keep IDind h3c_pre_kcal

    bysort IDind: keep if _n == 1

    isid IDind

    quietly count
    local N_pre2 = r(N)

    if `N_pre2' < 4 {
        display as error ///
            "ERROR: fewer than 4 individuals define the preferred q25 cutoff."
        restore
        exit 2001
    }

    xtile h3c_qkcal = h3c_pre_kcal, nq(4)

    gen byte h3c_low_q25 = ///
        (h3c_qkcal == 1) ///
        if !missing(h3c_qkcal)

    keep IDind h3c_qkcal h3c_low_q25

    tempfile h3c_groups
    save `h3c_groups', replace

restore


merge m:1 IDind using `h3c_groups', ///
    nogen ///
    keep(master match)


gen byte h3c_base_sample = ///
    h3c_sample_hg == 1 ///
    & h3c_pre_n == 2 ///
    & !missing(h3c_low_q25)


*===============================================================================
* 3. COMMON POLICY VARIABLES
*===============================================================================

capture drop h3c_ann2004 h3c_post_impl

gen byte h3c_ann2004 = ///
    (wave == 2004) ///
    if h3c_sample_hg == 1

gen byte h3c_post_impl = ///
    (wave >= 2006) ///
    if h3c_sample_hg == 1


*===============================================================================
* 4. BALANCE FLAGS
*===============================================================================

foreach y of local outcomes {

    foreach v in ///
        h3c_has97_`y' ///
        h3c_has00_`y' ///
        h3c_prebal_`y' ///
        h3c_has04_`y' ///
        h3c_has06_`y' ///
        h3c_has09_`y' ///
        h3c_has11_`y' ///
        h3c_bal6_`y' {

        capture drop `v'
    }


    bysort IDind: egen byte h3c_has97_`y' = max( ///
        wave == 1997 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )

    bysort IDind: egen byte h3c_has00_`y' = max( ///
        wave == 2000 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )

    gen byte h3c_prebal_`y' = ///
        h3c_base_sample == 1 ///
        & h3c_has97_`y' == 1 ///
        & h3c_has00_`y' == 1


    bysort IDind: egen byte h3c_has04_`y' = max( ///
        wave == 2004 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )

    bysort IDind: egen byte h3c_has06_`y' = max( ///
        wave == 2006 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )

    bysort IDind: egen byte h3c_has09_`y' = max( ///
        wave == 2009 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )

    bysort IDind: egen byte h3c_has11_`y' = max( ///
        wave == 2011 ///
        & h3c_base_sample == 1 ///
        & !missing(lnd3`y') ///
    )


    gen byte h3c_bal6_`y' = ///
        h3c_base_sample == 1 ///
        & h3c_has97_`y' == 1 ///
        & h3c_has00_`y' == 1 ///
        & h3c_has04_`y' == 1 ///
        & h3c_has06_`y' == 1 ///
        & h3c_has09_`y' == 1 ///
        & h3c_has11_`y' == 1
}


*===============================================================================
* 5. SAMPLE COUNTS
*===============================================================================

display as text ""
display as result "============================================================"
display as result "BALANCED-PANEL HETEROGENEITY SAMPLE COUNTS"
display as result "============================================================"

foreach y of local outcomes {

    capture drop __h3c_tag

    egen byte __h3c_tag = tag(IDind) ///
        if h3c_prebal_`y' == 1

    quietly count if __h3c_tag == 1

    display as result ///
        "`y' pre-period-balanced individuals = " r(N)

    drop __h3c_tag


    egen byte __h3c_tag = tag(IDind) ///
        if h3c_bal6_`y' == 1

    quietly count if __h3c_tag == 1

    display as result ///
        "`y' six-wave-balanced individuals   = " r(N)

    drop __h3c_tag
}


*===============================================================================
* 6. PROGRAM TO RUN ONE ROBUSTNESS SAMPLE
*
* Variables use COMMON names so coefficients align across outcome columns.
* Stored estimates/scalars use the supplied prefix.
*===============================================================================

capture program drop h3c_run_one

program define h3c_run_one

    args y sampleflag prefix


    *---------------------------------------------------------------------------
    * A. Pooled implementation-period DDD
    *---------------------------------------------------------------------------

    foreach v in ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl {

        capture drop `v'
    }


    gen byte h3c_hann = ///
        h3c_treated_hg * h3c_ann2004 ///
        if `sampleflag' == 1

    gen byte h3c_lann = ///
        h3c_low_q25 * h3c_ann2004 ///
        if `sampleflag' == 1

    gen byte h3c_dann = ///
        h3c_treated_hg * h3c_low_q25 * h3c_ann2004 ///
        if `sampleflag' == 1

    gen byte h3c_himpl = ///
        h3c_treated_hg * h3c_post_impl ///
        if `sampleflag' == 1

    gen byte h3c_limpl = ///
        h3c_low_q25 * h3c_post_impl ///
        if `sampleflag' == 1

    gen byte h3c_dimpl = ///
        h3c_treated_hg * h3c_low_q25 * h3c_post_impl ///
        if `sampleflag' == 1


    reghdfe lnd3`y' ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl ///
        if `sampleflag' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    estimates store `prefix'_IMPL


    test h3c_dimpl

    scalar `prefix'_impl_b = _b[h3c_dimpl]
    scalar `prefix'_impl_p = r(p)


    *---------------------------------------------------------------------------
    * B. Dynamic DDD
    *---------------------------------------------------------------------------

    foreach v in ///
        h3c_h97 h3c_h04 h3c_h06 h3c_h09 h3c_h11 ///
        h3c_l97 h3c_l04 h3c_l06 h3c_l09 h3c_l11 ///
        h3c_d97 h3c_d04 h3c_d06 h3c_d09 h3c_d11 {

        capture drop `v'
    }


    gen byte h3c_h97 = ///
        h3c_treated_hg * (wave == 1997) ///
        if `sampleflag' == 1

    gen byte h3c_h04 = ///
        h3c_treated_hg * (wave == 2004) ///
        if `sampleflag' == 1

    gen byte h3c_h06 = ///
        h3c_treated_hg * (wave == 2006) ///
        if `sampleflag' == 1

    gen byte h3c_h09 = ///
        h3c_treated_hg * (wave == 2009) ///
        if `sampleflag' == 1

    gen byte h3c_h11 = ///
        h3c_treated_hg * (wave == 2011) ///
        if `sampleflag' == 1


    gen byte h3c_l97 = ///
        h3c_low_q25 * (wave == 1997) ///
        if `sampleflag' == 1

    gen byte h3c_l04 = ///
        h3c_low_q25 * (wave == 2004) ///
        if `sampleflag' == 1

    gen byte h3c_l06 = ///
        h3c_low_q25 * (wave == 2006) ///
        if `sampleflag' == 1

    gen byte h3c_l09 = ///
        h3c_low_q25 * (wave == 2009) ///
        if `sampleflag' == 1

    gen byte h3c_l11 = ///
        h3c_low_q25 * (wave == 2011) ///
        if `sampleflag' == 1


    gen byte h3c_d97 = ///
        h3c_treated_hg * h3c_low_q25 * (wave == 1997) ///
        if `sampleflag' == 1

    gen byte h3c_d04 = ///
        h3c_treated_hg * h3c_low_q25 * (wave == 2004) ///
        if `sampleflag' == 1

    gen byte h3c_d06 = ///
        h3c_treated_hg * h3c_low_q25 * (wave == 2006) ///
        if `sampleflag' == 1

    gen byte h3c_d09 = ///
        h3c_treated_hg * h3c_low_q25 * (wave == 2009) ///
        if `sampleflag' == 1

    gen byte h3c_d11 = ///
        h3c_treated_hg * h3c_low_q25 * (wave == 2011) ///
        if `sampleflag' == 1


    reghdfe lnd3`y' ///
        h3c_h97 h3c_h04 h3c_h06 h3c_h09 h3c_h11 ///
        h3c_l97 h3c_l04 h3c_l06 h3c_l09 h3c_l11 ///
        h3c_d97 h3c_d04 h3c_d06 h3c_d09 h3c_d11 ///
        if `sampleflag' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    estimates store `prefix'_ES


    test h3c_d97

    scalar `prefix'_pre_b = _b[h3c_d97]
    scalar `prefix'_pre_p = r(p)


    test h3c_d06 h3c_d09 h3c_d11

    scalar `prefix'_joint_impl_p = r(p)

end


*===============================================================================
* 7. PRE-PERIOD BALANCED ROBUSTNESS
*===============================================================================

foreach y of local outcomes {

    h3c_run_one ///
        `y' ///
        h3c_prebal_`y' ///
        H3C_PB_`y'
}


esttab ///
    H3C_PB_kcal_IMPL ///
    H3C_PB_carbo_IMPL ///
    H3C_PB_fat_IMPL ///
    H3C_PB_protn_IMPL ///
    using "$P2_TABLES/03c_preperiod_balanced_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl ///
    ) ///
    order( ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl ///
    ) ///
    coeflabels( ///
        h3c_hann "Hunan x Announcement 2004" ///
        h3c_lann "Low baseline kcal x Announcement 2004" ///
        h3c_dann "Hunan x Low kcal x Announcement 2004 (DDD)" ///
        h3c_himpl "Hunan x Implementation period" ///
        h3c_limpl "Low baseline kcal x Implementation period" ///
        h3c_dimpl "Hunan x Low kcal x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Appendix robustness: pre-period-balanced implementation DDD" ///
    ) ///
    addnotes( ///
        "Preferred baseline calorie group is held fixed", ///
        "Outcome must be observed in both 1997 and 2000", ///
        "2004 announcement modeled separately", ///
        "Implementation period: 2006, 2009, 2011", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    H3C_PB_kcal_ES ///
    H3C_PB_carbo_ES ///
    H3C_PB_fat_ES ///
    H3C_PB_protn_ES ///
    using "$P2_TABLES/03c_preperiod_balanced_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        h3c_d97 ///
        h3c_d04 ///
        h3c_d06 ///
        h3c_d09 ///
        h3c_d11 ///
    ) ///
    order( ///
        h3c_d97 ///
        h3c_d04 ///
        h3c_d06 ///
        h3c_d09 ///
        h3c_d11 ///
    ) ///
    coeflabels( ///
        h3c_d97 "1997 x Hunan x Low baseline kcal" ///
        h3c_d04 "2004 x Hunan x Low baseline kcal" ///
        h3c_d06 "2006 x Hunan x Low baseline kcal" ///
        h3c_d09 "2009 x Hunan x Low baseline kcal" ///
        h3c_d11 "2011 x Hunan x Low baseline kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Appendix robustness: pre-period-balanced dynamic DDD" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "Preferred baseline calorie group is held fixed", ///
        "1997 triple interaction is the differential-pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 8. SIX-WAVE BALANCED ROBUSTNESS
*===============================================================================

foreach y of local outcomes {

    h3c_run_one ///
        `y' ///
        h3c_bal6_`y' ///
        H3C_B6_`y'
}


esttab ///
    H3C_B6_kcal_IMPL ///
    H3C_B6_carbo_IMPL ///
    H3C_B6_fat_IMPL ///
    H3C_B6_protn_IMPL ///
    using "$P2_TABLES/03c_sixwave_balanced_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl ///
    ) ///
    order( ///
        h3c_hann ///
        h3c_lann ///
        h3c_dann ///
        h3c_himpl ///
        h3c_limpl ///
        h3c_dimpl ///
    ) ///
    coeflabels( ///
        h3c_hann "Hunan x Announcement 2004" ///
        h3c_lann "Low baseline kcal x Announcement 2004" ///
        h3c_dann "Hunan x Low kcal x Announcement 2004 (DDD)" ///
        h3c_himpl "Hunan x Implementation period" ///
        h3c_limpl "Low baseline kcal x Implementation period" ///
        h3c_dimpl "Hunan x Low kcal x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Appendix robustness: six-wave-balanced implementation DDD" ///
    ) ///
    addnotes( ///
        "Preferred baseline calorie group is held fixed", ///
        "Outcome must be observed in all six analysis waves", ///
        "Six-wave balance is robustness only because it uses post-treatment retention", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    H3C_B6_kcal_ES ///
    H3C_B6_carbo_ES ///
    H3C_B6_fat_ES ///
    H3C_B6_protn_ES ///
    using "$P2_TABLES/03c_sixwave_balanced_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        h3c_d97 ///
        h3c_d04 ///
        h3c_d06 ///
        h3c_d09 ///
        h3c_d11 ///
    ) ///
    order( ///
        h3c_d97 ///
        h3c_d04 ///
        h3c_d06 ///
        h3c_d09 ///
        h3c_d11 ///
    ) ///
    coeflabels( ///
        h3c_d97 "1997 x Hunan x Low baseline kcal" ///
        h3c_d04 "2004 x Hunan x Low baseline kcal" ///
        h3c_d06 "2006 x Hunan x Low baseline kcal" ///
        h3c_d09 "2009 x Hunan x Low baseline kcal" ///
        h3c_d11 "2011 x Hunan x Low baseline kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Appendix robustness: six-wave-balanced dynamic DDD" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "Preferred baseline calorie group is held fixed", ///
        "Six-wave balance is robustness only because it uses post-treatment retention", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 9. COMPACT SUMMARY
*===============================================================================

display as text ""
display as result "======================================================================"
display as result "BALANCED-PANEL ROBUSTNESS SUMMARY"
display as result "======================================================================"

foreach y of local outcomes {

    display as text ""
    display as result "OUTCOME: `y'"

    display as text ///
        "Pre-balanced implementation DDD = " ///
        %9.4f scalar(H3C_PB_`y'_impl_b) ///
        "   p = " ///
        %9.4f scalar(H3C_PB_`y'_impl_p)

    display as text ///
        "Pre-balanced pretrend DDD       = " ///
        %9.4f scalar(H3C_PB_`y'_pre_b) ///
        "   p = " ///
        %9.4f scalar(H3C_PB_`y'_pre_p)

    display as text ///
        "Pre-balanced joint post p       = " ///
        %9.4f scalar(H3C_PB_`y'_joint_impl_p)

    display as text ///
        "Six-wave implementation DDD     = " ///
        %9.4f scalar(H3C_B6_`y'_impl_b) ///
        "   p = " ///
        %9.4f scalar(H3C_B6_`y'_impl_p)

    display as text ///
        "Six-wave pretrend DDD            = " ///
        %9.4f scalar(H3C_B6_`y'_pre_b) ///
        "   p = " ///
        %9.4f scalar(H3C_B6_`y'_pre_p)

    display as text ///
        "Six-wave joint post p            = " ///
        %9.4f scalar(H3C_B6_`y'_joint_impl_p)
}

display as result "======================================================================"
display as result "END OF analyses/03c_balanced_panel_robustness.do"
display as result "======================================================================"
