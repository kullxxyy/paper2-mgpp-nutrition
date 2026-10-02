*===============================================================================
* PAPER 2 — BASELINE-CALORIE HETEROGENEITY
* File: analyses/03_kcal_heterogeneity.do
*
* MAIN DESIGN:
*   Treated province: Hunan  (43)
*   Control province: Guizhou (52)
*
* POLICY TIMING:
*   1997 = pre-treatment
*   2000 = omitted reference / last clean pre-treatment wave
*   2004 = policy announcement / treatment onset
*   2006 = post
*   2009 = post
*   2011 = post
*
* SAMPLE:
*   Pure consumers only: consumer_base == 1
*
* HETEROGENEITY:
*   lowS1_q25 = bottom quartile of household calorie intake
*               measured using ONLY 1997 and 2000
*
* IMPORTANT:
*   The low-calorie cutoff is constructed ONLY among the Hunan-Guizhou
*   pure-consumer analysis population.
*===============================================================================


*===============================================================================
* 0. SETTINGS
*===============================================================================

local outcomes kcal carbo fat protn

local RD1 ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


*===============================================================================
* 1. DEFINE HUNAN-GUIZHOU ANALYSIS POPULATION
*===============================================================================

capture drop sample_hg treated_hg


*-------------------------------------------------------------------------------
* Prefer original CHNS province variable t1.
* Fall back to province_code if t1 is unavailable.
*-------------------------------------------------------------------------------

capture confirm variable t1

if !_rc {

    gen byte sample_hg = ///
        inlist(t1, 43, 52)

    gen byte treated_hg = ///
        (t1 == 43) ///
        if sample_hg == 1
}

else {

    capture confirm variable province_code

    if _rc {

        display as error ///
            "Neither t1 nor province_code exists. Cannot identify Hunan/Guizhou."

        exit 111
    }

    gen byte sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte treated_hg = ///
        (province_code == 43) ///
        if sample_hg == 1
}


label define hg_treat ///
    0 "Guizhou" ///
    1 "Hunan", replace

label values treated_hg hg_treat

label variable sample_hg ///
    "Hunan-Guizhou analysis population"

label variable treated_hg ///
    "Hunan treatment indicator"


*-------------------------------------------------------------------------------
* Quick check
*-------------------------------------------------------------------------------

tab treated_hg ///
    if sample_hg == 1, missing

tab treated_hg wave ///
    if sample_hg == 1 ///
    & consumer_base == 1, ///
    missing


*===============================================================================
* 2. ANNOUNCEMENT-BASED DID AND EVENT-TIME VARIABLES
*
* Reference year = 2000
* Treatment onset = 2004
*===============================================================================

capture drop ///
    did_ann ///
    evt_m7_ann ///
    evt_p0_ann ///
    evt_p2_ann ///
    evt_p5_ann ///
    evt_p7_ann


* Average DID treatment
gen byte did_ann = ///
    treated_hg == 1 ///
    & wave >= 2004 ///
    if sample_hg == 1


* 1997 = only clean pre-treatment lead
gen byte evt_m7_ann = ///
    treated_hg == 1 ///
    & wave == 1997 ///
    if sample_hg == 1


* 2000 omitted/reference


* 2004 = announcement / treatment onset
gen byte evt_p0_ann = ///
    treated_hg == 1 ///
    & wave == 2004 ///
    if sample_hg == 1


gen byte evt_p2_ann = ///
    treated_hg == 1 ///
    & wave == 2006 ///
    if sample_hg == 1


gen byte evt_p5_ann = ///
    treated_hg == 1 ///
    & wave == 2009 ///
    if sample_hg == 1


gen byte evt_p7_ann = ///
    treated_hg == 1 ///
    & wave == 2011 ///
    if sample_hg == 1


label variable did_ann ///
    "Hunan x post-2004 announcement"


*===============================================================================
* 3. RECONSTRUCT BASELINE LOW-CALORIE GROUP
*
* IMPORTANT:
*   - Uses 1997 and 2000 ONLY.
*   - Uses pure consumers ONLY.
*   - Uses Hunan and Guizhou ONLY.
*   - Quartiles are calculated at the HOUSEHOLD level.
*===============================================================================

capture drop ///
    pre_kcal_hh ///
    qkcal_hh ///
    lowS1_q25


