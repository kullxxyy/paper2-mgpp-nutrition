*===============================================================================
* PART 15 — PRE-PERIOD BALANCED DDD ROBUSTNESS
*
* Requirements:
*   - Hunan / Guizhou only
*   - pure consumers only
*   - same individual must have outcome observed in BOTH 1997 and 2000
*   - post-treatment waves are NOT required for sample inclusion
*
* Baseline low-calorie quartile is REDEFINED within this robustness sample.
*
* Main parameter:
*   did_ann x low baseline calorie
*
* Main pretrend diagnostic:
*   low calorie x evt_m7_ann
*===============================================================================


local outcomes kcal carbo fat protn

local RD1 ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


*-------------------------------------------------------------------------------
* 15.1 Check that main variables already exist
*-------------------------------------------------------------------------------

foreach v in ///
    sample_hg treated_hg consumer_base ///
    did_ann ///
    evt_m7_ann evt_p0_ann evt_p2_ann evt_p5_ann evt_p7_ann ///
    pre_kcal_hh {

    capture confirm variable `v'

    if _rc {
        display as error ///
            "Required variable `v' not found. Run Parts 1-14 first."
        exit 111
    }
}


*-------------------------------------------------------------------------------
* 15.2 Construct outcome-specific 1997/2000 balanced flags
*-------------------------------------------------------------------------------

foreach y of local outcomes {

    capture drop ///
        pb_has97_`y' ///
        pb_has00_`y' ///
        prebal2_`y'


    * 1997 outcome observed
    bysort IDind: egen pb_has97_`y' = max( ///
        wave == 1997 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    * 2000 outcome observed
    bysort IDind: egen pb_has00_`y' = max( ///
        wave == 2000 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    * Must be observed in BOTH clean pre-treatment waves
    gen byte prebal2_`y' = ///
        pb_has97_`y' == 1 ///
        & pb_has00_`y' == 1


    label variable prebal2_`y' ///
        "`y': observed in both 1997 and 2000"
}


*-------------------------------------------------------------------------------
* 15.3 Reconstruct bottom-quarter calorie group
*      separately within each outcome-specific balanced sample
*-------------------------------------------------------------------------------

foreach y of local outcomes {

    capture drop ///
        qkcal_prebal_`y' ///
        lowS_prebal_q25_`y'


    preserve

        keep if ///
            sample_hg == 1 ///
            & consumer_base == 1 ///
            & prebal2_`y' == 1 ///
            & !missing(pre_kcal_hh)


        * One observation per household
        keep hhid pre_kcal_hh

        bysort hhid: keep if _n == 1

        isid hhid


        * Bottom quartile within pre-balanced sample
        xtile qkcal_prebal_`y' = pre_kcal_hh, nq(4)

        gen byte lowS_prebal_q25_`y' = ///
            (qkcal_prebal_`y' == 1)


        keep ///
            hhid ///
            qkcal_prebal_`y' ///
            lowS_prebal_q25_`y'


        tempfile prebal_group
        save `prebal_group'

    restore


    merge m:1 hhid using `prebal_group', ///
        nogen ///
        keep(master match)


    label variable lowS_prebal_q25_`y' ///
        "`y': bottom 25% calories, 1997/2000 balanced sample"
}


*-------------------------------------------------------------------------------
* 15.4 Sample-size diagnostics
*-------------------------------------------------------------------------------

display as text ///
    "============================================================"

display as text ///
    "PRE-PERIOD BALANCED DDD SAMPLE COUNTS"

display as text ///
    "============================================================"


