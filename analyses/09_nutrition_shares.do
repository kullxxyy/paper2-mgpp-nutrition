*===============================================================================
* PAPER 2 — NUTRIENT SHARES, NUTRITION QUALITY, AND DYNAMIC EFFECTS
* File: analyses/09_nutrition_shares.do
*
* This file MERGES and REPLACES:
*   - old analyses/09_nutrition_shares.do
*   - old analyses/10_eventdd_shares.do
*
* FINAL PAPER-2 STANDARD
*
* Sample:
*   Hunan (treated) vs Guizhou (control), baseline pure consumers.
*
* Timing:
*   1997 = clean pre-policy lead
*   2000 = omitted/reference year
*   2004 = announcement / transition wave
*   2006, 2009, 2011 = observed implementation-period waves
*
* Heterogeneity:
*   Individual baseline calories measured in BOTH 1997 and 2000.
*   Preferred low-kcal group = bottom quartile calculated ONLY among individuals
*   with both pre-policy calorie observations.
*
* Estimation:
*   Individual FE + wave FE
*   SE clustered at community level
*   No contemporaneous controls in preferred specifications
*
* Outcomes:
*   sC_imp = carbohydrate share / index used in the project
*   sF_imp = fat share / index used in the project
*   sP_imp = protein share / index used in the project
*   Q2     = nutrition-quality index
*
* Compatibility:
*   If sC_imp/sF_imp/sP_imp are absent but
*   carb_share/fat_share/protein_share exist, aliases are created.
*
* Optional graphs:
*   If coefplot is installed and $P2_FIGURES is defined, dynamic average-DID
*   and dynamic-DDD graphs are exported automatically.
*===============================================================================


*===============================================================================
* 0. REQUIRED PACKAGES / PATHS / VARIABLES
*===============================================================================

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
    display as error "P2_TABLES is empty. Run config.do/main.do first."
    exit 198
}

if "$P2_MODELS" == "" {
    display as error "P2_MODELS is empty. Run config.do/main.do first."
    exit 198
}


foreach v in ///
    IDind wave consumer_base d3kcal {

    capture confirm variable `v'

    if _rc {
        display as error "Required variable `v' not found."
        exit 111
    }
}


* Preferred cluster variable.
capture confirm variable cluster_commid

