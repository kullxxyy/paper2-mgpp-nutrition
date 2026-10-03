*===============================================================================
* PAPER 2 — BASELINE-CALORIE HETEROGENEITY (FULLY SATURATED DDD)
* File: analyses/03_kcal_heterogeneity.do
*
* Treated province : Hunan   (43)
* Control province : Guizhou (52)
*
* Policy timing
*   1997 = clean pre-treatment
*   2000 = omitted reference / last clean pre-treatment wave
*   2004 = policy announcement / treatment onset
*   2006 = post
*   2009 = post
*   2011 = post
*
* Sample
*   Hunan + Guizhou pure consumers only
*
* Heterogeneity
*   Baseline low-calorie status comes from prep/05_baseline_groups.do.
*   It is anchored to each individual's pre-policy household:
*       2000 household if available;
*       otherwise 1997 household.
*
* IMPORTANT:
*   A valid DDD with individual FE and wave FE must include:
*
*       Hunan x Post
*       Low    x Post
*       Hunan x Low x Post
*
*   The Low x Post lower-order interaction cannot be omitted.
*
* Dynamic DDD similarly includes, for every event year:
*
*       Hunan x Year
*       Low   x Year
*       Hunan x Low x Year
*
*   with 2000 omitted as the reference year.
*
* Main specification:
*   individual FE + wave FE, no contemporaneous controls.
*
* Controlled specification:
*   RD1 controls included only as robustness.
*===============================================================================


*===============================================================================
* 0. SETTINGS
*===============================================================================

local outcomes kcal carbo fat protn

* Robustness controls only.
local RD1 ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


*===============================================================================
* 1. DEFINE HUNAN-GUIZHOU ANALYSIS POPULATION
*===============================================================================

capture drop sample_hg
capture drop treated_hg

capture confirm variable t1

if !_rc {

    gen byte sample_hg = inlist(t1, 43, 52)

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

    gen byte sample_hg = inlist(province_code, 43, 52)

    gen byte treated_hg = ///
        (province_code == 43) ///
        if sample_hg == 1
}

label define hg_treat ///
    0 "Guizhou" ///
    1 "Hunan", ///
    replace

label values treated_hg hg_treat

label variable sample_hg ///
    "Hunan-Guizhou analysis population"

label variable treated_hg ///
    "Hunan treatment indicator"


capture confirm variable consumer_base

if _rc {
    display as error ///
        "consumer_base not found. Run the pure-consumer preparation first."
    exit 111
}


*===============================================================================
* 2. POLICY TIMING VARIABLES
*===============================================================================

capture drop post_ann
capture drop did_ann

capture drop evt_m7_ann
capture drop evt_p0_ann
capture drop evt_p2_ann
capture drop evt_p5_ann
capture drop evt_p7_ann


* Common post indicator for BOTH provinces.
gen byte post_ann = ///
    wave >= 2004 ///
    if sample_hg == 1


* Hunan x Post.
gen byte did_ann = ///
    treated_hg * post_ann ///
    if sample_hg == 1


* Hunan x event-year indicators.
* 2000 is omitted/reference.

gen byte evt_m7_ann = ///
    treated_hg * (wave == 1997) ///
    if sample_hg == 1

gen byte evt_p0_ann = ///
    treated_hg * (wave == 2004) ///
    if sample_hg == 1

gen byte evt_p2_ann = ///
    treated_hg * (wave == 2006) ///
    if sample_hg == 1

gen byte evt_p5_ann = ///
    treated_hg * (wave == 2009) ///
    if sample_hg == 1

gen byte evt_p7_ann = ///
    treated_hg * (wave == 2011) ///
    if sample_hg == 1


label variable post_ann ///
    "Post-2004 announcement indicator"

label variable did_ann ///
    "Hunan x Post"


*===============================================================================
* 3. LOAD BASELINE GROUP FROM prep/05_baseline_groups.do
*
* Do NOT reconstruct baseline quartiles here.
* prep/05_baseline_groups.do is the single source of truth.
*===============================================================================

foreach v in pre_kcal_hh qkcal_hh lowS1_q25 {

    capture confirm variable `v'

    if _rc {
        display as error ///
            "`v' not found. Run prep/05_baseline_groups.do first."
        exit 111
    }
}