foreach y of local outcomes {

    capture drop tag_prebal_`y'

    egen tag_prebal_`y' = tag(IDind) ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & prebal2_`y' == 1 ///
        & !missing(lowS_prebal_q25_`y')


    quietly count if tag_prebal_`y' == 1

    display as text ///
        "`y' individuals = " r(N)


    tab lowS_prebal_q25_`y' treated_hg ///
        if tag_prebal_`y' == 1, ///
        column
}


*===============================================================================
* 15.5 PRE-PERIOD BALANCED — AVERAGE DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    local g lowS_prebal_q25_`y'


    display as text ///
        "============================================================"

    display as text ///
        "PRE-BALANCED AVERAGE DDD: `y'"

    display as text ///
        "============================================================"


    reghdfe lnd3`y' ///
        i.did_ann##i.`g' ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & prebal2_`y' == 1 ///
        & !missing(`g'), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo PB_DID_`y'


    * Differential DDD effect
    test ///
        1.did_ann#1.`g'

    scalar pb_ddd_p_`y' = r(p)


    * Total low-calorie DID effect
    lincom ///
        1.did_ann ///
        + 1.did_ann#1.`g'

    scalar pb_low_did_b_`y' = r(estimate)
    scalar pb_low_did_p_`y' = r(p)


    display as text ///
        "DDD interaction p-value = " ///
        %9.4f scalar(pb_ddd_p_`y')

    display as text ///
        "Low-calorie total DID = " ///
        %9.4f scalar(pb_low_did_b_`y')

    display as text ///
        "Low-calorie total DID p = " ///
        %9.4f scalar(pb_low_did_p_`y')
}


*===============================================================================
* 15.6 PRE-PERIOD BALANCED — EVENT-STUDY DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    local g lowS_prebal_q25_`y'


    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.`g'#c.evt_m7_ann ///
        1.`g'#c.evt_p0_ann ///
        1.`g'#c.evt_p2_ann ///
        1.`g'#c.evt_p5_ann ///
        1.`g'#c.evt_p7_ann ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & prebal2_`y' == 1 ///
        & !missing(`g'), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo PB_ES_`y'


    *-----------------------------------------------------------
    * Most important DDD pretrend test
    *
    * H0:
    * differential Hunan-vs-Guizhou pretrend between
    * low and non-low calorie groups = 0
    *-----------------------------------------------------------

    test ///
        1.`g'#c.evt_m7_ann

    scalar pb_pre_diff_`y' = r(p)


    *-----------------------------------------------------------
    * Non-low calorie pretrend
    *-----------------------------------------------------------

    test evt_m7_ann

    scalar pb_pre_main_`y' = r(p)


    *-----------------------------------------------------------
    * Total pretrend for low-calorie group
    *-----------------------------------------------------------

    lincom ///
        evt_m7_ann ///
        + 1.`g'#c.evt_m7_ann

    scalar pb_pre_low_b_`y' = r(estimate)
    scalar pb_pre_low_p_`y' = r(p)


    display as text ///
        "PRE-BAL `y' differential pretrend p = " ///
        %9.4f scalar(pb_pre_diff_`y')
}


*-------------------------------------------------------------------------------
* 15.7 Pre-balanced DDD pretrend summary
*-------------------------------------------------------------------------------

display as text ///
    "============================================================"

display as text ///
    "PRE-PERIOD BALANCED DDD PRETREND SUMMARY"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Non-low pretrend p    = " ///
        %9.4f scalar(pb_pre_main_`y')

    display as text ///
        "DDD differential p    = " ///
        %9.4f scalar(pb_pre_diff_`y')

    display as text ///
        "Low-group pre coef    = " ///
        %9.4f scalar(pb_pre_low_b_`y')

    display as text ///
        "Low-group pre p       = " ///
        %9.4f scalar(pb_pre_low_p_`y')
}


display as text ///
    "============================================================"


*-------------------------------------------------------------------------------
* 15.8 Pre-balanced DDD table
*-------------------------------------------------------------------------------

esttab ///
    PB_ES_kcal ///
    PB_ES_carbo ///
    PB_ES_fat ///
    PB_ES_protn, ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Pre-period balanced DDD event study" ///
    ) ///
    addnotes( ///
        "Individuals must be observed in both 1997 and 2000", ///
        "No post-treatment observation is required for sample inclusion", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* PART 16 — SIX-WAVE BALANCED DDD ROBUSTNESS
*
* Requires outcome observed in:
*   1997 / 2000 / 2004 / 2006 / 2009 / 2011
*
* IMPORTANT:
*   This uses post-treatment panel retention to define the sample.
*   Therefore this is ROBUSTNESS ONLY, not the main identifying sample.
*
* Balance is defined on outcome availability.
* Controls can still reduce the actual regression sample if controls are missing.
*===============================================================================


*-------------------------------------------------------------------------------
* 16.1 Construct six-wave balanced flags
*-------------------------------------------------------------------------------

foreach y of local outcomes {

    capture drop ///
        sw97_`y' ///
        sw00_`y' ///
        sw04_`y' ///
        sw06_`y' ///
        sw09_`y' ///
        sw11_`y' ///
        balanced6_`y'


    bysort IDind: egen sw97_`y' = max( ///
        wave == 1997 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    bysort IDind: egen sw00_`y' = max( ///
        wave == 2000 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    bysort IDind: egen sw04_`y' = max( ///
        wave == 2004 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    bysort IDind: egen sw06_`y' = max( ///
        wave == 2006 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    bysort IDind: egen sw09_`y' = max( ///
        wave == 2009 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    bysort IDind: egen sw11_`y' = max( ///
        wave == 2011 ///
        & sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y') ///
    )


    gen byte balanced6_`y' = ///
        sw97_`y' == 1 ///
        & sw00_`y' == 1 ///
        & sw04_`y' == 1 ///
        & sw06_`y' == 1 ///
        & sw09_`y' == 1 ///
        & sw11_`y' == 1


    label variable balanced6_`y' ///
        "`y': outcome observed in all six waves"
}


*-------------------------------------------------------------------------------
* 16.2 Redefine low-calorie quartile within six-wave sample
*-------------------------------------------------------------------------------

foreach y of local outcomes {

    capture drop ///
        qkcal_bal6_`y' ///
        lowS_bal6_q25_`y'


    preserve

        keep if ///
            sample_hg == 1 ///
            & consumer_base == 1 ///
            & balanced6_`y' == 1 ///
            & !missing(pre_kcal_hh)


        keep hhid pre_kcal_hh

        bysort hhid: keep if _n == 1

        isid hhid


        xtile qkcal_bal6_`y' = pre_kcal_hh, nq(4)

        gen byte lowS_bal6_q25_`y' = ///
            (qkcal_bal6_`y' == 1)


        keep ///
            hhid ///
            qkcal_bal6_`y' ///
            lowS_bal6_q25_`y'


        tempfile bal6_group
        save `bal6_group'

    restore


    merge m:1 hhid using `bal6_group', ///
        nogen ///
        keep(master match)


    label variable lowS_bal6_q25_`y' ///
        "`y': bottom 25% calories, six-wave balanced sample"
}


*-------------------------------------------------------------------------------
* 16.3 Six-wave sample counts
*-------------------------------------------------------------------------------

display as text ///
    "============================================================"

display as text ///
    "SIX-WAVE BALANCED DDD SAMPLE COUNTS"

display as text ///
    "============================================================"


foreach y of local outcomes {

    capture drop tag_bal6_`y'

    egen tag_bal6_`y' = tag(IDind) ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & balanced6_`y' == 1 ///
        & !missing(lowS_bal6_q25_`y')


    quietly count if tag_bal6_`y' == 1


    display as text ///
        "`y' individuals = " r(N)


    quietly count ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & balanced6_`y' == 1 ///
        & !missing(lowS_bal6_q25_`y')


    display as text ///
        "`y' person-wave observations before regression = " r(N)
}


*===============================================================================
* 16.4 SIX-WAVE BALANCED — AVERAGE DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    local g lowS_bal6_q25_`y'


    display as text ///
        "============================================================"

    display as text ///
        "SIX-WAVE BALANCED AVERAGE DDD: `y'"

    display as text ///
        "============================================================"


    reghdfe lnd3`y' ///
        i.did_ann##i.`g' ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & balanced6_`y' == 1 ///
        & !missing(`g'), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo B6_DID_`y'


    * DDD interaction
    test ///
        1.did_ann#1.`g'

    scalar b6_ddd_p_`y' = r(p)


    * Total low-calorie DID
    lincom ///
        1.did_ann ///
        + 1.did_ann#1.`g'

    scalar b6_low_did_b_`y' = r(estimate)
    scalar b6_low_did_p_`y' = r(p)
}


*===============================================================================
* 16.5 SIX-WAVE BALANCED — EVENT-STUDY DDD
*===============================================================================

eststo clear


foreach y of local outcomes {

    local g lowS_bal6_q25_`y'


    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        1.`g'#c.evt_m7_ann ///
        1.`g'#c.evt_p0_ann ///
        1.`g'#c.evt_p2_ann ///
        1.`g'#c.evt_p5_ann ///
        1.`g'#c.evt_p7_ann ///
        `RD1' ///
        if sample_hg == 1 ///
        & consumer_base == 1 ///
        & balanced6_`y' == 1 ///
        & !missing(`g'), ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)


    eststo B6_ES_`y'


    *-----------------------------------------------------------
    * Key DDD pretrend
    *-----------------------------------------------------------

    test ///
        1.`g'#c.evt_m7_ann

    scalar b6_pre_diff_`y' = r(p)


    * Non-low pretrend
    test evt_m7_ann

    scalar b6_pre_main_`y' = r(p)


    * Total low-calorie pretrend
    lincom ///
        evt_m7_ann ///
        + 1.`g'#c.evt_m7_ann

    scalar b6_pre_low_b_`y' = r(estimate)
    scalar b6_pre_low_p_`y' = r(p)
}


*-------------------------------------------------------------------------------
* 16.6 Six-wave DDD pretrend summary
*-------------------------------------------------------------------------------

display as text ///
    "============================================================"

display as text ///
    "SIX-WAVE BALANCED DDD PRETREND SUMMARY"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Non-low pretrend p    = " ///
        %9.4f scalar(b6_pre_main_`y')

    display as text ///
        "DDD differential p    = " ///
        %9.4f scalar(b6_pre_diff_`y')

    display as text ///
        "Low-group pre coef    = " ///
        %9.4f scalar(b6_pre_low_b_`y')

    display as text ///
        "Low-group pre p       = " ///
        %9.4f scalar(b6_pre_low_p_`y')
}


display as text ///
    "============================================================"


*-------------------------------------------------------------------------------
* 16.7 Six-wave balanced event-study table
*-------------------------------------------------------------------------------

esttab ///
    B6_ES_kcal ///
    B6_ES_carbo ///
    B6_ES_fat ///
    B6_ES_protn, ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Six-wave balanced DDD event study" ///
    ) ///
    addnotes( ///
        "Outcome must be observed in all six waves", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004", ///
        "Six-wave balancing is a robustness check only", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* PART 17 — SIDE-BY-SIDE PRETREND SUMMARY
*
* Most important column for DDD:
*   differential pretrend p-value
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "DDD DIFFERENTIAL PRETREND COMPARISON"

display as text ///
    "============================================================"


foreach y of local outcomes {

    display as text ///
        "----- `y' -----"

    display as text ///
        "Pre-period balanced p = " ///
        %9.4f scalar(pb_pre_diff_`y')

    display as text ///
        "Six-wave balanced p   = " ///
        %9.4f scalar(b6_pre_diff_`y')
}


display as text ///
    "============================================================"


*===============================================================================
* END OF BALANCED-PANEL DDD ROBUSTNESS
*===============================================================================