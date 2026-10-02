*===============================================================================
* PAPER 2 — NUTRITION EVENT STUDY AND AVERAGE DID
* File: analyses/02_nutrition_main.do
*
* Main sample:
*   consumer_base == 1
*
* Fixed effects:
*   Individual FE + wave FE
*
* Standard errors:
*   Clustered at harmonized community level
*===============================================================================


*===============================================================================
* 0. OUTPUT DIRECTORY
*===============================================================================

local outdir ///
    "/Users/lenovo/PhD papers/paper 2/table and figures"

capture mkdir "`outdir'"

local xlsx ///
    "`outdir'/paper2_nutrition_main_results.xlsx"


*===============================================================================
* 1. VARIABLES
*===============================================================================

local outcomes d3kcal d3carbo d3fat d3protn

* Keep this on ONE line to avoid Stata quotation/continuation errors.
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


*===============================================================================
* 2. EVENT STUDY — MAIN PURE-CONSUMER SAMPLE
*===============================================================================

eststo clear

foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7 evt_p0 evt_p2 evt_p5 evt_p7 ///
        $P2_ES_EXTRA ///
        `RD1' ///
        if consumer_base == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo ES_`y'

    estimates save ///
        "$P2_MODELS/02_nutrition_main_ES_`y'.ster", ///
        replace

    *-----------------------------------------------------------
    * Pre-trend test
    * 2000 is the omitted/reference period.
    * evt_m7 corresponds to 1997.
    *-----------------------------------------------------------

    display as text ///
        "=================================================="

    display as text ///
        "Pre-trend test: `y'"

    test evt_m7

    scalar pretrend_p_`y' = r(p)

    display as text ///
        "=================================================="
}


*===============================================================================
* 3. DISPLAY EVENT-STUDY TABLE IN STATA
*===============================================================================

esttab ///
    ES_d3kcal ///
    ES_d3carbo ///
    ES_d3fat ///
    ES_d3protn, ///
    keep(evt_*) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates: main pure-consumer sample") ///
    addnotes( ///
        "Reference period: 2000", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 4. EXPORT EVENT STUDY TO EXCEL
*===============================================================================

putexcel set "`xlsx'", ///
    sheet("EventStudy") replace


*-------------------------------------------------------------------------------
* Header
*-------------------------------------------------------------------------------

putexcel A1 = ("Paper 2: Nutrition Event Study")

putexcel A2 = ///
    ("Main sample: baseline pure-consumer proxy")

putexcel A3 = ///
    ("Individual FE + wave FE; SE clustered at community level")

putexcel A5 = ("Outcome") ///
         B5 = ("1997 coef") ///
         C5 = ("1997 SE") ///
         D5 = ("2004 coef") ///
         E5 = ("2004 SE") ///
         F5 = ("2006 coef") ///
         G5 = ("2006 SE") ///
         H5 = ("2009 coef") ///
         I5 = ("2009 SE") ///
         J5 = ("2011 coef") ///
         K5 = ("2011 SE") ///
         L5 = ("Pre-trend p") ///
         M5 = ("N")


*-------------------------------------------------------------------------------
* Fill results
*-------------------------------------------------------------------------------

local row = 6

foreach y of local outcomes {

    estimates restore ES_`y'

    local b_m7 = _b[evt_m7]
    local s_m7 = _se[evt_m7]

    local b_p0 = _b[evt_p0]
    local s_p0 = _se[evt_p0]

    local b_p2 = _b[evt_p2]
    local s_p2 = _se[evt_p2]

    local b_p5 = _b[evt_p5]
    local s_p5 = _se[evt_p5]

    local b_p7 = _b[evt_p7]
    local s_p7 = _se[evt_p7]

    local N = e(N)

    local pre_p = scalar(pretrend_p_`y')

    putexcel A`row' = ("`y'") ///
             B`row' = (`b_m7') ///
             C`row' = (`s_m7') ///
             D`row' = (`b_p0') ///
             E`row' = (`s_p0') ///
             F`row' = (`b_p2') ///
             G`row' = (`s_p2') ///
             H`row' = (`b_p5') ///
             I`row' = (`s_p5') ///
             J`row' = (`b_p7') ///
             K`row' = (`s_p7') ///
             L`row' = (`pre_p') ///
             M`row' = (`N')

    local ++row
}


*-------------------------------------------------------------------------------
* Formatting
*-------------------------------------------------------------------------------

putexcel A1:M1, bold

