*===============================================================================
* PAPER 2
* TWO-PRE-WAVE BASELINE-CALORIE HETEROGENEITY
*
* Purpose:
*   Preferred calorie heterogeneity analysis using individuals whose
*   calorie intake is observed in BOTH 1997 and 2000.
*
* Baseline calorie status:
*   Existing lowKCAL_i_q25, based on individual mean kcal in 1997/2000.
*
* Outcomes:
*   kcal, carbohydrate, fat, protein
*
* Policy timing:
*   2004 = announcement
*   2005 = implementation in Hunan
*   2006 = first observed post-implementation CHNS wave
*
* Identification:
*   Fully saturated DDD
*   Individual FE + wave FE
*   Community-clustered SE
*
* Dynamic reference period:
*   2000
*
* IMPORTANT:
*   1997 triple interaction is the only clean pretrend diagnostic.
*===============================================================================


*===============================================================================
* 0. REQUIRED VARIABLES
*===============================================================================

local outcomes kcal carbo fat protn

foreach v in ///
    IDind wave treated_hg cluster_commid ///
    sample_iq25 pre_kcal_n_i lowKCAL_i_q25 {

    capture confirm variable `v'

    if _rc {
        display as error "Required variable `v' not found."
        exit 111
    }
}

foreach y of local outcomes {

    capture confirm variable lnd3`y'

    if _rc {
        display as error "Outcome lnd3`y' not found."
        exit 111
    }
}


*===============================================================================
* 1. DEFINE TWO-PRE-WAVE SAMPLE
*===============================================================================

capture drop sample_pre2_hetero

gen byte sample_pre2_hetero = ///
    sample_iq25 == 1 ///
    & pre_kcal_n_i == 2


display ""
display "============================================================"
display "TWO-PRE-WAVE HETEROGENEITY SAMPLE"
display "============================================================"


* Number of individuals
capture drop __pre2_idtag

egen byte __pre2_idtag = tag(IDind) ///
    if sample_pre2_hetero == 1

quietly count if __pre2_idtag == 1

display "Individuals = " r(N)

drop __pre2_idtag


* Number of observations
quietly count if sample_pre2_hetero == 1

display "Person-wave observations = " r(N)


* Number of communities
capture drop __pre2_ctag

egen byte __pre2_ctag = tag(cluster_commid) ///
    if sample_pre2_hetero == 1

quietly count if __pre2_ctag == 1

display "Communities = " r(N)

drop __pre2_ctag


* Composition
preserve

keep if sample_pre2_hetero == 1
bysort IDind: keep if _n == 1

tab treated_hg
tab lowKCAL_i_q25 treated_hg, column

restore


*===============================================================================
* 2. ANNOUNCEMENT-BASED AVERAGE DDD
*
* 2004 onward = exposed after policy announcement
*
* Model includes:
*   Hunan x Post
*   Low kcal x Post
*   Hunan x Low kcal x Post
*===============================================================================

foreach v in ///
    pre2_post_ann ///
    pre2_did_ann ///
    pre2_low_post_ann ///
    pre2_ddd_annavg {

    capture drop `v'
}


gen byte pre2_post_ann = ///
    (wave >= 2004) ///
    if sample_pre2_hetero == 1


gen byte pre2_did_ann = ///
    treated_hg * pre2_post_ann ///
    if sample_pre2_hetero == 1


gen byte pre2_low_post_ann = ///
    lowKCAL_i_q25 * pre2_post_ann ///
    if sample_pre2_hetero == 1


gen byte pre2_ddd_annavg = ///
    treated_hg * lowKCAL_i_q25 * pre2_post_ann ///
    if sample_pre2_hetero == 1


eststo clear


foreach y of local outcomes {

    display ""
    display "============================================================"
    display "ANNOUNCEMENT-BASED AVERAGE DDD: `y'"
    display "============================================================"

    reghdfe lnd3`y' ///
        pre2_did_ann ///
        pre2_low_post_ann ///
        pre2_ddd_annavg ///
        if sample_pre2_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo PRE2_AVG_`y'


    * Main DDD
    test pre2_ddd_annavg

    scalar pre2_avg_b_`y' = _b[pre2_ddd_annavg]
    scalar pre2_avg_p_`y' = r(p)


    * Total DID for low-calorie group
    lincom pre2_did_ann + pre2_ddd_annavg

    scalar pre2_lowavg_b_`y' = r(estimate)
    scalar pre2_lowavg_p_`y' = r(p)
}