*===============================================================================
* 4. FIX BASELINE GROUP AT THE INDIVIDUAL LEVEL
*
* Anchor:
*   2000 household if available;
*   otherwise 1997 household.
*===============================================================================

capture drop lowS_at_2000
capture drop lowS_at_1997
capture drop lowS1_q25_fixed


bysort IDind: egen lowS_at_2000 = max( ///
    cond( ///
        wave == 2000 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lowS1_q25), ///
        lowS1_q25, ///
        . ///
    ) ///
)


bysort IDind: egen lowS_at_1997 = max( ///
    cond( ///
        wave == 1997 ///
        & sample_hg == 1 ///
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
    "Fixed baseline low-calorie status"


drop lowS_at_2000 lowS_at_1997


*===============================================================================
* 5. VERIFY TIME-INVARIANCE
*===============================================================================

capture drop lowS_fixed_min
capture drop lowS_fixed_max

bysort IDind: egen lowS_fixed_min = min(lowS1_q25_fixed)
bysort IDind: egen lowS_fixed_max = max(lowS1_q25_fixed)

quietly count ///
    if lowS_fixed_min != lowS_fixed_max ///
    & !missing(lowS_fixed_min, lowS_fixed_max)

local n_switch_fixed = r(N)

display as text ///
    "============================================================"

display as text ///
    "FIXED BASELINE-GROUP CHECK"

display as text ///
    "Individuals whose fixed group changes across waves = " ///
    `n_switch_fixed'

display as text ///
    "============================================================"


if `n_switch_fixed' > 0 {
    display as error ///
        "ERROR: lowS1_q25_fixed is not time-invariant."
    exit 459
}


drop lowS_fixed_min lowS_fixed_max


*===============================================================================
* 6. FINAL HETEROGENEITY SAMPLE
*===============================================================================

capture drop sample_hetero

gen byte sample_hetero = ///
    sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(lowS1_q25_fixed)


label variable sample_hetero ///
    "Hunan-Guizhou pure consumers with fixed baseline group"


display as text ///
    "============================================================"

display as text ///
    "FINAL HETEROGENEITY SAMPLE"

display as text ///
    "============================================================"


tab lowS1_q25_fixed ///
    if sample_hetero == 1, ///
    missing


tab lowS1_q25_fixed treated_hg ///
    if sample_hetero == 1, ///
    column


capture drop tag_hetero

egen tag_hetero = tag(IDind) ///
    if sample_hetero == 1

quietly count ///
    if tag_hetero == 1

display as text ///
    "Unique individuals = " ///
    r(N)


*===============================================================================
* 7. CREATE ALL LOWER-ORDER AND TRIPLE INTERACTIONS FOR DDD
*
* Average DDD:
*
*   did_ann      = Hunan x Post
*   low_post_ann = Low   x Post
*   ddd_ann      = Hunan x Low x Post
*
* With individual FE:
*   Hunan, Low, and Hunan x Low are absorbed.
*
* With wave FE:
*   Post is absorbed.
*
* Therefore these three time-varying interaction terms are the required
* non-collinear components of the fully saturated DDD.
*===============================================================================

capture drop low_post_ann
capture drop ddd_ann


gen byte low_post_ann = ///
    lowS1_q25_fixed * post_ann ///
    if sample_hetero == 1


gen byte ddd_ann = ///
    treated_hg * lowS1_q25_fixed * post_ann ///
    if sample_hetero == 1


label variable low_post_ann ///
    "Low baseline calories x Post"

label variable ddd_ann ///
    "DDD: Hunan x Low x Post"


*===============================================================================
* 8. CREATE EVENT-STUDY LOWER-ORDER AND TRIPLE INTERACTIONS
*
* For every event year relative to 2000:
*
*   Hunan x Year
*   Low   x Year
*   Hunan x Low x Year
*
* 2000 is omitted.
*===============================================================================

foreach v in ///
    low_evt_m7 ///
    low_evt_p0 ///
    low_evt_p2 ///
    low_evt_p5 ///
    low_evt_p7 ///
    ddd_evt_m7 ///
    ddd_evt_p0 ///
    ddd_evt_p2 ///
    ddd_evt_p5 ///
    ddd_evt_p7 {

    capture drop `v'
}


* Low x Year.
gen byte low_evt_m7 = ///
    lowS1_q25_fixed * (wave == 1997) ///
    if sample_hetero == 1

gen byte low_evt_p0 = ///
    lowS1_q25_fixed * (wave == 2004) ///
    if sample_hetero == 1

gen byte low_evt_p2 = ///
    lowS1_q25_fixed * (wave == 2006) ///
    if sample_hetero == 1

gen byte low_evt_p5 = ///
    lowS1_q25_fixed * (wave == 2009) ///
    if sample_hetero == 1

gen byte low_evt_p7 = ///
    lowS1_q25_fixed * (wave == 2011) ///
    if sample_hetero == 1


* Hunan x Low x Year.
gen byte ddd_evt_m7 = ///
    treated_hg * lowS1_q25_fixed * (wave == 1997) ///
    if sample_hetero == 1

gen byte ddd_evt_p0 = ///
    treated_hg * lowS1_q25_fixed * (wave == 2004) ///
    if sample_hetero == 1

gen byte ddd_evt_p2 = ///
    treated_hg * lowS1_q25_fixed * (wave == 2006) ///
    if sample_hetero == 1

gen byte ddd_evt_p5 = ///
    treated_hg * lowS1_q25_fixed * (wave == 2009) ///
    if sample_hetero == 1

gen byte ddd_evt_p7 = ///
    treated_hg * lowS1_q25_fixed * (wave == 2011) ///
    if sample_hetero == 1


label variable ddd_evt_m7 ///
    "DDD differential: 1997"

label variable ddd_evt_p0 ///
    "DDD differential: 2004"

label variable ddd_evt_p2 ///
    "DDD differential: 2006"

label variable ddd_evt_p5 ///
    "DDD differential: 2009"

label variable ddd_evt_p7 ///
    "DDD differential: 2011"


*===============================================================================
* 9. PREFERRED MAIN SPECIFICATION — FULLY SATURATED AVERAGE DDD
*
* Coefficients:
*
*   did_ann
*       = Hunan-vs-Guizhou post change among non-low consumers
*
*   low_post_ann
*       = common low-vs-nonlow post change in Guizhou
*
*   ddd_ann
*       = DDD:
*         additional Hunan post change for low consumers
*         relative to non-low consumers and relative to Guizhou
*
* ddd_ann is the main heterogeneity estimand.
*===============================================================================

eststo clear


foreach y of local outcomes {

    display as text ///
        "============================================================"

    display as text ///
        "MAIN FULL DDD — NO CONTROLS: `y'"

    display as text ///
        "============================================================"


    reghdfe lnd3`y' ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
        if sample_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo MAIN_DID_`y'


    test ddd_ann

    scalar main_ddd_b_`y'  = _b[ddd_ann]
    scalar main_ddd_se_`y' = _se[ddd_ann]
    scalar main_ddd_p_`y'  = r(p)


    * Supplementary: total Hunan-vs-Guizhou DID for the low group.
    * This equals DID(non-low) + DDD.
    lincom ///
        did_ann ///
        + ddd_ann

    scalar main_low_did_b_`y' = r(estimate)
    scalar main_low_did_p_`y' = r(p)


    display as text ///
        "DDD (`y') = " ///
        %9.4f scalar(main_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(main_ddd_p_`y')


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_MAIN_DID_`y'.ster", ///
        replace
}


*===============================================================================
* 10. MAIN AVERAGE DDD TABLE
*===============================================================================

esttab ///
    MAIN_DID_kcal ///
    MAIN_DID_carbo ///
    MAIN_DID_fat ///
    MAIN_DID_protn, ///
    keep( ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
    ) ///
    order( ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
    ) ///
    coeflabels( ///
        did_ann ///
            "Hunan x Post" ///
        low_post_ann ///
            "Low calorie x Post" ///
        ddd_ann ///
            "Hunan x Low calorie x Post (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: fully saturated DDD" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Low group fixed to pre-policy household", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    MAIN_DID_kcal ///
    MAIN_DID_carbo ///
    MAIN_DID_fat ///
    MAIN_DID_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_main_DDD.rtf", ///
    replace ///
    keep( ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
    ) ///
    order( ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
    ) ///
    coeflabels( ///
        did_ann ///
            "Hunan x Post" ///
        low_post_ann ///
            "Low calorie x Post" ///
        ddd_ann ///
            "Hunan x Low calorie x Post (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: fully saturated DDD" ///
    ) ///
    addnotes( ///
        "Sample: Hunan and Guizhou pure consumers", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    MAIN_DID_kcal ///
    MAIN_DID_carbo ///
    MAIN_DID_fat ///
    MAIN_DID_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_main_DDD.csv", ///
    replace ///
    keep( ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01)


*===============================================================================
* 11. PREFERRED MAIN DYNAMIC DDD EVENT STUDY
*
* Correct dynamic DDD specification includes:
*
*   Hunan x Year
*   Low   x Year
*   Hunan x Low x Year
*
* for 1997, 2004, 2006, 2009, 2011.
*
* 2000 is omitted.
*
* MAIN PRETREND TEST:
*   ddd_evt_m7 = 0
*===============================================================================

eststo clear


foreach y of local outcomes {

    display as text ///
        "============================================================"

    display as text ///
        "MAIN FULL DDD EVENT STUDY: `y'"

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
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
        if sample_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo MAIN_ES_`y'


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_MAIN_ES_`y'.ster", ///
        replace


    *---------------------------------------------------------------------------
    * A. Non-low Hunan-vs-Guizhou pretrend
    *---------------------------------------------------------------------------

    test evt_m7_ann

    scalar main_pre_nonlow_b_`y' = _b[evt_m7_ann]
    scalar main_pre_nonlow_p_`y' = r(p)


    *---------------------------------------------------------------------------
    * B. MAIN DDD PRETREND
    *
    * Tests whether the low-vs-nonlow Hunan-Guizhou gap was already
    * changing between 1997 and the 2000 reference period.
    *---------------------------------------------------------------------------

    test ddd_evt_m7

    scalar main_pre_diff_b_`y' = _b[ddd_evt_m7]
    scalar main_pre_diff_p_`y' = r(p)


    *---------------------------------------------------------------------------
    * C. Low-group Hunan-vs-Guizhou pretrend — supplementary
    *---------------------------------------------------------------------------

    lincom ///
        evt_m7_ann ///
        + ddd_evt_m7

    scalar main_pre_low_b_`y' = r(estimate)
    scalar main_pre_low_p_`y' = r(p)


    * Store post-treatment DDD coefficients.
    scalar main_ddd_2004_b_`y' = _b[ddd_evt_p0]
    scalar main_ddd_2006_b_`y' = _b[ddd_evt_p2]
    scalar main_ddd_2009_b_`y' = _b[ddd_evt_p5]
    scalar main_ddd_2011_b_`y' = _b[ddd_evt_p7]


    display as text ///
        "DDD pretrend (`y') = " ///
        %9.4f scalar(main_pre_diff_b_`y') ///
        "   p = " ///
        %9.4f scalar(main_pre_diff_p_`y')
}


*===============================================================================
* 12. MAIN DYNAMIC DDD TABLE
*===============================================================================

esttab ///
    MAIN_ES_kcal ///
    MAIN_ES_carbo ///
    MAIN_ES_fat ///
    MAIN_ES_protn, ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
    ) ///
    order( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
    ) ///
    coeflabels( ///
        evt_m7_ann "Hunan x 1997" ///
        evt_p0_ann "Hunan x 2004" ///
        evt_p2_ann "Hunan x 2006" ///
        evt_p5_ann "Hunan x 2009" ///
        evt_p7_ann "Hunan x 2011" ///
        low_evt_m7 "Low x 1997" ///
        low_evt_p0 "Low x 2004" ///
        low_evt_p2 "Low x 2006" ///
        low_evt_p5 "Low x 2009" ///
        low_evt_p7 "Low x 2011" ///
        ddd_evt_m7 "DDD: 1997" ///
        ddd_evt_p0 "DDD: 2004" ///
        ddd_evt_p2 "DDD: 2006" ///
        ddd_evt_p5 "DDD: 2009" ///
        ddd_evt_p7 "DDD: 2011" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie dynamic DDD" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    MAIN_ES_kcal ///
    MAIN_ES_carbo ///
    MAIN_ES_fat ///
    MAIN_ES_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_main_event.rtf", ///
    replace ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie dynamic DDD" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "Standard errors clustered at community level" ///
    )


esttab ///
    MAIN_ES_kcal ///
    MAIN_ES_carbo ///
    MAIN_ES_fat ///
    MAIN_ES_protn ///
    using "$P2_TABLES/03_kcal_heterogeneity_main_event.csv", ///
    replace ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01)


*===============================================================================
* 13. MAIN DDD PRETREND SUMMARY
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "MAIN DDD PRETREND SUMMARY — FULLY SATURATED, NO CONTROLS"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Non-low pretrend coef  = " ///
        %9.4f scalar(main_pre_nonlow_b_`y')

    display as text ///
        "Non-low pretrend p     = " ///
        %9.4f scalar(main_pre_nonlow_p_`y')

    display as text ///
        "DDD pretrend coef      = " ///
        %9.4f scalar(main_pre_diff_b_`y')

    display as text ///
        "DDD differential p     = " ///
        %9.4f scalar(main_pre_diff_p_`y')

    display as text ///
        "Low-group pretrend p   = " ///
        %9.4f scalar(main_pre_low_p_`y')
}


display as text ///
    "============================================================"


*===============================================================================
* 14. CONTROLLED ROBUSTNESS — FULLY SATURATED AVERAGE DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        low_post_ann ///
        ddd_ann ///
        `RD1' ///
        if sample_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo CTRL_DID_`y'


    test ddd_ann

    scalar ctrl_ddd_b_`y' = _b[ddd_ann]
    scalar ctrl_ddd_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_CTRL_DID_`y'.ster", ///
        replace
}


*===============================================================================
* 15. CONTROLLED ROBUSTNESS — FULL DYNAMIC DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        low_evt_m7 ///
        low_evt_p0 ///
        low_evt_p2 ///
        low_evt_p5 ///
        low_evt_p7 ///
        ddd_evt_m7 ///
        ddd_evt_p0 ///
        ddd_evt_p2 ///
        ddd_evt_p5 ///
        ddd_evt_p7 ///
        `RD1' ///
        if sample_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo CTRL_ES_`y'


    test ddd_evt_m7

    scalar ctrl_pre_diff_b_`y' = _b[ddd_evt_m7]
    scalar ctrl_pre_diff_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/03_kcal_heterogeneity_CTRL_ES_`y'.ster", ///
        replace
}


*===============================================================================
* 16. MAIN VS CONTROLLED SUMMARY
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "MAIN VS CONTROLLED — FULL DDD"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Main DDD coef          = " ///
        %9.4f scalar(main_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(main_ddd_p_`y')

    display as text ///
        "Controlled DDD coef    = " ///
        %9.4f scalar(ctrl_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(ctrl_ddd_p_`y')

    display as text ///
        "Main DDD pretrend p    = " ///
        %9.4f scalar(main_pre_diff_p_`y')

    display as text ///
        "Controlled pretrend p  = " ///
        %9.4f scalar(ctrl_pre_diff_p_`y')
}


display as text ///
    "============================================================"


*===============================================================================
* 17. INTERPRETATION
*
* MAIN HETEROGENEITY ESTIMAND
*   ddd_ann
*
* It measures:
*
*   [Hunan low - Hunan non-low] post-pre change
*   minus
*   [Guizhou low - Guizhou non-low] post-pre change.
*
* MAIN DDD PRETREND TEST
*   ddd_evt_m7
*
* A statistically insignificant ddd_evt_m7 means the data do not reject
* equality of the low-vs-nonlow Hunan-Guizhou differential trend between
* 1997 and the 2000 reference period.
*
* Because there is only one clean pre-treatment lead, this remains a limited
* pretrend diagnostic rather than proof of the identifying assumption.
*===============================================================================


*===============================================================================
* END OF analyses/03_kcal_heterogeneity.do
*===============================================================================