*-------------------------------------------------------------------------------
* Household mean calorie intake in clean pre-treatment years.
*
* This reproduces the original household-level logic but excludes 2004.
*-------------------------------------------------------------------------------

bysort hhid: egen pre_kcal_hh = mean( ///
    cond( ///
        inlist(wave, 1997, 2000) ///
        & consumer_base == 1 ///
        & sample_hg == 1, ///
        d3kcal, ///
        . ///
    ) ///
)


label variable pre_kcal_hh ///
    "Mean household calorie intake, 1997/2000"


*-------------------------------------------------------------------------------
* Calculate quartile cutoff using ONE observation per eligible household.
*-------------------------------------------------------------------------------

preserve

    keep if ///
        sample_hg == 1 ///
        & consumer_base == 1

    keep hhid pre_kcal_hh

    drop if missing(pre_kcal_hh)

    bysort hhid: keep if _n == 1

    isid hhid

    xtile qkcal_hh = pre_kcal_hh, nq(4)

    keep hhid pre_kcal_hh qkcal_hh

    tempfile kcal_groups
    save `kcal_groups'

restore


*-------------------------------------------------------------------------------
* Merge baseline group back to full panel.
*-------------------------------------------------------------------------------

merge m:1 hhid using `kcal_groups', ///
    nogen ///
    keep(master match)


gen byte lowS1_q25 = ///
    (qkcal_hh == 1) ///
    if !missing(qkcal_hh)


label variable lowS1_q25 ///
    "Bottom 25% baseline calories among Hunan-Guizhou pure consumers"


*===============================================================================
* 4. CHECK BASELINE GROUP
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "BASELINE LOW-CALORIE GROUP CHECK"

display as text ///
    "============================================================"


tab lowS1_q25 ///
    if sample_hg == 1 ///
    & consumer_base == 1, ///
    missing


tab lowS1_q25 treated_hg ///
    if sample_hg == 1 ///
    & consumer_base == 1, ///
    column


summarize pre_kcal_hh ///
    if sample_hg == 1 ///
    & consumer_base == 1, ///
    detail


*===============================================================================
* 5. SAMPLE DIAGNOSTICS
*===============================================================================

capture drop tag_hetero

egen tag_hetero = tag(IDind) ///
    if sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(lowS1_q25)


quietly count ///
    if tag_hetero == 1

display as text ///
    "Unique individuals in heterogeneity population = " r(N)


tab treated_hg ///
    if tag_hetero == 1


*===============================================================================
* 6. BASELINE-CALORIE HETEROGENEITY — AVERAGE DID
*
* Interpretation:
*
*   1.did_ann
*       = effect for non-low-calorie consumers
*
*   1.did_ann#1.lowS1_q25
*       = DIFFERENTIAL policy effect for low-calorie consumers
*
*   Total low-calorie effect:
*
*       1.did_ann
*       + 1.did_ann#1.lowS1_q25
*===============================================================================

eststo clear