* Export average DDD table
esttab ///
    PRE2_AVG_kcal ///
    PRE2_AVG_carbo ///
    PRE2_AVG_fat ///
    PRE2_AVG_protn ///
    using "$P2_TABLES/03c_pre2_average_DDD.rtf", ///
    replace ///
    keep( ///
        pre2_did_ann ///
        pre2_low_post_ann ///
        pre2_ddd_annavg ///
    ) ///
    order( ///
        pre2_did_ann ///
        pre2_low_post_ann ///
        pre2_ddd_annavg ///
    ) ///
    coeflabels( ///
        pre2_did_ann ///
            "Hunan x Post-announcement" ///
        pre2_low_post_ann ///
            "Low baseline kcal x Post-announcement" ///
        pre2_ddd_annavg ///
            "Hunan x Low kcal x Post-announcement (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Two-pre-wave baseline-calorie heterogeneity: average DDD" ///
    ) ///
    addnotes( ///
        "Sample requires kcal observed in both 1997 and 2000", ///
        "Baseline calorie status measured before policy exposure", ///
        "Post-announcement period begins in 2004", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 3. IMPLEMENTATION-PERIOD POOLED DDD
*
* 2004 gets its OWN announcement interactions.
* Implementation period = 2006, 2009, 2011.
*
* This avoids treating 2004 as a clean pre-treatment year.
*===============================================================================

foreach v in ///
    pre2_ann2004 ///
    pre2_post_impl ///
    pre2_hunan_ann2004 ///
    pre2_low_ann2004 ///
    pre2_ddd_ann2004 ///
    pre2_did_impl ///
    pre2_low_post_impl ///
    pre2_ddd_impl {

    capture drop `v'
}


gen byte pre2_ann2004 = ///
    (wave == 2004) ///
    if sample_pre2_hetero == 1


gen byte pre2_post_impl = ///
    (wave >= 2006) ///
    if sample_pre2_hetero == 1


* Hunan x announcement
gen byte pre2_hunan_ann2004 = ///
    treated_hg * pre2_ann2004 ///
    if sample_pre2_hetero == 1


* Low kcal x announcement
gen byte pre2_low_ann2004 = ///
    lowKCAL_i_q25 * pre2_ann2004 ///
    if sample_pre2_hetero == 1


* Hunan x Low kcal x announcement
gen byte pre2_ddd_ann2004 = ///
    treated_hg * lowKCAL_i_q25 * pre2_ann2004 ///
    if sample_pre2_hetero == 1


* Hunan x implementation
gen byte pre2_did_impl = ///
    treated_hg * pre2_post_impl ///
    if sample_pre2_hetero == 1


* Low kcal x implementation
gen byte pre2_low_post_impl = ///
    lowKCAL_i_q25 * pre2_post_impl ///
    if sample_pre2_hetero == 1


* Hunan x Low kcal x implementation
gen byte pre2_ddd_impl = ///
    treated_hg * lowKCAL_i_q25 * pre2_post_impl ///
    if sample_pre2_hetero == 1


eststo clear


foreach y of local outcomes {

    display ""
    display "============================================================"
    display "IMPLEMENTATION-PERIOD DDD: `y'"
    display "============================================================"

    reghdfe lnd3`y' ///
        pre2_hunan_ann2004 ///
        pre2_low_ann2004 ///
        pre2_ddd_ann2004 ///
        pre2_did_impl ///
        pre2_low_post_impl ///
        pre2_ddd_impl ///
        if sample_pre2_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo PRE2_IMPL_`y'


    *-----------------------------------------------------------
    * 3A. Main implementation-period heterogeneity
    *-----------------------------------------------------------

    test pre2_ddd_impl

    scalar pre2_impl_b_`y' = _b[pre2_ddd_impl]
    scalar pre2_impl_p_`y' = r(p)


    *-----------------------------------------------------------
    * 3B. Announcement-period heterogeneity
    *-----------------------------------------------------------

    test pre2_ddd_ann2004

    scalar pre2_ann_b_`y' = _b[pre2_ddd_ann2004]
    scalar pre2_ann_p_`y' = r(p)


    *-----------------------------------------------------------
    * 3C. Total implementation effect for LOW kcal group
    *-----------------------------------------------------------

    lincom pre2_did_impl + pre2_ddd_impl

    scalar pre2_lowimpl_b_`y' = r(estimate)
    scalar pre2_lowimpl_se_`y' = r(se)
    scalar pre2_lowimpl_p_`y' = r(p)


    *-----------------------------------------------------------
    * 3D. Total announcement effect for LOW kcal group
    *-----------------------------------------------------------

    lincom pre2_hunan_ann2004 + pre2_ddd_ann2004

    scalar pre2_lowann_b_`y' = r(estimate)
    scalar pre2_lowann_se_`y' = r(se)
    scalar pre2_lowann_p_`y' = r(p)


    *-----------------------------------------------------------
    * 3E. Test implementation DDD = announcement DDD
    *-----------------------------------------------------------

    test pre2_ddd_impl = pre2_ddd_ann2004

    scalar pre2_impl_vs_ann_p_`y' = r(p)
}


* Export implementation-period table
esttab ///
    PRE2_IMPL_kcal ///
    PRE2_IMPL_carbo ///
    PRE2_IMPL_fat ///
    PRE2_IMPL_protn ///
    using "$P2_TABLES/03c_pre2_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        pre2_hunan_ann2004 ///
        pre2_low_ann2004 ///
        pre2_ddd_ann2004 ///
        pre2_did_impl ///
        pre2_low_post_impl ///
        pre2_ddd_impl ///
    ) ///
    order( ///
        pre2_hunan_ann2004 ///
        pre2_low_ann2004 ///
        pre2_ddd_ann2004 ///
        pre2_did_impl ///
        pre2_low_post_impl ///
        pre2_ddd_impl ///
    ) ///
    coeflabels( ///
        pre2_hunan_ann2004 ///
            "Hunan x Announcement 2004" ///
        pre2_low_ann2004 ///
            "Low baseline kcal x Announcement 2004" ///
        pre2_ddd_ann2004 ///
            "Hunan x Low kcal x Announcement 2004 (DDD)" ///
        pre2_did_impl ///
            "Hunan x Implementation period" ///
        pre2_low_post_impl ///
            "Low baseline kcal x Implementation period" ///
        pre2_ddd_impl ///
            "Hunan x Low kcal x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Two-pre-wave baseline-calorie heterogeneity: implementation-period DDD" ///
    ) ///
    addnotes( ///
        "Sample requires kcal observed in both 1997 and 2000", ///
        "2004 is modeled separately as the announcement year", ///
        "Implementation period includes 2006, 2009, and 2011", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 4. FULL DYNAMIC DDD
*
* Omitted reference year = 2000
*
* 1997 = clean pre-policy diagnostic
* 2004 = announcement
* 2006 = first post-implementation observation
* 2009 = post-implementation
* 2011 = post-implementation
*===============================================================================

foreach v in ///
    pre2_h97 pre2_h04 pre2_h06 pre2_h09 pre2_h11 ///
    pre2_l97 pre2_l04 pre2_l06 pre2_l09 pre2_l11 ///
    pre2_d97 pre2_d04 pre2_d06 pre2_d09 pre2_d11 {

    capture drop `v'
}


*-------------------------------------------------------------------------------
* Hunan x year
*-------------------------------------------------------------------------------

gen byte pre2_h97 = ///
    treated_hg * (wave == 1997) ///
    if sample_pre2_hetero == 1

gen byte pre2_h04 = ///
    treated_hg * (wave == 2004) ///
    if sample_pre2_hetero == 1

gen byte pre2_h06 = ///
    treated_hg * (wave == 2006) ///
    if sample_pre2_hetero == 1

gen byte pre2_h09 = ///
    treated_hg * (wave == 2009) ///
    if sample_pre2_hetero == 1

gen byte pre2_h11 = ///
    treated_hg * (wave == 2011) ///
    if sample_pre2_hetero == 1


*-------------------------------------------------------------------------------
* Low baseline kcal x year
*-------------------------------------------------------------------------------

gen byte pre2_l97 = ///
    lowKCAL_i_q25 * (wave == 1997) ///
    if sample_pre2_hetero == 1

gen byte pre2_l04 = ///
    lowKCAL_i_q25 * (wave == 2004) ///
    if sample_pre2_hetero == 1

gen byte pre2_l06 = ///
    lowKCAL_i_q25 * (wave == 2006) ///
    if sample_pre2_hetero == 1

gen byte pre2_l09 = ///
    lowKCAL_i_q25 * (wave == 2009) ///
    if sample_pre2_hetero == 1

gen byte pre2_l11 = ///
    lowKCAL_i_q25 * (wave == 2011) ///
    if sample_pre2_hetero == 1


*-------------------------------------------------------------------------------
* Hunan x Low baseline kcal x year = dynamic DDD
*-------------------------------------------------------------------------------

gen byte pre2_d97 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 1997) ///
    if sample_pre2_hetero == 1