if _rc {

    capture confirm variable COMMID

    if _rc {
        display as error "Neither cluster_commid nor COMMID exists."
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
* 1. STANDARDIZE SHARE / QUALITY OUTCOME NAMES
*===============================================================================

capture confirm variable sC_imp

if _rc {

    capture confirm variable carb_share

    if !_rc {
        gen double sC_imp = carb_share
        label variable sC_imp "Carbohydrate share"
    }
}


capture confirm variable sF_imp

if _rc {

    capture confirm variable fat_share

    if !_rc {
        gen double sF_imp = fat_share
        label variable sF_imp "Fat share"
    }
}


capture confirm variable sP_imp

if _rc {

    capture confirm variable protein_share

    if !_rc {
        gen double sP_imp = protein_share
        label variable sP_imp "Protein share"
    }
}


local share_outcomes ""

foreach y in sC_imp sF_imp sP_imp Q2 {

    capture confirm variable `y'

    if !_rc {
        local share_outcomes "`share_outcomes' `y'"
    }
    else {
        display as text ///
            "NOTE: `y' not found and will be skipped."
    }
}


if "`share_outcomes'" == "" {
    display as error ///
        "No nutrient-share / quality outcome is available."
    exit 111
}


*===============================================================================
* 2. HUNAN / GUIZHOU PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in ///
    ns_sample_hg ///
    ns_treated_hg ///
    ns_sample_pc {

    capture drop `v'
}


capture confirm variable t1

if !_rc {

    gen byte ns_sample_hg = ///
        inlist(t1, 43, 52)

    gen byte ns_treated_hg = ///
        (t1 == 43) ///
        if ns_sample_hg == 1
}
else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists; cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte ns_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte ns_treated_hg = ///
        (province_code == 43) ///
        if ns_sample_hg == 1
}


gen byte ns_sample_pc = ///
    ns_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


capture label define ns_hg ///
    0 "Guizhou" ///
    1 "Hunan"

if _rc {
    label define ns_hg ///
        0 "Guizhou" ///
        1 "Hunan", ///
        replace
}

label values ns_treated_hg ns_hg


display as text ""
display as result "============================================================"
display as result "09 NUTRIENT SHARES — HUNAN / GUIZHOU PURE CONSUMERS"
display as result "============================================================"

tab ns_treated_hg ///
    if ns_sample_pc == 1, ///
    missing

tab wave ///
    if ns_sample_pc == 1, ///
    missing


*===============================================================================
* 3. PREFERRED TWO-PRE-WAVE INDIVIDUAL LOW-KCAL GROUP
*
* Exactly the same conceptual definition as the final heterogeneity analysis:
*   1997 kcal observed
*   2000 kcal observed
*   mean of the two waves
*   bottom quartile calculated only among those two-pre-wave individuals
*===============================================================================

foreach v in ///
    ns_kcal97 ///
    ns_kcal00 ///
    ns_pre_n ///
    ns_pre_kcal ///
    ns_qkcal ///
    ns_low_q25 ///
    ns_sample_pre2 {

    capture drop `v'
}


bysort IDind: egen double ns_kcal97 = max( ///
    cond( ///
        wave == 1997 ///
        & ns_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen double ns_kcal00 = max( ///
    cond( ///
        wave == 2000 ///
        & ns_sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


gen byte ns_pre_n = ///
    !missing(ns_kcal97) ///
    + !missing(ns_kcal00)


gen double ns_pre_kcal = ///
    (ns_kcal97 + ns_kcal00) / 2 ///
    if ns_pre_n == 2


preserve

    keep if ///
        ns_sample_hg == 1 ///
        & ns_pre_n == 2 ///
        & !missing(ns_pre_kcal)

    keep IDind ns_pre_kcal

    bysort IDind: keep if _n == 1

    isid IDind

    quietly count
    local N_pre2 = r(N)

    display as result ///
        "Two-pre-wave individuals defining low-kcal q25 = `N_pre2'"

    if `N_pre2' < 4 {
        display as error ///
            "Too few individuals to define baseline-calorie quartiles."
        restore
        exit 2001
    }

    xtile ns_qkcal = ns_pre_kcal, nq(4)

    gen byte ns_low_q25 = ///
        (ns_qkcal == 1) ///
        if !missing(ns_qkcal)

    keep ///
        IDind ///
        ns_qkcal ///
        ns_low_q25

    tempfile ns_kcal_groups
    save `ns_kcal_groups', replace

restore


merge m:1 IDind ///
    using `ns_kcal_groups', ///
    nogen ///
    keep(master match)


gen byte ns_sample_pre2 = ///
    ns_sample_hg == 1 ///
    & ns_pre_n == 2 ///
    & !missing(ns_low_q25) ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


label variable ns_low_q25 ///
    "Bottom 25% individual baseline calories, both 1997/2000 required"


capture drop __ns_tag

egen byte __ns_tag = tag(IDind) ///
    if ns_sample_pre2 == 1

quietly count if __ns_tag == 1

display as result ///
    "Preferred two-pre-wave individuals = " ///
    r(N)

tab ns_low_q25 ns_treated_hg ///
    if __ns_tag == 1, ///
    column

drop __ns_tag


*===============================================================================
* 4. COMMON POLICY VARIABLES
*===============================================================================

foreach v in ///
    ns_ann ///
    ns_impl ///
    ns_h_ann ///
    ns_h_impl ///
    ns_l_ann ///
    ns_l_impl ///
    ns_ddd_ann ///
    ns_ddd_impl {

    capture drop `v'
}


gen byte ns_ann = ///
    (wave == 2004)


gen byte ns_impl = ///
    (wave >= 2006)


* Average Hunan effects.
gen byte ns_h_ann = ///
    ns_treated_hg * ns_ann ///
    if ns_sample_pc == 1


gen byte ns_h_impl = ///
    ns_treated_hg * ns_impl ///
    if ns_sample_pc == 1


* Low-kcal time effects.
gen byte ns_l_ann = ///
    ns_low_q25 * ns_ann ///
    if ns_sample_pre2 == 1


gen byte ns_l_impl = ///
    ns_low_q25 * ns_impl ///
    if ns_sample_pre2 == 1


* Triple interactions.
gen byte ns_ddd_ann = ///
    ns_treated_hg * ns_low_q25 * ns_ann ///
    if ns_sample_pre2 == 1


gen byte ns_ddd_impl = ///
    ns_treated_hg * ns_low_q25 * ns_impl ///
    if ns_sample_pre2 == 1


label variable ns_h_ann ///
    "Hunan x Announcement 2004"

label variable ns_h_impl ///
    "Hunan x Implementation period"

label variable ns_l_ann ///
    "Low baseline kcal x Announcement 2004"

label variable ns_l_impl ///
    "Low baseline kcal x Implementation period"

label variable ns_ddd_ann ///
    "Hunan x Low kcal x Announcement 2004 (DDD)"

label variable ns_ddd_impl ///
    "Hunan x Low kcal x Implementation period (DDD)"


*===============================================================================
* 5. PART A — AVERAGE NUTRIENT SHARES / QUALITY
*
* Preferred average specification:
*   outcome = Hunan x announcement + Hunan x implementation
*   individual FE + wave FE
*===============================================================================

eststo clear

local avg_models ""


foreach y of local share_outcomes {

    display as text ""
    display as result "============================================================"
    display as result "AVERAGE SHARE / QUALITY EFFECT: `y'"
    display as result "============================================================"

    reghdfe `y' ///
        ns_h_ann ///
        ns_h_impl ///
        if ns_sample_pc == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo AVG_`y'

    local avg_models ///
        "`avg_models' AVG_`y'"

    test ns_h_impl

    scalar ns_avg_impl_b_`y' = _b[ns_h_impl]
    scalar ns_avg_impl_p_`y' = r(p)

    estimates save ///
        "$P2_MODELS/09_average_`y'.ster", ///
        replace
}


if "`avg_models'" != "" {

    esttab ///
        `avg_models' ///
        using "$P2_TABLES/09_average_shares_quality.rtf", ///
        replace ///
        keep( ///
            ns_h_ann ///
            ns_h_impl ///
        ) ///
        order( ///
            ns_h_ann ///
            ns_h_impl ///
        ) ///
        coeflabels( ///
            ns_h_ann ///
                "Hunan x Announcement 2004" ///
            ns_h_impl ///
                "Hunan x Implementation period" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Average effects on nutrient shares and nutrition quality" ///
        ) ///
        addnotes( ///
            "Hunan versus Guizhou baseline pure consumers", ///
            "2004 is modeled separately as the announcement wave", ///
            "Implementation period: 2006, 2009, and 2011", ///
            "Individual and wave fixed effects", ///
            "Standard errors clustered at community level", ///
            "No contemporaneous controls in preferred specifications" ///
        )


    esttab ///
        `avg_models' ///
        using "$P2_TABLES/09_average_shares_quality.csv", ///
        replace ///
        keep( ///
            ns_h_ann ///
            ns_h_impl ///
        ) ///
        order( ///
            ns_h_ann ///
            ns_h_impl ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01)
}


*===============================================================================
* 6. PART B — PREFERRED LOW-KCAL DDD FOR SHARES / QUALITY
*
* Complete DDD:
*   Hunan x period
*   Low-kcal x period
*   Hunan x Low-kcal x period
*===============================================================================

eststo clear

local ddd_models ""


foreach y of local share_outcomes {

    display as text ""
    display as result "============================================================"
    display as result "LOW-KCAL SHARE / QUALITY DDD: `y'"
    display as result "============================================================"

    reghdfe `y' ///
        ns_h_ann ///
        ns_l_ann ///
        ns_ddd_ann ///
        ns_h_impl ///
        ns_l_impl ///
        ns_ddd_impl ///
        if ns_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo DDD_`y'

    local ddd_models ///
        "`ddd_models' DDD_`y'"

    test ns_ddd_impl

    scalar ns_ddd_impl_b_`y' = _b[ns_ddd_impl]
    scalar ns_ddd_impl_p_`y' = r(p)


    lincom ns_h_impl + ns_ddd_impl

    scalar ns_low_total_b_`y' = r(estimate)
    scalar ns_low_total_p_`y' = r(p)


    test ns_ddd_impl = ns_ddd_ann

    scalar ns_impl_vs_ann_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/09_heterogeneity_`y'.ster", ///
        replace
}


if "`ddd_models'" != "" {

    esttab ///
        `ddd_models' ///
        using "$P2_TABLES/09_lowkcal_shares_quality_DDD.rtf", ///
        replace ///
        keep( ///
            ns_h_ann ///
            ns_l_ann ///
            ns_ddd_ann ///
            ns_h_impl ///
            ns_l_impl ///
            ns_ddd_impl ///
        ) ///
        order( ///
            ns_h_ann ///
            ns_l_ann ///
            ns_ddd_ann ///
            ns_h_impl ///
            ns_l_impl ///
            ns_ddd_impl ///
        ) ///
        coeflabels( ///
            ns_h_ann ///
                "Hunan x Announcement 2004" ///
            ns_l_ann ///
                "Low kcal x Announcement 2004" ///
            ns_ddd_ann ///
                "Hunan x Low kcal x Announcement 2004 (DDD)" ///
            ns_h_impl ///
                "Hunan x Implementation period" ///
            ns_l_impl ///
                "Low kcal x Implementation period" ///
            ns_ddd_impl ///
                "Hunan x Low kcal x Implementation period (DDD)" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Nutrient shares and nutrition quality by baseline calorie status" ///
        ) ///
        addnotes( ///
            "Low-kcal group = bottom quartile of individual mean kcal in 1997 and 2000", ///
            "Both pre-policy calorie observations are required", ///
            "2004 is modeled separately as the announcement wave", ///
            "Implementation period: 2006, 2009, and 2011", ///
            "Individual and wave fixed effects", ///
            "Standard errors clustered at community level" ///
        )


    esttab ///
        `ddd_models' ///
        using "$P2_TABLES/09_lowkcal_shares_quality_DDD.csv", ///
        replace ///
        keep( ///
            ns_h_ann ///
            ns_l_ann ///
            ns_ddd_ann ///
            ns_h_impl ///
            ns_l_impl ///
            ns_ddd_impl ///
        ) ///
        order( ///
            ns_h_ann ///
            ns_l_ann ///
            ns_ddd_ann ///
            ns_h_impl ///
            ns_l_impl ///
            ns_ddd_impl ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01)
}


*===============================================================================
* 7. PART C — DYNAMIC AVERAGE DID
*
* Reference year = 2000.
* 1997 x Hunan is the single clean pretrend diagnostic.
*===============================================================================

foreach v in ///
    ns_h97 ///
    ns_h04 ///
    ns_h06 ///
    ns_h09 ///
    ns_h11 {

    capture drop `v'
}


gen byte ns_h97 = ///
    ns_treated_hg * (wave == 1997) ///
    if ns_sample_pc == 1

gen byte ns_h04 = ///
    ns_treated_hg * (wave == 2004) ///
    if ns_sample_pc == 1

gen byte ns_h06 = ///
    ns_treated_hg * (wave == 2006) ///
    if ns_sample_pc == 1

gen byte ns_h09 = ///
    ns_treated_hg * (wave == 2009) ///
    if ns_sample_pc == 1

gen byte ns_h11 = ///
    ns_treated_hg * (wave == 2011) ///
    if ns_sample_pc == 1


eststo clear

local avg_es_models ""


foreach y of local share_outcomes {

    display as text ""
    display as result "============================================================"
    display as result "DYNAMIC AVERAGE SHARE / QUALITY DID: `y'"
    display as result "REFERENCE YEAR = 2000"
    display as result "============================================================"

    reghdfe `y' ///
        ns_h97 ///
        ns_h04 ///
        ns_h06 ///
        ns_h09 ///
        ns_h11 ///
        if ns_sample_pc == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo AVGES_`y'

    local avg_es_models ///
        "`avg_es_models' AVGES_`y'"

    test ns_h97

    scalar ns_avg_pre_b_`y' = _b[ns_h97]
    scalar ns_avg_pre_p_`y' = r(p)


    test ns_h06 ns_h09 ns_h11

    scalar ns_avg_post_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/09_dynamic_average_`y'.ster", ///
        replace
}


if "`avg_es_models'" != "" {

    esttab ///
        `avg_es_models' ///
        using "$P2_TABLES/09_dynamic_average_shares_quality.rtf", ///
        replace ///
        keep( ///
            ns_h97 ///
            ns_h04 ///
            ns_h06 ///
            ns_h09 ///
            ns_h11 ///
        ) ///
        order( ///
            ns_h97 ///
            ns_h04 ///
            ns_h06 ///
            ns_h09 ///
            ns_h11 ///
        ) ///
        coeflabels( ///
            ns_h97 "1997 x Hunan" ///
            ns_h04 "2004 x Hunan" ///
            ns_h06 "2006 x Hunan" ///
            ns_h09 "2009 x Hunan" ///
            ns_h11 "2011 x Hunan" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Dynamic average effects on nutrient shares and nutrition quality" ///
        ) ///
        addnotes( ///
            "Reference year: 2000", ///
            "1997 x Hunan is the differential-pretrend diagnostic", ///
            "Individual and wave fixed effects", ///
            "Standard errors clustered at community level" ///
        )
}


*===============================================================================
* 8. PART D — DYNAMIC LOW-KCAL DDD
*
* Reference year = 2000.
* Correct dynamic DDD includes:
*   Hunan x year
*   Low-kcal x year
*   Hunan x Low-kcal x year
*
* NOTE:
*   Do NOT clear stored estimates here. The optional graph section below uses
*   both AVGES_* models from Part C and DDDES_* models from Part D.
*===============================================================================

foreach v in ///
    ns_l97 ns_l04 ns_l06 ns_l09 ns_l11 ///
    ns_d97 ns_d04 ns_d06 ns_d09 ns_d11 {

    capture drop `v'
}


gen byte ns_l97 = ///
    ns_low_q25 * (wave == 1997) ///
    if ns_sample_pre2 == 1

gen byte ns_l04 = ///
    ns_low_q25 * (wave == 2004) ///
    if ns_sample_pre2 == 1

gen byte ns_l06 = ///
    ns_low_q25 * (wave == 2006) ///
    if ns_sample_pre2 == 1

gen byte ns_l09 = ///
    ns_low_q25 * (wave == 2009) ///
    if ns_sample_pre2 == 1

gen byte ns_l11 = ///
    ns_low_q25 * (wave == 2011) ///
    if ns_sample_pre2 == 1


gen byte ns_d97 = ///
    ns_treated_hg * ns_low_q25 * (wave == 1997) ///
    if ns_sample_pre2 == 1

gen byte ns_d04 = ///
    ns_treated_hg * ns_low_q25 * (wave == 2004) ///
    if ns_sample_pre2 == 1

gen byte ns_d06 = ///
    ns_treated_hg * ns_low_q25 * (wave == 2006) ///
    if ns_sample_pre2 == 1

gen byte ns_d09 = ///
    ns_treated_hg * ns_low_q25 * (wave == 2009) ///
    if ns_sample_pre2 == 1

gen byte ns_d11 = ///
    ns_treated_hg * ns_low_q25 * (wave == 2011) ///
    if ns_sample_pre2 == 1


local ddd_es_models ""


foreach y of local share_outcomes {

    display as text ""
    display as result "============================================================"
    display as result "DYNAMIC LOW-KCAL SHARE / QUALITY DDD: `y'"
    display as result "REFERENCE YEAR = 2000"
    display as result "============================================================"

    reghdfe `y' ///
        ns_h97 ns_h04 ns_h06 ns_h09 ns_h11 ///
        ns_l97 ns_l04 ns_l06 ns_l09 ns_l11 ///
        ns_d97 ns_d04 ns_d06 ns_d09 ns_d11 ///
        if ns_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo DDDES_`y'

    local ddd_es_models ///
        "`ddd_es_models' DDDES_`y'"

    test ns_d97

    scalar ns_ddd_pre_b_`y' = _b[ns_d97]
    scalar ns_ddd_pre_p_`y' = r(p)


    test ns_d06 ns_d09 ns_d11

    scalar ns_ddd_post_p_`y' = r(p)


    estimates save ///
        "$P2_MODELS/09_dynamic_DDD_`y'.ster", ///
        replace
}


if "`ddd_es_models'" != "" {

    esttab ///
        `ddd_es_models' ///
        using "$P2_TABLES/09_dynamic_lowkcal_shares_quality_DDD.rtf", ///
        replace ///
        keep( ///
            ns_d97 ///
            ns_d04 ///
            ns_d06 ///
            ns_d09 ///
            ns_d11 ///
        ) ///
        order( ///
            ns_d97 ///
            ns_d04 ///
            ns_d06 ///
            ns_d09 ///
            ns_d11 ///
        ) ///
        coeflabels( ///
            ns_d97 "1997 x Hunan x Low kcal" ///
            ns_d04 "2004 x Hunan x Low kcal" ///
            ns_d06 "2006 x Hunan x Low kcal" ///
            ns_d09 "2009 x Hunan x Low kcal" ///
            ns_d11 "2011 x Hunan x Low kcal" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Dynamic DDD for nutrient shares and nutrition quality" ///
        ) ///
        addnotes( ///
            "Reference year: 2000", ///
            "1997 triple interaction is the differential-pretrend diagnostic", ///
            "Low-kcal group uses individual mean calories in both 1997 and 2000", ///
            "Individual and wave fixed effects", ///
            "Standard errors clustered at community level" ///
        )
}


*===============================================================================
* 9. PART E — OPTIONAL DYNAMIC GRAPHS
*
* This section replaces the old eventdd file.
* It graphs the explicit wave-interaction estimates above.
* If coefplot is unavailable, estimation still completes and graphs are skipped.
*===============================================================================

capture which coefplot

if !_rc & "$P2_FIGURES" != "" {

    foreach y of local share_outcomes {

        local pretty "`y'"

        if "`y'" == "sC_imp" {
            local pretty "Carbohydrate share"
        }

        if "`y'" == "sF_imp" {
            local pretty "Fat share"
        }

        if "`y'" == "sP_imp" {
            local pretty "Protein share"
        }

        if "`y'" == "Q2" {
            local pretty "Nutrition quality (Q2)"
        }


        * Average dynamic DID.
        coefplot ///
            AVGES_`y', ///
            keep( ///
                ns_h97 ///
                ns_h04 ///
                ns_h06 ///
                ns_h09 ///
                ns_h11 ///
            ) ///
            order( ///
                ns_h97 ///
                ns_h04 ///
                ns_h06 ///
                ns_h09 ///
                ns_h11 ///
            ) ///
            coeflabels( ///
                ns_h97 = "1997" ///
                ns_h04 = "2004" ///
                ns_h06 = "2006" ///
                ns_h09 = "2009" ///
                ns_h11 = "2011" ///
            ) ///
            vertical ///
            yline(0) ///
            title("`pretty': dynamic Hunan effect") ///
            subtitle("Reference year = 2000") ///
            ytitle("Coefficient relative to 2000") ///
            xtitle("Survey year")

        graph export ///
            "$P2_FIGURES/09_dynamic_average_`y'.png", ///
            replace ///
            width(2000)


        * Dynamic low-kcal DDD.
        coefplot ///
            DDDES_`y', ///
            keep( ///
                ns_d97 ///
                ns_d04 ///
                ns_d06 ///
                ns_d09 ///
                ns_d11 ///
            ) ///
            order( ///
                ns_d97 ///
                ns_d04 ///
                ns_d06 ///
                ns_d09 ///
                ns_d11 ///
            ) ///
            coeflabels( ///
                ns_d97 = "1997" ///
                ns_d04 = "2004" ///
                ns_d06 = "2006" ///
                ns_d09 = "2009" ///
                ns_d11 = "2011" ///
            ) ///
            vertical ///
            yline(0) ///
            title("`pretty': dynamic low-kcal DDD") ///
            subtitle("Reference year = 2000") ///
            ytitle("Triple-interaction coefficient") ///
            xtitle("Survey year")

        graph export ///
            "$P2_FIGURES/09_dynamic_DDD_`y'.png", ///
            replace ///
            width(2000)
    }
}
else {

    display as text ///
        "NOTE: coefplot unavailable or P2_FIGURES empty; dynamic graphs skipped."
}


*===============================================================================
* 10. COMPACT SUMMARY
*===============================================================================

display as text ""
display as result "======================================================================"
display as result "NUTRIENT SHARES / QUALITY SUMMARY"
display as result "======================================================================"


foreach y of local share_outcomes {

    display as text ""
    display as result "OUTCOME: `y'"

    display as text ///
        "Average implementation effect       = " ///
        %9.4f scalar(ns_avg_impl_b_`y') ///
        "   p = " ///
        %9.4f scalar(ns_avg_impl_p_`y')

    display as text ///
        "Low-kcal implementation DDD          = " ///
        %9.4f scalar(ns_ddd_impl_b_`y') ///
        "   p = " ///
        %9.4f scalar(ns_ddd_impl_p_`y')

    display as text ///
        "Low-kcal total Hunan effect          = " ///
        %9.4f scalar(ns_low_total_b_`y') ///
        "   p = " ///
        %9.4f scalar(ns_low_total_p_`y')

    display as text ///
        "Average DID pretrend p               = " ///
        %9.4f scalar(ns_avg_pre_p_`y')

    display as text ///
        "Average dynamic joint post p         = " ///
        %9.4f scalar(ns_avg_post_p_`y')

    display as text ///
        "DDD pretrend p                       = " ///
        %9.4f scalar(ns_ddd_pre_p_`y')

    display as text ///
        "Dynamic DDD joint post p             = " ///
        %9.4f scalar(ns_ddd_post_p_`y')

    display as text ///
        "Implementation DDD = Announcement p  = " ///
        %9.4f scalar(ns_impl_vs_ann_p_`y')
}


display as result "======================================================================"
display as result "END OF 09 NUTRIENT SHARES / QUALITY ANALYSIS"
display as result "======================================================================"