foreach y of local outcomes {

    display as text ///
        "============================================================"

    display as text ///
        "AVERAGE DID HETEROGENEITY: `y'"

    display as text ///
        "============================================================"


    reghdfe lnd3`y' ///
        i.did_ann##i.lowS1_q25 ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowS1_q25), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo DID_`y'


    *---------------------------------------------------------------------------
    * Total effect for low-calorie households
    *---------------------------------------------------------------------------

    lincom ///
        1.did_ann ///
        + 1.did_ann#1.lowS1_q25


    scalar low_did_b_`y'  = r(estimate)
    scalar low_did_se_`y' = r(se)
    scalar low_did_p_`y'  = r(p)


    display as text ///
        "Low-calorie total DID (`y') = " ///
        %9.4f scalar(low_did_b_`y')

    display as text ///
        "Low-calorie total DID p-value = " ///
        %9.4f scalar(low_did_p_`y')


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_DID_`y'.ster", ///
        replace
}


*===============================================================================
* 7. DISPLAY AVERAGE DID TABLE
*===============================================================================

esttab ///
    DID_kcal ///
    DID_carbo ///
    DID_fat ///
    DID_protn, ///
    keep( ///
        1.did_ann ///
        1.did_ann#1.lowS1_q25 ///
    ) ///
    order( ///
        1.did_ann ///
        1.did_ann#1.lowS1_q25 ///
    ) ///
    coeflabels( ///
        1.did_ann ///
            "Non-low calorie: DID" ///
        1.did_ann#1.lowS1_q25 ///
            "Low calorie: differential DID" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: announcement-based DID" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Baseline calorie group based on 1997 and 2000 only", ///
        "Treatment begins in 2004", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 8. SAVE AVERAGE DID TABLE
*===============================================================================

esttab ///
    DID_kcal ///
    DID_carbo ///
    DID_fat ///
    DID_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_table_01.rtf", ///
    replace ///
    keep( ///
        1.did_ann ///
        1.did_ann#1.lowS1_q25 ///
    ) ///
    coeflabels( ///
        1.did_ann ///
            "Non-low calorie: DID" ///
        1.did_ann#1.lowS1_q25 ///
            "Low calorie: differential DID" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: announcement-based DID" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Baseline calorie group based on 1997 and 2000 only", ///
        "Treatment begins in 2004", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    DID_kcal ///
    DID_carbo ///
    DID_fat ///
    DID_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_table_01.csv", ///
    replace ///
    keep( ///
        1.did_ann ///
        1.did_ann#1.lowS1_q25 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01)


*===============================================================================
* 9. DISPLAY TOTAL LOW-CALORIE DID EFFECTS
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "LOW-CALORIE TOTAL DID EFFECTS"

display as text ///
    "============================================================"


display as text ///
    "kcal    = " ///
    %9.4f scalar(low_did_b_kcal) ///
    "   p = " ///
    %9.4f scalar(low_did_p_kcal)


display as text ///
    "carbo   = " ///
    %9.4f scalar(low_did_b_carbo) ///
    "   p = " ///
    %9.4f scalar(low_did_p_carbo)


display as text ///
    "fat     = " ///
    %9.4f scalar(low_did_b_fat) ///
    "   p = " ///
    %9.4f scalar(low_did_p_fat)


display as text ///
    "protein = " ///
    %9.4f scalar(low_did_b_protn) ///
    "   p = " ///
    %9.4f scalar(low_did_p_protn)


display as text ///
    "============================================================"


*===============================================================================
* 10. HETEROGENEOUS EVENT STUDY
*
* Reference year = 2000
*
* evt_m7_ann:
*   Hunan-control difference in 1997 relative to 2000
*   among NON-low-calorie households.
*
* lowS1_q25 x evt_m7_ann:
*   Additional/differential pretrend of low-calorie households.
*
* Sum:
*   Total pretrend for low-calorie households.
*===============================================================================

eststo clear


foreach y of local outcomes {

    display as text ///
        "============================================================"

    display as text ///
        "HETEROGENEOUS EVENT STUDY: `y'"

    display as text ///
        "Reference year = 2000"

    display as text ///
        "============================================================"


    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.lowS1_q25#c.evt_m7_ann ///
        1.lowS1_q25#c.evt_p0_ann ///
        1.lowS1_q25#c.evt_p2_ann ///
        1.lowS1_q25#c.evt_p5_ann ///
        1.lowS1_q25#c.evt_p7_ann ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowS1_q25), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo ES_`y'


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_ES_`y'.ster", ///
        replace


    *===========================================================================
    * PRE-TREND TEST A
    * Non-low-calorie consumers
    *===========================================================================

    test evt_m7_ann

    scalar pre_main_`y' = r(p)


    display as text ///
        "Non-low pretrend p-value = " ///
        %9.4f scalar(pre_main_`y')


    *===========================================================================
    * PRE-TREND TEST B
    * Differential pretrend for low-calorie consumers
    *===========================================================================

    test ///
        1.lowS1_q25#c.evt_m7_ann

    scalar pre_diff_`y' = r(p)


    display as text ///
        "Differential pretrend p-value = " ///
        %9.4f scalar(pre_diff_`y')


    *===========================================================================
    * PRE-TREND TEST C
    * Total low-calorie pretrend
    *===========================================================================

    lincom ///
        evt_m7_ann ///
        + 1.lowS1_q25#c.evt_m7_ann


    scalar pre_low_b_`y' = r(estimate)
    scalar pre_low_p_`y' = r(p)


    display as text ///
        "Low-calorie total pretrend = " ///
        %9.4f scalar(pre_low_b_`y')

    display as text ///
        "Low-calorie total pretrend p-value = " ///
        %9.4f scalar(pre_low_p_`y')


    *===========================================================================
    * POST-TREATMENT TOTAL EFFECT — 2004
    *===========================================================================

    lincom ///
        evt_p0_ann ///
        + 1.lowS1_q25#c.evt_p0_ann

    scalar low_2004_b_`y' = r(estimate)
    scalar low_2004_p_`y' = r(p)


    *===========================================================================
    * POST-TREATMENT TOTAL EFFECT — 2006
    *===========================================================================

    lincom ///
        evt_p2_ann ///
        + 1.lowS1_q25#c.evt_p2_ann

    scalar low_2006_b_`y' = r(estimate)
    scalar low_2006_p_`y' = r(p)


    *===========================================================================
    * POST-TREATMENT TOTAL EFFECT — 2009
    *===========================================================================

    lincom ///
        evt_p5_ann ///
        + 1.lowS1_q25#c.evt_p5_ann

    scalar low_2009_b_`y' = r(estimate)
    scalar low_2009_p_`y' = r(p)


    *===========================================================================
    * POST-TREATMENT TOTAL EFFECT — 2011
    *===========================================================================

    lincom ///
        evt_p7_ann ///
        + 1.lowS1_q25#c.evt_p7_ann

    scalar low_2011_b_`y' = r(estimate)
    scalar low_2011_p_`y' = r(p)
}


*===============================================================================
* 11. EVENT-STUDY TABLE
*===============================================================================

esttab ///
    ES_kcal ///
    ES_carbo ///
    ES_fat ///
    ES_protn, ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.lowS1_q25#c.evt_m7_ann ///
        1.lowS1_q25#c.evt_p0_ann ///
        1.lowS1_q25#c.evt_p2_ann ///
        1.lowS1_q25#c.evt_p5_ann ///
        1.lowS1_q25#c.evt_p7_ann ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneous event study" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Baseline calorie group based on 1997 and 2000 only", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 12. SAVE EVENT-STUDY TABLE
*===============================================================================

esttab ///
    ES_kcal ///
    ES_carbo ///
    ES_fat ///
    ES_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_table_02.rtf", ///
    replace ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.lowS1_q25#c.evt_m7_ann ///
        1.lowS1_q25#c.evt_p0_ann ///
        1.lowS1_q25#c.evt_p2_ann ///
        1.lowS1_q25#c.evt_p5_ann ///
        1.lowS1_q25#c.evt_p7_ann ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneous event study" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Baseline calorie group based on 1997 and 2000 only", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    ES_kcal ///
    ES_carbo ///
    ES_fat ///
    ES_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_table_02.csv", ///
    replace ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.lowS1_q25#c.evt_m7_ann ///
        1.lowS1_q25#c.evt_p0_ann ///
        1.lowS1_q25#c.evt_p2_ann ///
        1.lowS1_q25#c.evt_p5_ann ///
        1.lowS1_q25#c.evt_p7_ann ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01)


*===============================================================================
* 13. PRE-TREND DIAGNOSTIC SUMMARY
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "HETEROGENEITY PRE-TREND DIAGNOSTICS"

display as text ///
    "Reference year = 2000"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Non-low group p       = " ///
        %9.4f scalar(pre_main_`y')

    display as text ///
        "Differential p        = " ///
        %9.4f scalar(pre_diff_`y')

    display as text ///
        "Low-calorie coef      = " ///
        %9.4f scalar(pre_low_b_`y')

    display as text ///
        "Low-calorie p         = " ///
        %9.4f scalar(pre_low_p_`y')
}


display as text ///
    "============================================================"


*===============================================================================
* 14. LOW-CALORIE EVENT-STUDY TOTAL EFFECTS
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "LOW-CALORIE TOTAL EVENT-STUDY EFFECTS"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "2004 = " ///
        %9.4f scalar(low_2004_b_`y') ///
        "   p = " ///
        %9.4f scalar(low_2004_p_`y')

    display as text ///
        "2006 = " ///
        %9.4f scalar(low_2006_b_`y') ///
        "   p = " ///
        %9.4f scalar(low_2006_p_`y')

    display as text ///
        "2009 = " ///
        %9.4f scalar(low_2009_b_`y') ///
        "   p = " ///
        %9.4f scalar(low_2009_p_`y')

    display as text ///
        "2011 = " ///
        %9.4f scalar(low_2011_b_`y') ///
        "   p = " ///
        %9.4f scalar(low_2011_p_`y')
}


display as text ///
    "============================================================"




    

*===============================================================================
* END OF analyses/03_kcal_heterogeneity.do
*===============================================================================