gen byte pre2_d04 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2004) ///
    if sample_pre2_hetero == 1

gen byte pre2_d06 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2006) ///
    if sample_pre2_hetero == 1

gen byte pre2_d09 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2009) ///
    if sample_pre2_hetero == 1

gen byte pre2_d11 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2011) ///
    if sample_pre2_hetero == 1


*===============================================================================
* 5. RUN DYNAMIC DDD FOR ALL FOUR NUTRITION OUTCOMES
*===============================================================================

eststo clear


foreach y of local outcomes {

    display ""
    display "============================================================"
    display "DYNAMIC DDD: `y'"
    display "REFERENCE YEAR = 2000"
    display "============================================================"

    reghdfe lnd3`y' ///
        pre2_h97 ///
        pre2_h04 ///
        pre2_h06 ///
        pre2_h09 ///
        pre2_h11 ///
        pre2_l97 ///
        pre2_l04 ///
        pre2_l06 ///
        pre2_l09 ///
        pre2_l11 ///
        pre2_d97 ///
        pre2_d04 ///
        pre2_d06 ///
        pre2_d09 ///
        pre2_d11 ///
        if sample_pre2_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo PRE2_ES_`y'


    *-----------------------------------------------------------
    * 5A. DIFFERENTIAL PRETREND
    *
    * 1997 relative to omitted 2000
    *-----------------------------------------------------------

    test pre2_d97

    scalar pre2_pre_b_`y' = _b[pre2_d97]
    scalar pre2_pre_p_`y' = r(p)

    display ""
    display "PRETREND DIAGNOSTIC:"
    display ///
        "1997 DDD = " ///
        %9.4f _b[pre2_d97] ///
        "   p = " ///
        %9.4f r(p)


    *-----------------------------------------------------------
    * 5B. ANNOUNCEMENT YEAR
    *-----------------------------------------------------------

    test pre2_d04

    scalar pre2_dyn04_b_`y' = _b[pre2_d04]
    scalar pre2_dyn04_p_`y' = r(p)


    *-----------------------------------------------------------
    * 5C. INDIVIDUAL IMPLEMENTATION-YEAR EFFECTS
    *-----------------------------------------------------------

    scalar pre2_dyn06_b_`y' = _b[pre2_d06]
    scalar pre2_dyn09_b_`y' = _b[pre2_d09]
    scalar pre2_dyn11_b_`y' = _b[pre2_d11]


    test pre2_d06
    scalar pre2_dyn06_p_`y' = r(p)

    test pre2_d09
    scalar pre2_dyn09_p_`y' = r(p)

    test pre2_d11
    scalar pre2_dyn11_p_`y' = r(p)


    *-----------------------------------------------------------
    * 5D. JOINT IMPLEMENTATION-PERIOD TEST
    *
    * Tests 2006, 2009, 2011 jointly
    *-----------------------------------------------------------

    test pre2_d06 pre2_d09 pre2_d11

    scalar pre2_joint_impl_p_`y' = r(p)

    display ///
        "JOINT 2006/2009/2011 DDD p = " ///
        %9.4f r(p)
}


*===============================================================================
* 6. EXPORT DYNAMIC DDD TABLE
*===============================================================================

esttab ///
    PRE2_ES_kcal ///
    PRE2_ES_carbo ///
    PRE2_ES_fat ///
    PRE2_ES_protn ///
    using "$P2_TABLES/03c_pre2_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        pre2_d97 ///
        pre2_d04 ///
        pre2_d06 ///
        pre2_d09 ///
        pre2_d11 ///
    ) ///
    order( ///
        pre2_d97 ///
        pre2_d04 ///
        pre2_d06 ///
        pre2_d09 ///
        pre2_d11 ///
    ) ///
    coeflabels( ///
        pre2_d97 ///
            "1997 x Hunan x Low kcal" ///
        pre2_d04 ///
            "2004 x Hunan x Low kcal" ///
        pre2_d06 ///
            "2006 x Hunan x Low kcal" ///
        pre2_d09 ///
            "2009 x Hunan x Low kcal" ///
        pre2_d11 ///
            "2011 x Hunan x Low kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD by baseline calorie status: two-pre-wave sample" ///
    ) ///
    addnotes( ///
        "Reference year: 2000", ///
        "1997 triple interaction is the differential-pretrend diagnostic", ///
        "2004 is the announcement wave", ///
        "2006, 2009, and 2011 are post-implementation observations", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 7. COMPACT SUMMARY
*
* THIS IS THE PART TO COPY BACK TO CHATGPT
*===============================================================================

display ""
display "======================================================================"
display "TWO-PRE-WAVE BASELINE-CALORIE HETEROGENEITY SUMMARY"
display "======================================================================"


foreach y of local outcomes {

    display ""
    display "OUTCOME: `y'"
    display "----------------------------------------------------------------------"


    * Average announcement-based DDD
    display ///
        "Average DDD (2004+)             = " ///
        %8.4f scalar(pre2_avg_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_avg_p_`y')


    * Differential pretrend
    display ///
        "Pretrend DDD 1997 vs 2000       = " ///
        %8.4f scalar(pre2_pre_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_pre_p_`y')


    * Announcement
    display ///
        "Announcement DDD 2004           = " ///
        %8.4f scalar(pre2_ann_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_ann_p_`y')


    * Implementation pooled
    display ///
        "Implementation DDD 2006-2011    = " ///
        %8.4f scalar(pre2_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_impl_p_`y')


    * Low group's total treatment effect
    display ///
        "Low-group total impl DID        = " ///
        %8.4f scalar(pre2_lowimpl_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_lowimpl_p_`y')


    * Announcement total effect
    display ///
        "Low-group total announcement DID= " ///
        %8.4f scalar(pre2_lowann_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_lowann_p_`y')


    * Difference announcement vs implementation
    display ///
        "Impl DDD = Ann DDD test         p = " ///
        %7.4f scalar(pre2_impl_vs_ann_p_`y')


    * Dynamic coefficients
    display ///
        "Dynamic DDD 2004                = " ///
        %8.4f scalar(pre2_dyn04_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_dyn04_p_`y')

    display ///
        "Dynamic DDD 2006                = " ///
        %8.4f scalar(pre2_dyn06_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_dyn06_p_`y')

    display ///
        "Dynamic DDD 2009                = " ///
        %8.4f scalar(pre2_dyn09_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_dyn09_p_`y')

    display ///
        "Dynamic DDD 2011                = " ///
        %8.4f scalar(pre2_dyn11_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre2_dyn11_p_`y')


    * Joint test
    display ///
        "Joint DDD 2006/2009/2011 test   p = " ///
        %7.4f scalar(pre2_joint_impl_p_`y')

}


display ""
display "======================================================================"
display "END OF TWO-PRE-WAVE HETEROGENEITY ANALYSIS"
display "======================================================================"