putexcel A5:M5, bold

putexcel B6:M9, nformat(number_d3)


*===============================================================================
* 5. EVENT-STUDY FIGURES
*===============================================================================

capture program drop draw_es

program define draw_es

    args model ttl

    preserve

    clear

    set obs 5

    gen event_time = -7 in 1
    replace event_time = 0 in 2
    replace event_time = 2 in 3
    replace event_time = 5 in 4
    replace event_time = 7 in 5

    gen coef = .
    gen se   = .

    estimates restore `model'

    matrix b = e(b)
    matrix V = e(V)

    foreach k in m7 p0 p2 p5 p7 {

        local r = ///
            cond("`k'" == "m7", 1, ///
            cond("`k'" == "p0", 2, ///
            cond("`k'" == "p2", 3, ///
            cond("`k'" == "p5", 4, 5))))

        replace coef = ///
            b[1, "evt_`k'"] ///
            in `r'

        replace se = ///
            sqrt(V["evt_`k'", "evt_`k'"]) ///
            in `r'
    }

    * 95% confidence interval
    gen ub = coef + 1.96 * se
    gen lb = coef - 1.96 * se


    twoway ///
        (rcap ub lb event_time) ///
        (scatter coef event_time, msymbol(O)), ///
        yline(0, lpattern(dash)) ///
        xline(-4, lpattern(dash)) ///
        xtitle("Event time (years relative to 2004)") ///
        ytitle("Effect (log)") ///
        title("Event study: `ttl'") ///
        subtitle("Reference period = 2000") ///
        legend(off)


    graph export ///
        "/Users/lenovo/PhD papers/paper 2/table and figures/es_`model'.png", ///
        replace ///
        width(2000)

    restore

end


draw_es ES_d3kcal   "Calories"
draw_es ES_d3carbo  "Carbohydrates"
draw_es ES_d3fat    "Fat"
draw_es ES_d3protn  "Protein"


*===============================================================================
* 6. AVERAGE DID — MAIN PURE-CONSUMER SAMPLE
*===============================================================================

eststo clear

foreach y of local outcomes {

    reghdfe ln`y' ///
        did ///
        `RD1' ///
        if consumer_base == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo DID_`y'

    estimates save ///
        "$P2_MODELS/02_nutrition_main_DID_`y'.ster", ///
        replace

    test did

    scalar did_p_`y' = r(p)
}


*===============================================================================
* 7. DISPLAY DID TABLE
*===============================================================================

esttab ///
    DID_d3kcal ///
    DID_d3carbo ///
    DID_d3fat ///
    DID_d3protn, ///
    keep(did) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Average DID estimates: main pure-consumer sample") ///
    addnotes( ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 8. EXPORT AVERAGE DID TO EXCEL
*===============================================================================

putexcel set "`xlsx'", ///
    sheet("AverageDID") modify


putexcel A1 = ("Paper 2: Average DID Results")

putexcel A2 = ///
    ("Main sample: baseline pure-consumer proxy")

putexcel A3 = ///
    ("Individual FE + wave FE; SE clustered at community level")


putexcel A5 = ("Outcome") ///
         B5 = ("DID coefficient") ///
         C5 = ("Standard error") ///
         D5 = ("p-value") ///
         E5 = ("N")


local row = 6

foreach y of local outcomes {

    estimates restore DID_`y'

    local beta = _b[did]
    local se   = _se[did]

    local p = scalar(did_p_`y')

    local N = e(N)

    putexcel A`row' = ("`y'") ///
             B`row' = (`beta') ///
             C`row' = (`se') ///
             D`row' = (`p') ///
             E`row' = (`N')

    local ++row
}


putexcel A1:E1, bold
putexcel A5:E5, bold
putexcel B6:E9, nformat(number_d3)


*===============================================================================
* 9. SAMPLE DIAGNOSTICS
*===============================================================================

capture drop tag_main_ind tag_main_cluster


*-------------------------------------------------------------------------------
* Raw person-wave observations
*-------------------------------------------------------------------------------

quietly count if consumer_base == 1

local raw_obs = r(N)

display as text ///
    "Raw pure-consumer person-wave observations = `raw_obs'"


*-------------------------------------------------------------------------------
* Unique individuals
*-------------------------------------------------------------------------------

egen tag_main_ind = ///
    tag(IDind) ///
    if consumer_base == 1

quietly count if tag_main_ind == 1

local raw_ind = r(N)

display as text ///
    "Unique pure-consumer individuals = `raw_ind'"


*-------------------------------------------------------------------------------
* Communities
*-------------------------------------------------------------------------------

egen tag_main_cluster = ///
    tag(cluster_commid) ///
    if consumer_base == 1

quietly count if tag_main_cluster == 1

local raw_clusters = r(N)

display as text ///
    "Pure-consumer communities = `raw_clusters'"


*===============================================================================
* 10. EXPORT SAMPLE INFORMATION TO EXCEL
*===============================================================================

putexcel set "`xlsx'", ///
    sheet("Sample") modify


putexcel A1 = ("Paper 2: Main Sample Diagnostics")

putexcel A3 = ("Statistic") ///
         B3 = ("Value")

putexcel A4 = ("Pure-consumer households") ///
         B4 = (373)

putexcel A5 = ("Unique individuals") ///
         B5 = (`raw_ind')

putexcel A6 = ("Person-wave observations") ///
         B6 = (`raw_obs')

putexcel A7 = ("Community clusters") ///
         B7 = (`raw_clusters')


putexcel A1:B1, bold
putexcel A3:B3, bold


*===============================================================================
* 11. FINISH
*===============================================================================

display as text ///
    "============================================================"

display as text ///
    "Paper 2 nutrition analysis completed."

display as text ///
    "Excel results saved to:"

display as result ///
    "`xlsx'"

display as text ///
    "============================================================"


*===============================================================================
* 12. CARBOHYDRATE PRE-POLICY BALANCED SAMPLE (1997 AND 2000)
*===============================================================================
capture drop has97_carbo has00_carbo prebalanced_carbo

bysort IDind: egen has97_carbo = max( ///
    wave == 1997 ///
    & consumer_base == 1 ///
    & !missing(lnd3carbo))

bysort IDind: egen has00_carbo = max( ///
    wave == 2000 ///
    & consumer_base == 1 ///
    & !missing(lnd3carbo))

gen prebalanced_carbo = ///
    has97_carbo == 1 & has00_carbo == 1


reghdfe lnd3carbo ///
    evt_m7 evt_p0 evt_p2 evt_p5 evt_p7 ///
    if consumer_base == 1 ///
    & prebalanced_carbo == 1, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)


*===============================================================================
* 13. IMPLEMENTATION-BASED TIMING
* 2004 = reference / last pre-treatment wave
* 2006 = first observed post-treatment wave
*===============================================================================

capture drop evt_m9_impl evt_m6_impl evt_p0_impl evt_p3_impl evt_p5_impl
capture drop did_impl

* Relative to first observed post wave: 2006
gen evt_m9_impl = (treated == 1 & wave == 1997)
gen evt_m6_impl = (treated == 1 & wave == 2000)

* 2004 is omitted reference period

gen evt_p0_impl = (treated == 1 & wave == 2006)
gen evt_p3_impl = (treated == 1 & wave == 2009)
gen evt_p5_impl = (treated == 1 & wave == 2011)

gen did_impl = (treated == 1 & wave >= 2006)


reghdfe lnd3carbo ///
    evt_m9_impl evt_m6_impl ///
    evt_p0_impl evt_p3_impl evt_p5_impl ///
    if consumer_base == 1, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)

test evt_m9_impl evt_m6_impl


foreach y in d3kcal d3carbo d3fat d3protn {

    reghdfe ln`y' ///
        evt_m9_impl evt_m6_impl ///
        evt_p0_impl evt_p3_impl evt_p5_impl ///
        if consumer_base == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    display "=============================="
    display "Pretrend test: `y'"
    test evt_m9_impl evt_m6_impl
}


*===============================================================================
* 14. SIX-WAVE BALANCED-PANEL ANALYSES
*
* All six-wave code is kept together here at the END of this file.
*
* Waves required:
*   1997, 2000, 2004, 2006, 2009, 2011
*
* This section:
*   A. Creates outcome-specific six-wave balanced flags.
*   B. Runs the carbohydrate attrition/composition diagnostic.
*   C. Runs six-wave balanced event studies for all nutrition outcomes.
*===============================================================================


*-------------------------------------------------------------------------------
* 14.1 CREATE OUTCOME-SPECIFIC SIX-WAVE BALANCED FLAGS
*-------------------------------------------------------------------------------

foreach y in kcal carbo fat protn {

    capture drop ///
        sw_has97_`y' sw_has00_`y' sw_has04_`y' ///
        sw_has06_`y' sw_has09_`y' sw_has11_`y' ///
        sw_balanced6_`y'

    bysort IDind: egen sw_has97_`y' = max( ///
        wave == 1997 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    bysort IDind: egen sw_has00_`y' = max( ///
        wave == 2000 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    bysort IDind: egen sw_has04_`y' = max( ///
        wave == 2004 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    bysort IDind: egen sw_has06_`y' = max( ///
        wave == 2006 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    bysort IDind: egen sw_has09_`y' = max( ///
        wave == 2009 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    bysort IDind: egen sw_has11_`y' = max( ///
        wave == 2011 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    gen byte sw_balanced6_`y' = ///
        sw_has97_`y' == 1 & ///
        sw_has00_`y' == 1 & ///
        sw_has04_`y' == 1 & ///
        sw_has06_`y' == 1 & ///
        sw_has09_`y' == 1 & ///
        sw_has11_`y' == 1

    label variable sw_balanced6_`y' ///
        "`y' observed in all six waves, 1997-2011"
}


* Quick balance checks.
tab sw_balanced6_kcal  if consumer_base == 1, missing
tab sw_balanced6_carbo if consumer_base == 1, missing
tab sw_balanced6_fat   if consumer_base == 1, missing
tab sw_balanced6_protn if consumer_base == 1, missing


*-------------------------------------------------------------------------------
* 14.2 CARBOHYDRATE ATTRITION / SAMPLE-COMPOSITION DIAGNOSTIC
*
* Compare the 1997 -> 2000 pre-policy change between:
*   - six-wave retainers
*   - individuals not observed with carbohydrate in all six waves
*-------------------------------------------------------------------------------

capture drop carbo97 carbo00 dcarbo_pre tag_person

bysort IDind: egen carbo97 = max(cond( ///
    wave == 1997 & consumer_base == 1, lnd3carbo, .))

bysort IDind: egen carbo00 = max(cond( ///
    wave == 2000 & consumer_base == 1, lnd3carbo, .))

gen dcarbo_pre = carbo00 - carbo97

label variable dcarbo_pre ///
    "Change in log carbohydrate intake, 1997-2000"

egen tag_person = tag(IDind) ///
    if consumer_base == 1 & !missing(dcarbo_pre)


display as text "============================================================"
display as text "CONTROL (Guizhou), six-wave balanced"

summarize dcarbo_pre ///
    if tag_person == 1 ///
    & treated == 0 ///
    & sw_balanced6_carbo == 1


display as text "============================================================"
display as text "TREATED (Hunan), six-wave balanced"

summarize dcarbo_pre ///
    if tag_person == 1 ///
    & treated == 1 ///
    & sw_balanced6_carbo == 1


display as text "============================================================"
display as text "CONTROL (Guizhou), NOT six-wave balanced"

summarize dcarbo_pre ///
    if tag_person == 1 ///
    & treated == 0 ///
    & sw_balanced6_carbo == 0


display as text "============================================================"
display as text "TREATED (Hunan), NOT six-wave balanced"

summarize dcarbo_pre ///
    if tag_person == 1 ///
    & treated == 1 ///
    & sw_balanced6_carbo == 0


* Formal test:
* Does the Hunan-vs-Guizhou 1997->2000 difference differ by six-wave retention?
reg dcarbo_pre ///
    i.treated##i.sw_balanced6_carbo ///
    if tag_person == 1, ///
    vce(cluster cluster_commid)

margins sw_balanced6_carbo, dydx(treated)

test 1.treated#1.sw_balanced6_carbo


*-------------------------------------------------------------------------------
* 14.3 SIX-WAVE BALANCED EVENT STUDY — ALL NUTRITION OUTCOMES
*
* 2000 is the omitted/reference period.
* evt_m7 corresponds to 1997.
*-------------------------------------------------------------------------------

foreach y in kcal carbo fat protn {

    display as text "============================================================"
    display as text "Six-wave balanced event study: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        evt_m7 evt_p0 evt_p2 evt_p5 evt_p7 ///
        if consumer_base == 1 ///
        & sw_balanced6_`y' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    display as text "Pre-trend test: `y'"
    test evt_m7

    scalar balanced_pretrend_p_`y' = r(p)
}


* Display the four six-wave pre-trend p-values together.
display as text "============================================================"
display as text "SIX-WAVE BALANCED PRE-TREND P-VALUES"
display as text "kcal    = " %9.4f scalar(balanced_pretrend_p_kcal)
display as text "carbo   = " %9.4f scalar(balanced_pretrend_p_carbo)
display as text "fat     = " %9.4f scalar(balanced_pretrend_p_fat)
display as text "protein = " %9.4f scalar(balanced_pretrend_p_protn)
display as text "============================================================"


*===============================================================================
* END OF analyses/02_nutrition_main_6wave_at_end.do
*===============================================================================



*===============================================================
* SIX-WAVE BALANCED EVENT STUDY
* IMPLEMENTATION-BASED TIMING
*
* 2004 = omitted reference / last pre-treatment wave
* 2006 = first observed post-treatment wave
*===============================================================

foreach y in kcal carbo fat protn {

    display as text "============================================================"
    display as text "Balanced implementation-timing event study: `y'"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        evt_m9_impl evt_m6_impl ///
        evt_p0_impl evt_p3_impl evt_p5_impl ///
        if consumer_base == 1 ///
        & sw_balanced6_`y' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    * Joint pre-trend test:
    * 1997 and 2000 relative to 2004
    test evt_m9_impl evt_m6_impl

    scalar bal_impl_pretrend_p_`y' = r(p)
}

display "=========================================="
display "BALANCED IMPLEMENTATION-TIMING PRETREND"
display "kcal    = " scalar(bal_impl_pretrend_p_kcal)
display "carbo   = " scalar(bal_impl_pretrend_p_carbo)
display "fat     = " scalar(bal_impl_pretrend_p_fat)
display "protein = " scalar(bal_impl_pretrend_p_protn)
display "=========================================="

*===============================================================================
* PRE-POLICY BALANCED SAMPLE — ANNOUNCEMENT-BASED TIMING
*
* Policy timing:
*   1997 = pre-treatment
*   2000 = last clean pre-treatment wave / omitted reference
*   2004 = policy announcement / treatment onset
*   2006 = post
*   2009 = post
*   2011 = post
*
* Sample definition:
*   Individuals must have the relevant nutrition outcome observed
*   in BOTH 1997 and 2000.
*
* IMPORTANT:
*   Sample selection uses PRE-TREATMENT information only.
*   Observations in 2004/2006/2009/2011 are NOT required for sample entry.
*===============================================================================


*-------------------------------------------------------------------------------
* 1. SAME CONTROLS AS MAIN SPECIFICATION
*-------------------------------------------------------------------------------

local RD_prebal ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


*===============================================================================
* 2. ANNOUNCEMENT-BASED EVENT-TIME VARIABLES
*
* Reference period = 2000
* Treatment starts = 2004
*===============================================================================

capture drop ///
    evt_m7_ann ///
    evt_p0_ann ///
    evt_p2_ann ///
    evt_p5_ann ///
    evt_p7_ann ///
    did_ann


* 1997 = pre-treatment lead
gen evt_m7_ann = ///
    (treated == 1 & wave == 1997)

* 2000 = omitted/reference period

* 2004 = policy announcement / treatment onset
gen evt_p0_ann = ///
    (treated == 1 & wave == 2004)

* Post-treatment waves
gen evt_p2_ann = ///
    (treated == 1 & wave == 2006)

gen evt_p5_ann = ///
    (treated == 1 & wave == 2009)

gen evt_p7_ann = ///
    (treated == 1 & wave == 2011)


* Average DID treatment indicator
gen did_ann = ///
    (treated == 1 & wave >= 2004)

label variable did_ann ///
    "Hunan x post-2004 announcement"


*===============================================================================
* 3. CREATE OUTCOME-SPECIFIC PRE-POLICY BALANCED FLAGS
*
* Only 1997 and 2000 are used to define the sample.
*===============================================================================

foreach y in kcal carbo fat protn {

    capture drop ///
        pre97_`y' ///
        pre00_`y' ///
        prebal2_`y'

    *-----------------------------------------------------------
    * 1997 observed
    *-----------------------------------------------------------

    bysort IDind: egen pre97_`y' = max( ///
        wave == 1997 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    *-----------------------------------------------------------
    * 2000 observed
    *-----------------------------------------------------------

    bysort IDind: egen pre00_`y' = max( ///
        wave == 2000 ///
        & consumer_base == 1 ///
        & !missing(lnd3`y'))

    *-----------------------------------------------------------
    * Must have outcome in BOTH clean pre-treatment waves
    *-----------------------------------------------------------

    gen byte prebal2_`y' = ///
        pre97_`y' == 1 ///
        & pre00_`y' == 1

    label variable prebal2_`y' ///
        "`y': observed in both 1997 and 2000"
}


*===============================================================================
* 4. CHECK PRE-POLICY BALANCED SAMPLE SIZE
*===============================================================================

display as text "============================================================"
display as text "PRE-POLICY BALANCED SAMPLE COUNTS"
display as text "Required waves: 1997 and 2000"
display as text "============================================================"

foreach y in kcal carbo fat protn {

    capture drop tag_prebal2_`y'

    egen tag_prebal2_`y' = tag(IDind) ///
        if consumer_base == 1 ///
        & prebal2_`y' == 1

    quietly count if tag_prebal2_`y' == 1

    display as text ///
        "`y' individuals = " r(N)
}


*===============================================================================
* 5. EVENT STUDY — PRE-POLICY BALANCED SAMPLE
*
* Reference = 2000
*
* PRE:
*   1997 = evt_m7_ann
*
* TREATMENT / POST:
*   2004 = evt_p0_ann
*   2006 = evt_p2_ann
*   2009 = evt_p5_ann
*   2011 = evt_p7_ann
*===============================================================================

eststo clear

foreach y in kcal carbo fat protn {

    display as text "============================================================"
    display as text ///
        "PRE-POLICY BALANCED EVENT STUDY: `y'"
    display as text ///
        "Reference = 2000; treatment onset = 2004"
    display as text "============================================================"

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        `RD_prebal' ///
        if consumer_base == 1 ///
        & prebal2_`y' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo PREBAL_ES_`y'

    *-----------------------------------------------------------
    * Parallel-trend test
    *
    * Since 2000 is the reference and 2004 is treatment onset,
    * the only clean pre-treatment coefficient is 1997.
    *-----------------------------------------------------------

    test evt_m7_ann

    scalar prebal_pretrend_p_`y' = r(p)

    display as text ///
        "Pre-trend p-value (`y') = " ///
        %9.4f scalar(prebal_pretrend_p_`y')
}


*===============================================================================
* 6. SHOW EVENT-STUDY RESULTS TOGETHER
*===============================================================================

esttab ///
    PREBAL_ES_kcal ///
    PREBAL_ES_carbo ///
    PREBAL_ES_fat ///
    PREBAL_ES_protn, ///
    keep( ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Pre-policy balanced sample: announcement-based event study" ///
    ) ///
    addnotes( ///
        "Sample requires outcome observed in both 1997 and 2000", ///
        "Reference period: 2000", ///
        "2004 is treated as policy announcement / treatment onset", ///
        "Post-treatment observations are not required for sample entry", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* 7. DISPLAY ALL PRE-TREND P-VALUES
*===============================================================================

display as text "============================================================"
display as text ///
    "PRE-POLICY BALANCED PRE-TREND P-VALUES"
display as text ///
    "1997 relative to reference year 2000"
display as text "============================================================"

display as text ///
    "kcal    = " %9.4f scalar(prebal_pretrend_p_kcal)

display as text ///
    "carbo   = " %9.4f scalar(prebal_pretrend_p_carbo)

display as text ///
    "fat     = " %9.4f scalar(prebal_pretrend_p_fat)

display as text ///
    "protein = " %9.4f scalar(prebal_pretrend_p_protn)

display as text "============================================================"


*===============================================================================
* 8. AVERAGE DID — SAME PRE-POLICY BALANCED SAMPLE
*
* Post begins in 2004.
*===============================================================================

eststo clear

foreach y in kcal carbo fat protn {

    reghdfe lnd3`y' ///
        did_ann ///
        `RD_prebal' ///
        if consumer_base == 1 ///
        & prebal2_`y' == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo PREBAL_DID_`y'
}


*===============================================================================
* 9. DISPLAY AVERAGE DID RESULTS
*===============================================================================

esttab ///
    PREBAL_DID_kcal ///
    PREBAL_DID_carbo ///
    PREBAL_DID_fat ///
    PREBAL_DID_protn, ///
    keep(did_ann) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Pre-policy balanced sample: average DID" ///
    ) ///
    addnotes( ///
        "Sample requires outcome observed in both 1997 and 2000", ///
        "Treatment/post period begins in 2004", ///
        "Individual and wave fixed effects", ///
        "Standard errors clustered at community level" ///
    )


*===============================================================================
* END — PRE-POLICY BALANCED, ANNOUNCEMENT-BASED TIMING
*===============================================================================
