*===============================================================================
* PAPER 2 — ALTERNATIVE HETEROGENEITY DEFINITIONS
* File: analyses/03b_heterogeneity_alternative_definitions.do
*
* PURPOSE
*   Re-estimate nutrition heterogeneity using definitions that do not rely only
*   on the household bottom-quartile split.
*
* ANALYSES
*   A. Continuous INDIVIDUAL baseline-calorie constraint
*   B. INDIVIDUAL baseline-calorie bottom quartile
*   C. Baseline-income bottom quartile
*   D. Existing HOUSEHOLD baseline-calorie bottom quartile (robustness)
*
* IDENTIFICATION
*   Fully saturated DDD:
*
*       Hunan x Post
*       Heterogeneity measure x Post
*       Hunan x Heterogeneity measure x Post
*
*   Dynamic DDD:
*
*       Hunan x Year
*       Heterogeneity measure x Year
*       Hunan x Heterogeneity measure x Year
*
*   2000 is the omitted reference year.
*
* POLICY TIMING
*   MGPP announced in 2004, implemented in Hunan in 2005.
*   Main timing therefore treats 2004 as treatment/exposure onset.
*
* IMPORTANT
*   - Main specifications use individual FE + wave FE and NO contemporaneous
*     controls.
*   - RD1 controls are used only as robustness.
*   - The main DDD pretrend test is the triple interaction for 1997 relative
*     to 2000.
*   - With only one clean pre-treatment lead, this is a limited diagnostic,
*     not proof of parallel trends.
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED PACKAGES
*===============================================================================

local outcomes kcal carbo fat protn

local RD1 ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real"


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


*===============================================================================
* 1. DEFINE HUNAN-GUIZHOU PURE-CONSUMER ANALYSIS SAMPLE
*===============================================================================

foreach v in sample_hg treated_hg sample_pc {
    capture drop `v'
}


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
            "Neither t1 nor province_code exists."
        exit 111
    }

    gen byte sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte treated_hg = ///
        (province_code == 43) ///
        if sample_hg == 1
}


capture confirm variable consumer_base

if _rc {
    display as error ///
        "consumer_base not found. Run the pure-consumer preparation first."
    exit 111
}


gen byte sample_pc = ///
    sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


label define hg_treat ///
    0 "Guizhou" ///
    1 "Hunan", ///
    replace

label values treated_hg hg_treat


display as text "============================================================"
display as text "HUNAN-GUIZHOU PURE-CONSUMER SAMPLE"
display as text "============================================================"

tab treated_hg ///
    if sample_pc == 1, ///
    missing

tab wave ///
    if sample_pc == 1, ///
    missing


*===============================================================================
* 2. ANNOUNCEMENT-BASED POLICY TIMING
*
* 2000 = omitted reference / last clean pre-treatment wave
* 2004 = announcement / exposure onset
*===============================================================================

foreach v in ///
    post_ann ///
    did_ann ///
    evt_m7_ann ///
    evt_p0_ann ///
    evt_p2_ann ///
    evt_p5_ann ///
    evt_p7_ann {

    capture drop `v'
}


gen byte post_ann = ///
    (wave >= 2004) ///
    if sample_hg == 1


gen byte did_ann = ///
    treated_hg * post_ann ///
    if sample_hg == 1


gen byte evt_m7_ann = ///
    treated_hg * (wave == 1997) ///
    if sample_hg == 1

* 2000 omitted.

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


label variable did_ann ///
    "Hunan x Post"

label variable post_ann ///
    "Post-2004 announcement"


*===============================================================================
* 3. INDIVIDUAL BASELINE CALORIES
*
* Baseline period = 1997 and 2000 only.
*
* pre_kcal_i:
*   individual's mean observed calorie intake across 1997/2000.
*
* kcal_constraint_std:
*   negative standardized baseline calories.
*   Higher value = lower baseline calories / greater baseline constraint.
*
* This sign convention makes a POSITIVE continuous DDD coefficient mean:
*   stronger policy response among individuals with lower baseline calories.
*===============================================================================

foreach v in ///
    pre_kcal97_i ///
    pre_kcal00_i ///
    pre_kcal_i ///
    pre_kcal_n_i ///
    pre_kcal_std_i ///
    kcal_constraint_std ///
    qkcal_i ///
    lowKCAL_i_q25 ///
    tag_pre_kcal_i {

    capture drop `v'
}


bysort IDind: egen pre_kcal97_i = max( ///
    cond( ///
        wave == 1997 ///
        & sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen pre_kcal00_i = max( ///
    cond( ///
        wave == 2000 ///
        & sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


egen pre_kcal_i = rowmean( ///
    pre_kcal97_i ///
    pre_kcal00_i ///
)


gen byte pre_kcal_n_i = ///
    !missing(pre_kcal97_i) ///
    + !missing(pre_kcal00_i)


label variable pre_kcal_i ///
    "Individual mean calories in 1997/2000"

label variable pre_kcal_n_i ///
    "Number of clean pre-policy kcal observations"


* Calculate standardization and quartiles with ONE observation per individual.
preserve

    keep if sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(pre_kcal_i)

    keep IDind pre_kcal_i pre_kcal_n_i

    bysort IDind: keep if _n == 1

    isid IDind

    egen pre_kcal_std_i = std(pre_kcal_i)

    xtile qkcal_i = pre_kcal_i, nq(4)

    keep IDind pre_kcal_std_i qkcal_i

    tempfile individual_kcal_groups
    save `individual_kcal_groups'

restore


merge m:1 IDind ///
    using `individual_kcal_groups', ///
    nogen ///
    keep(master match)


gen double kcal_constraint_std = ///
    -pre_kcal_std_i ///
    if !missing(pre_kcal_std_i)


gen byte lowKCAL_i_q25 = ///
    (qkcal_i == 1) ///
    if !missing(qkcal_i)


label variable pre_kcal_std_i ///
    "Standardized individual baseline calories"

label variable kcal_constraint_std ///
    "Baseline calorie constraint, higher = lower pre-policy kcal"

label variable lowKCAL_i_q25 ///
    "Individual baseline calories: bottom 25%"


* Verify time-invariance.
bysort IDind: egen double __kmin = min(kcal_constraint_std)
bysort IDind: egen double __kmax = max(kcal_constraint_std)

assert __kmin == __kmax ///
    if !missing(__kmin, __kmax)

drop __kmin __kmax


bysort IDind: egen byte __qmin = min(lowKCAL_i_q25)
bysort IDind: egen byte __qmax = max(lowKCAL_i_q25)

assert __qmin == __qmax ///
    if !missing(__qmin, __qmax)

drop __qmin __qmax


display as text "============================================================"
display as text "INDIVIDUAL BASELINE-CALORIE DIAGNOSTICS"
display as text "============================================================"

egen tag_pre_kcal_i = tag(IDind) ///
    if sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(pre_kcal_i)

tab pre_kcal_n_i ///
    if tag_pre_kcal_i == 1, ///
    missing

summarize pre_kcal_i ///
    if tag_pre_kcal_i == 1, ///
    detail

tab lowKCAL_i_q25 treated_hg ///
    if tag_pre_kcal_i == 1, ///
    column


*===============================================================================
* 4. INDIVIDUAL BASELINE INCOME
*
* Uses the individual's observed household income in 1997/2000.
* The group is fixed at the individual level.
*===============================================================================

foreach v in ///
    pre_inc97_i ///
    pre_inc00_i ///
    pre_inc_i ///
    pre_inc_n_i ///
    qinc_i ///
    lowINC_i_q25 ///
    tag_pre_inc_i {

    capture drop `v'
}


bysort IDind: egen pre_inc97_i = max( ///
    cond( ///
        wave == 1997 ///
        & sample_pc == 1 ///
        & !missing(lnHHINC_real), ///
        lnHHINC_real, ///
        . ///
    ) ///
)


bysort IDind: egen pre_inc00_i = max( ///
    cond( ///
        wave == 2000 ///
        & sample_pc == 1 ///
        & !missing(lnHHINC_real), ///
        lnHHINC_real, ///
        . ///
    ) ///
)


egen pre_inc_i = rowmean( ///
    pre_inc97_i ///
    pre_inc00_i ///
)


gen byte pre_inc_n_i = ///
    !missing(pre_inc97_i) ///
    + !missing(pre_inc00_i)


preserve

    keep if sample_hg == 1 ///
        & consumer_base == 1 ///
        & !missing(pre_inc_i)

    keep IDind pre_inc_i pre_inc_n_i

    bysort IDind: keep if _n == 1

    isid IDind

    xtile qinc_i = pre_inc_i, nq(4)

    keep IDind qinc_i

    tempfile individual_income_groups
    save `individual_income_groups'

restore


merge m:1 IDind ///
    using `individual_income_groups', ///
    nogen ///
    keep(master match)


gen byte lowINC_i_q25 = ///
    (qinc_i == 1) ///
    if !missing(qinc_i)


label variable pre_inc_i ///
    "Individual baseline household income, mean 1997/2000"

label variable lowINC_i_q25 ///
    "Baseline income: bottom 25%"


bysort IDind: egen byte __imin = min(lowINC_i_q25)
bysort IDind: egen byte __imax = max(lowINC_i_q25)

assert __imin == __imax ///
    if !missing(__imin, __imax)

drop __imin __imax


egen tag_pre_inc_i = tag(IDind) ///
    if sample_hg == 1 ///
    & consumer_base == 1 ///
    & !missing(pre_inc_i)


display as text "============================================================"
display as text "BASELINE-INCOME DIAGNOSTICS"
display as text "============================================================"

tab pre_inc_n_i ///
    if tag_pre_inc_i == 1, ///
    missing

tab lowINC_i_q25 treated_hg ///
    if tag_pre_inc_i == 1, ///
    column


*===============================================================================
* 5. DEFINE ANALYSIS SAMPLES
*===============================================================================

foreach v in ///
    sample_cont ///
    sample_iq25 ///
    sample_income ///
    sample_hhq25 {

    capture drop `v'
}


gen byte sample_cont = ///
    sample_pc == 1 ///
    & !missing(kcal_constraint_std)


gen byte sample_iq25 = ///
    sample_pc == 1 ///
    & !missing(lowKCAL_i_q25)


gen byte sample_income = ///
    sample_pc == 1 ///
    & !missing(lowINC_i_q25)


capture confirm variable lowS1_q25_fixed

if !_rc {

    gen byte sample_hhq25 = ///
        sample_pc == 1 ///
        & !missing(lowS1_q25_fixed)
}

else {

    gen byte sample_hhq25 = 0

    display as text ///
        "NOTE: lowS1_q25_fixed not found; household-q25 robustness will be skipped."
}


*===============================================================================
* 6. ANALYSIS A — CONTINUOUS INDIVIDUAL BASELINE-CALORIE DDD
*
* Main parameter:
*   ddd_cont = Hunan x Post x baseline calorie constraint
*
* Because higher kcal_constraint_std means LOWER baseline calories:
*   positive ddd_cont = stronger response among lower-baseline-kcal individuals.
*===============================================================================

foreach v in ///
    kcalcon_post ///
    ddd_cont ///
    kcalcon_evt_m7 ///
    kcalcon_evt_p0 ///
    kcalcon_evt_p2 ///
    kcalcon_evt_p5 ///
    kcalcon_evt_p7 ///
    dddcont_evt_m7 ///
    dddcont_evt_p0 ///
    dddcont_evt_p2 ///
    dddcont_evt_p5 ///
    dddcont_evt_p7 {

    capture drop `v'
}


gen double kcalcon_post = ///
    kcal_constraint_std * post_ann ///
    if sample_cont == 1


gen double ddd_cont = ///
    treated_hg * kcal_constraint_std * post_ann ///
    if sample_cont == 1


gen double kcalcon_evt_m7 = ///
    kcal_constraint_std * (wave == 1997) ///
    if sample_cont == 1

gen double kcalcon_evt_p0 = ///
    kcal_constraint_std * (wave == 2004) ///
    if sample_cont == 1

gen double kcalcon_evt_p2 = ///
    kcal_constraint_std * (wave == 2006) ///
    if sample_cont == 1

gen double kcalcon_evt_p5 = ///
    kcal_constraint_std * (wave == 2009) ///
    if sample_cont == 1

gen double kcalcon_evt_p7 = ///
    kcal_constraint_std * (wave == 2011) ///
    if sample_cont == 1


gen double dddcont_evt_m7 = ///
    treated_hg * kcal_constraint_std * (wave == 1997) ///
    if sample_cont == 1

gen double dddcont_evt_p0 = ///
    treated_hg * kcal_constraint_std * (wave == 2004) ///
    if sample_cont == 1

gen double dddcont_evt_p2 = ///
    treated_hg * kcal_constraint_std * (wave == 2006) ///
    if sample_cont == 1

gen double dddcont_evt_p5 = ///
    treated_hg * kcal_constraint_std * (wave == 2009) ///
    if sample_cont == 1

gen double dddcont_evt_p7 = ///
    treated_hg * kcal_constraint_std * (wave == 2011) ///
    if sample_cont == 1


*-------------------------------------------------------------------------------
* 6A. Average continuous DDD — preferred main specification
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        kcalcon_post ///
        ddd_cont ///
        if sample_cont == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo CONT_DID_`y'

    test ddd_cont

    scalar cont_ddd_b_`y' = _b[ddd_cont]
    scalar cont_ddd_p_`y' = r(p)

    estimates save ///
        "$P2_MODELS/03b_CONT_DID_`y'.ster", ///
        replace
}


esttab ///
    CONT_DID_kcal ///
    CONT_DID_carbo ///
    CONT_DID_fat ///
    CONT_DID_protn ///
    using "$P2_TABLES/03b_continuous_individual_kcal_DDD.rtf", ///
    replace ///
    keep( ///
        did_ann ///
        kcalcon_post ///
        ddd_cont ///
    ) ///
    order( ///
        did_ann ///
        kcalcon_post ///
        ddd_cont ///
    ) ///
    coeflabels( ///
        did_ann ///
            "Hunan x Post" ///
        kcalcon_post ///
            "Calorie constraint x Post" ///
        ddd_cont ///
            "Hunan x Calorie constraint x Post (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Continuous individual baseline-calorie heterogeneity" ///
    ) ///
    addnotes( ///
        "Higher calorie-constraint index = lower baseline individual calories", ///
        "Baseline calories use 1997 and 2000 only", ///
        "Reference period: 2000", ///
        "Treatment onset: 2004 policy announcement", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 6B. Dynamic continuous DDD
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        kcalcon_evt_m7 ///
        kcalcon_evt_p0 ///
        kcalcon_evt_p2 ///
        kcalcon_evt_p5 ///
        kcalcon_evt_p7 ///
        dddcont_evt_m7 ///
        dddcont_evt_p0 ///
        dddcont_evt_p2 ///
        dddcont_evt_p5 ///
        dddcont_evt_p7 ///
        if sample_cont == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo CONT_ES_`y'

    test dddcont_evt_m7

    scalar cont_pre_b_`y' = _b[dddcont_evt_m7]
    scalar cont_pre_p_`y' = r(p)

    estimates save ///
        "$P2_MODELS/03b_CONT_ES_`y'.ster", ///
        replace
}


esttab ///
    CONT_ES_kcal ///
    CONT_ES_carbo ///
    CONT_ES_fat ///
    CONT_ES_protn ///
    using "$P2_TABLES/03b_continuous_individual_kcal_event.rtf", ///
    replace ///
    keep( ///
        dddcont_evt_m7 ///
        dddcont_evt_p0 ///
        dddcont_evt_p2 ///
        dddcont_evt_p5 ///
        dddcont_evt_p7 ///
    ) ///
    order( ///
        dddcont_evt_m7 ///
        dddcont_evt_p0 ///
        dddcont_evt_p2 ///
        dddcont_evt_p5 ///
        dddcont_evt_p7 ///
    ) ///
    coeflabels( ///
        dddcont_evt_m7 ///
            "DDD x constraint: 1997" ///
        dddcont_evt_p0 ///
            "DDD x constraint: 2004" ///
        dddcont_evt_p2 ///
            "DDD x constraint: 2006" ///
        dddcont_evt_p5 ///
            "DDD x constraint: 2009" ///
        dddcont_evt_p7 ///
            "DDD x constraint: 2011" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD: continuous individual baseline-calorie constraint" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "1997 triple interaction is the pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 6C. Controlled robustness
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        kcalcon_post ///
        ddd_cont ///
        `RD1' ///
        if sample_cont == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo CONT_CTRL_`y'

    test ddd_cont

    scalar cont_ctrl_b_`y' = _b[ddd_cont]
    scalar cont_ctrl_p_`y' = r(p)
}


*===============================================================================
* 7. ANALYSIS B — INDIVIDUAL BOTTOM-QUARTILE BASELINE-CALORIE DDD
*===============================================================================

foreach v in ///
    lowi_post ///
    ddd_iq25 ///
    lowi_evt_m7 ///
    lowi_evt_p0 ///
    lowi_evt_p2 ///
    lowi_evt_p5 ///
    lowi_evt_p7 ///
    dddiq_evt_m7 ///
    dddiq_evt_p0 ///
    dddiq_evt_p2 ///
    dddiq_evt_p5 ///
    dddiq_evt_p7 {

    capture drop `v'
}


gen byte lowi_post = ///
    lowKCAL_i_q25 * post_ann ///
    if sample_iq25 == 1


gen byte ddd_iq25 = ///
    treated_hg * lowKCAL_i_q25 * post_ann ///
    if sample_iq25 == 1


gen byte lowi_evt_m7 = ///
    lowKCAL_i_q25 * (wave == 1997) ///
    if sample_iq25 == 1

gen byte lowi_evt_p0 = ///
    lowKCAL_i_q25 * (wave == 2004) ///
    if sample_iq25 == 1

gen byte lowi_evt_p2 = ///
    lowKCAL_i_q25 * (wave == 2006) ///
    if sample_iq25 == 1

gen byte lowi_evt_p5 = ///
    lowKCAL_i_q25 * (wave == 2009) ///
    if sample_iq25 == 1

gen byte lowi_evt_p7 = ///
    lowKCAL_i_q25 * (wave == 2011) ///
    if sample_iq25 == 1


gen byte dddiq_evt_m7 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 1997) ///
    if sample_iq25 == 1

gen byte dddiq_evt_p0 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2004) ///
    if sample_iq25 == 1

gen byte dddiq_evt_p2 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2006) ///
    if sample_iq25 == 1

gen byte dddiq_evt_p5 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2009) ///
    if sample_iq25 == 1

gen byte dddiq_evt_p7 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2011) ///
    if sample_iq25 == 1


*-------------------------------------------------------------------------------
* 7A. Average DDD
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        lowi_post ///
        ddd_iq25 ///
        if sample_iq25 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo IQ25_DID_`y'

    test ddd_iq25

    scalar iq25_ddd_b_`y' = _b[ddd_iq25]
    scalar iq25_ddd_p_`y' = r(p)
}


esttab ///
    IQ25_DID_kcal ///
    IQ25_DID_carbo ///
    IQ25_DID_fat ///
    IQ25_DID_protn ///
    using "$P2_TABLES/03b_individual_q25_kcal_DDD.rtf", ///
    replace ///
    keep( ///
        did_ann ///
        lowi_post ///
        ddd_iq25 ///
    ) ///
    order( ///
        did_ann ///
        lowi_post ///
        ddd_iq25 ///
    ) ///
    coeflabels( ///
        did_ann ///
            "Hunan x Post" ///
        lowi_post ///
            "Individual low-kcal x Post" ///
        ddd_iq25 ///
            "Hunan x Individual low-kcal x Post (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Individual baseline-calorie bottom-quartile DDD" ///
    ) ///
    addnotes( ///
        "Low group defined from individual mean calories in 1997/2000", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 7B. Dynamic DDD
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        lowi_evt_m7 ///
        lowi_evt_p0 ///
        lowi_evt_p2 ///
        lowi_evt_p5 ///
        lowi_evt_p7 ///
        dddiq_evt_m7 ///
        dddiq_evt_p0 ///
        dddiq_evt_p2 ///
        dddiq_evt_p5 ///
        dddiq_evt_p7 ///
        if sample_iq25 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo IQ25_ES_`y'

    test dddiq_evt_m7

    scalar iq25_pre_b_`y' = _b[dddiq_evt_m7]
    scalar iq25_pre_p_`y' = r(p)
}


esttab ///
    IQ25_ES_kcal ///
    IQ25_ES_carbo ///
    IQ25_ES_fat ///
    IQ25_ES_protn ///
    using "$P2_TABLES/03b_individual_q25_kcal_event.rtf", ///
    replace ///
    keep( ///
        dddiq_evt_m7 ///
        dddiq_evt_p0 ///
        dddiq_evt_p2 ///
        dddiq_evt_p5 ///
        dddiq_evt_p7 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD: individual baseline-calorie bottom quartile" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "1997 triple interaction is the pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 8. ANALYSIS C — BASELINE-INCOME BOTTOM-QUARTILE DDD
*===============================================================================

foreach v in ///
    lowinc_post ///
    ddd_income ///
    lowinc_evt_m7 ///
    lowinc_evt_p0 ///
    lowinc_evt_p2 ///
    lowinc_evt_p5 ///
    lowinc_evt_p7 ///
    dddinc_evt_m7 ///
    dddinc_evt_p0 ///
    dddinc_evt_p2 ///
    dddinc_evt_p5 ///
    dddinc_evt_p7 {

    capture drop `v'
}


gen byte lowinc_post = ///
    lowINC_i_q25 * post_ann ///
    if sample_income == 1


gen byte ddd_income = ///
    treated_hg * lowINC_i_q25 * post_ann ///
    if sample_income == 1


gen byte lowinc_evt_m7 = ///
    lowINC_i_q25 * (wave == 1997) ///
    if sample_income == 1

gen byte lowinc_evt_p0 = ///
    lowINC_i_q25 * (wave == 2004) ///
    if sample_income == 1

gen byte lowinc_evt_p2 = ///
    lowINC_i_q25 * (wave == 2006) ///
    if sample_income == 1

gen byte lowinc_evt_p5 = ///
    lowINC_i_q25 * (wave == 2009) ///
    if sample_income == 1

gen byte lowinc_evt_p7 = ///
    lowINC_i_q25 * (wave == 2011) ///
    if sample_income == 1


gen byte dddinc_evt_m7 = ///
    treated_hg * lowINC_i_q25 * (wave == 1997) ///
    if sample_income == 1

gen byte dddinc_evt_p0 = ///
    treated_hg * lowINC_i_q25 * (wave == 2004) ///
    if sample_income == 1

gen byte dddinc_evt_p2 = ///
    treated_hg * lowINC_i_q25 * (wave == 2006) ///
    if sample_income == 1

gen byte dddinc_evt_p5 = ///
    treated_hg * lowINC_i_q25 * (wave == 2009) ///
    if sample_income == 1

gen byte dddinc_evt_p7 = ///
    treated_hg * lowINC_i_q25 * (wave == 2011) ///
    if sample_income == 1


*-------------------------------------------------------------------------------
* 8A. Average DDD
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        lowinc_post ///
        ddd_income ///
        if sample_income == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_DID_`y'

    test ddd_income

    scalar inc_ddd_b_`y' = _b[ddd_income]
    scalar inc_ddd_p_`y' = r(p)
}


esttab ///
    INC_DID_kcal ///
    INC_DID_carbo ///
    INC_DID_fat ///
    INC_DID_protn ///
    using "$P2_TABLES/03b_baseline_income_DDD.rtf", ///
    replace ///
    keep( ///
        did_ann ///
        lowinc_post ///
        ddd_income ///
    ) ///
    order( ///
        did_ann ///
        lowinc_post ///
        ddd_income ///
    ) ///
    coeflabels( ///
        did_ann ///
            "Hunan x Post" ///
        lowinc_post ///
            "Low baseline income x Post" ///
        ddd_income ///
            "Hunan x Low income x Post (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-income heterogeneity DDD" ///
    ) ///
    addnotes( ///
        "Low income = bottom quartile of individual pre-policy household income", ///
        "Baseline period: 1997/2000", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*-------------------------------------------------------------------------------
* 8B. Dynamic DDD
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        lowinc_evt_m7 ///
        lowinc_evt_p0 ///
        lowinc_evt_p2 ///
        lowinc_evt_p5 ///
        lowinc_evt_p7 ///
        dddinc_evt_m7 ///
        dddinc_evt_p0 ///
        dddinc_evt_p2 ///
        dddinc_evt_p5 ///
        dddinc_evt_p7 ///
        if sample_income == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo INC_ES_`y'

    test dddinc_evt_m7

    scalar inc_pre_b_`y' = _b[dddinc_evt_m7]
    scalar inc_pre_p_`y' = r(p)
}


esttab ///
    INC_ES_kcal ///
    INC_ES_carbo ///
    INC_ES_fat ///
    INC_ES_protn ///
    using "$P2_TABLES/03b_baseline_income_event.rtf", ///
    replace ///
    keep( ///
        dddinc_evt_m7 ///
        dddinc_evt_p0 ///
        dddinc_evt_p2 ///
        dddinc_evt_p5 ///
        dddinc_evt_p7 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD: baseline-income heterogeneity" ///
    ) ///
    addnotes( ///
        "Reference period: 2000", ///
        "1997 triple interaction is the pretrend diagnostic", ///
        "Individual and wave fixed effects", ///
        "No contemporaneous controls", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 9. ANALYSIS D — EXISTING HOUSEHOLD-Q25 DDD AS ROBUSTNESS
*
* Requires lowS1_q25_fixed from prep/05_baseline_groups.do.
*===============================================================================

capture confirm variable lowS1_q25_fixed

if !_rc {

    foreach v in ///
        hhq_post ///
        ddd_hhq25 ///
        hhq_evt_m7 ///
        hhq_evt_p0 ///
        hhq_evt_p2 ///
        hhq_evt_p5 ///
        hhq_evt_p7 ///
        dddhh_evt_m7 ///
        dddhh_evt_p0 ///
        dddhh_evt_p2 ///
        dddhh_evt_p5 ///
        dddhh_evt_p7 {

        capture drop `v'
    }


    gen byte hhq_post = ///
        lowS1_q25_fixed * post_ann ///
        if sample_hhq25 == 1


    gen byte ddd_hhq25 = ///
        treated_hg * lowS1_q25_fixed * post_ann ///
        if sample_hhq25 == 1


    gen byte hhq_evt_m7 = ///
        lowS1_q25_fixed * (wave == 1997) ///
        if sample_hhq25 == 1

    gen byte hhq_evt_p0 = ///
        lowS1_q25_fixed * (wave == 2004) ///
        if sample_hhq25 == 1

    gen byte hhq_evt_p2 = ///
        lowS1_q25_fixed * (wave == 2006) ///
        if sample_hhq25 == 1

    gen byte hhq_evt_p5 = ///
        lowS1_q25_fixed * (wave == 2009) ///
        if sample_hhq25 == 1

    gen byte hhq_evt_p7 = ///
        lowS1_q25_fixed * (wave == 2011) ///
        if sample_hhq25 == 1


    gen byte dddhh_evt_m7 = ///
        treated_hg * lowS1_q25_fixed * (wave == 1997) ///
        if sample_hhq25 == 1

    gen byte dddhh_evt_p0 = ///
        treated_hg * lowS1_q25_fixed * (wave == 2004) ///
        if sample_hhq25 == 1

    gen byte dddhh_evt_p2 = ///
        treated_hg * lowS1_q25_fixed * (wave == 2006) ///
        if sample_hhq25 == 1

    gen byte dddhh_evt_p5 = ///
        treated_hg * lowS1_q25_fixed * (wave == 2009) ///
        if sample_hhq25 == 1

    gen byte dddhh_evt_p7 = ///
        treated_hg * lowS1_q25_fixed * (wave == 2011) ///
        if sample_hhq25 == 1


    eststo clear


    foreach y of local outcomes {

        reghdfe lnd3`y' ///
            did_ann ///
            hhq_post ///
            ddd_hhq25 ///
            if sample_hhq25 == 1, ///
            absorb(IDind wave) ///
            vce(cluster cluster_commid)

        eststo HHQ_DID_`y'

        test ddd_hhq25

        scalar hhq_ddd_b_`y' = _b[ddd_hhq25]
        scalar hhq_ddd_p_`y' = r(p)
    }


    esttab ///
        HHQ_DID_kcal ///
        HHQ_DID_carbo ///
        HHQ_DID_fat ///
        HHQ_DID_protn ///
        using "$P2_TABLES/03b_household_q25_robustness_DDD.rtf", ///
        replace ///
        keep( ///
            did_ann ///
            hhq_post ///
            ddd_hhq25 ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title( ///
            "Household baseline-calorie q25 DDD: robustness" ///
        )


    eststo clear


    foreach y of local outcomes {

        reghdfe lnd3`y' ///
            evt_m7_ann ///
            evt_p0_ann ///
            evt_p2_ann ///
            evt_p5_ann ///
            evt_p7_ann ///
            hhq_evt_m7 ///
            hhq_evt_p0 ///
            hhq_evt_p2 ///
            hhq_evt_p5 ///
            hhq_evt_p7 ///
            dddhh_evt_m7 ///
            dddhh_evt_p0 ///
            dddhh_evt_p2 ///
            dddhh_evt_p5 ///
            dddhh_evt_p7 ///
            if sample_hhq25 == 1, ///
            absorb(IDind wave) ///
            vce(cluster cluster_commid)

        test dddhh_evt_m7

        scalar hhq_pre_b_`y' = _b[dddhh_evt_m7]
        scalar hhq_pre_p_`y' = r(p)
    }
}


*===============================================================================
* 10. OPTIONAL STRICT PRE-POLICY-BALANCED ROBUSTNESS
*
* This does NOT replace the main sample.
* It shows whether the continuous / individual-q25 findings survive when the
* baseline measure is based on BOTH 1997 and 2000 observations.
*===============================================================================

foreach v in sample_cont_pre2 sample_iq25_pre2 {
    capture drop `v'
}


gen byte sample_cont_pre2 = ///
    sample_cont == 1 ///
    & pre_kcal_n_i == 2


gen byte sample_iq25_pre2 = ///
    sample_iq25 == 1 ///
    & pre_kcal_n_i == 2


display as text "============================================================"
display as text "STRICT TWO-PRE-WAVE ROBUSTNESS — SAMPLE COUNTS"
display as text "============================================================"

egen byte __tag_cont2 = tag(IDind) ///
    if sample_cont_pre2 == 1

quietly count if __tag_cont2 == 1

display as text ///
    "Continuous baseline: individuals with both 1997 and 2000 = " ///
    r(N)

drop __tag_cont2


foreach y of local outcomes {

    reghdfe lnd3`y' ///
        did_ann ///
        kcalcon_post ///
        ddd_cont ///
        if sample_cont_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    test ddd_cont

    scalar cont_pre2_b_`y' = _b[ddd_cont]
    scalar cont_pre2_p_`y' = r(p)


    reghdfe lnd3`y' ///
        did_ann ///
        lowi_post ///
        ddd_iq25 ///
        if sample_iq25_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    test ddd_iq25

    scalar iq25_pre2_b_`y' = _b[ddd_iq25]
    scalar iq25_pre2_p_`y' = r(p)
}


*===============================================================================
* 11. COMPACT SUMMARY
*===============================================================================

display as text "============================================================"
display as text "ALTERNATIVE HETEROGENEITY SUMMARY"
display as text "============================================================"

display as text ///
    "Interpretation: continuous index is coded so HIGHER = LOWER baseline kcal."

display as text ///
    "Therefore a POSITIVE continuous DDD means a stronger Hunan post response" ///
    " among more calorie-constrained individuals."

display as text "------------------------------------------------------------"


foreach y of local outcomes {

    display as text "OUTCOME: `y'"

    display as text ///
        "Continuous individual kcal DDD = " ///
        %9.4f scalar(cont_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(cont_ddd_p_`y')

    display as text ///
        "Continuous DDD pretrend p      = " ///
        %9.4f scalar(cont_pre_p_`y')

    display as text ///
        "Individual q25 kcal DDD        = " ///
        %9.4f scalar(iq25_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(iq25_ddd_p_`y')

    display as text ///
        "Individual q25 pretrend p      = " ///
        %9.4f scalar(iq25_pre_p_`y')

    display as text ///
        "Baseline-income DDD            = " ///
        %9.4f scalar(inc_ddd_b_`y') ///
        "   p = " ///
        %9.4f scalar(inc_ddd_p_`y')

    display as text ///
        "Baseline-income pretrend p     = " ///
        %9.4f scalar(inc_pre_p_`y')

    capture confirm scalar hhq_ddd_b_`y'

    if !_rc {

        display as text ///
            "Household q25 DDD robustness   = " ///
            %9.4f scalar(hhq_ddd_b_`y') ///
            "   p = " ///
            %9.4f scalar(hhq_ddd_p_`y')

        display as text ///
            "Household q25 pretrend p       = " ///
            %9.4f scalar(hhq_pre_p_`y')
    }

    display as text ///
        "Continuous both-pre-waves DDD   = " ///
        %9.4f scalar(cont_pre2_b_`y') ///
        "   p = " ///
        %9.4f scalar(cont_pre2_p_`y')

    display as text ///
        "Individual q25 both-pre-waves   = " ///
        %9.4f scalar(iq25_pre2_b_`y') ///
        "   p = " ///
        %9.4f scalar(iq25_pre2_p_`y')

    display as text "------------------------------------------------------------"
}


display as text "============================================================"
display as text "END OF ALTERNATIVE HETEROGENEITY ANALYSIS"
display as text "============================================================"

*===============================================================
* TWO-PRE-WAVE INDIVIDUAL-Q25: FULL DYNAMIC DDD
* Sample requires baseline kcal observed in BOTH 1997 and 2000
* Reference year = 2000
*===============================================================

foreach y in kcal carbo fat protn {

    display "=============================================="
    display "TWO-PRE-WAVE DYNAMIC DDD: `y'"
    display "=============================================="

    reghdfe lnd3`y' ///
        evt_m7_ann ///
        evt_p0_ann ///
        evt_p2_ann ///
        evt_p5_ann ///
        evt_p7_ann ///
        lowi_evt_m7 ///
        lowi_evt_p0 ///
        lowi_evt_p2 ///
        lowi_evt_p5 ///
        lowi_evt_p7 ///
        dddiq_evt_m7 ///
        dddiq_evt_p0 ///
        dddiq_evt_p2 ///
        dddiq_evt_p5 ///
        dddiq_evt_p7 ///
        if sample_iq25_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    * DDD pretrend
    test dddiq_evt_m7

    display "DDD PRETREND p-value = " r(p)

    * Joint post-treatment DDD test
    test ///
        dddiq_evt_p0 ///
        dddiq_evt_p2 ///
        dddiq_evt_p5 ///
        dddiq_evt_p7

    display "JOINT POST DDD p-value = " r(p)

}

drop post_impl did_impl lowi_post_impl ddd_iq25_impl
* Implementation period
gen byte post_impl = (wave >= 2006)

gen byte did_impl = treated_hg * post_impl
gen byte lowi_post_impl = lowKCAL_i_q25 * post_impl
gen byte ddd_iq25_impl = treated_hg * lowKCAL_i_q25 * post_impl

* Announcement year = 2004, separately controlled
gen byte hunan_ann2004 = treated_hg * (wave == 2004)
gen byte low_ann2004   = lowKCAL_i_q25 * (wave == 2004)
gen byte ddd_ann2004   = treated_hg * lowKCAL_i_q25 * (wave == 2004)

reghdfe lnd3kcal ///
    hunan_ann2004 ///
    low_ann2004 ///
    ddd_ann2004 ///
    did_impl ///
    lowi_post_impl ///
    ddd_iq25_impl ///
    if sample_iq25_pre2 == 1, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)

test ddd_iq25_impl
* 1. Low-calorie group's total implementation effect
lincom did_impl + ddd_iq25_impl

* 2. Announcement-period effect for low-calorie group
lincom hunan_ann2004 + ddd_ann2004

* 3. Is implementation heterogeneity larger than announcement heterogeneity?
test ddd_iq25_impl = ddd_ann2004
==========================================
* NOTES FOR INTERPRETATION
*
* 1. Do not choose the preferred specification based on significance.
*
* 2. If continuous individual baseline calories produce a stable pattern while
*    household-q25 does not, the interpretation should emphasize that the
*    response varies smoothly with baseline nutritional status rather than
*    discontinuously at an arbitrary quartile cutoff.
*
* 3. If individual-q25 differs from household-q25, discuss the unit of the
*    heterogeneity measure: individual nutritional status versus household
*    nutritional environment.
*
* 4. If baseline-income heterogeneity is present, it is evidence about economic
*    resources, not automatically proof of a calorie-subsistence mechanism.
*
* 5. If all properly saturated DDD estimates are near zero, report the null
*    treatment-specific heterogeneity result rather than searching across
*    cutoffs for significance.
*
* 6. A future "calorie adequacy" measure should only be added after choosing a
*    defensible external physiological-needs formula. Do not label a fitted
*    calorie-prediction model as physiological nutritional need.
*===============================================================================


* One-pre-wave people
reghdfe lnd3kcal ///
    did_ann lowi_post ddd_iq25 ///
    if sample_iq25==1 & pre_kcal_n_i==1, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)

* Two-pre-wave people
reghdfe lnd3kcal ///
    did_ann lowi_post ddd_iq25 ///
    if sample_iq25==1 & pre_kcal_n_i==2, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)


tab pre_kcal_n_i treated_hg
tab lowKCAL_i_q25 treated_hg if pre_kcal_n_i==1, col
tab lowKCAL_i_q25 treated_hg if pre_kcal_n_i==2, col



capture drop hunan_ann2004 low_ann2004 ddd_ann2004
capture drop did_impl lowi_post_impl ddd_iq25_impl
capture drop post_impl ann2004
*------------------------------------------------------------
* 1. Unique-individual composition
*------------------------------------------------------------

preserve

keep if sample_iq25 == 1
bysort IDind: keep if _n == 1

tab pre_kcal_n_i treated_hg, col

tab lowKCAL_i_q25 treated_hg if pre_kcal_n_i == 1, col
tab lowKCAL_i_q25 treated_hg if pre_kcal_n_i == 2, col

summ pre_kcal_i if pre_kcal_n_i == 1, detail
summ pre_kcal_i if pre_kcal_n_i == 2, detail

restore


reghdfe lnd3kcal ///
    evt_m7_ann ///
    evt_p0_ann evt_p2_ann evt_p5_ann evt_p7_ann ///
    lowi_evt_m7 ///
    lowi_evt_p0 lowi_evt_p2 lowi_evt_p5 lowi_evt_p7 ///
    dddiq_evt_m7 ///
    dddiq_evt_p0 dddiq_evt_p2 dddiq_evt_p5 dddiq_evt_p7 ///
    if sample_iq25 == 1 & pre_kcal_n_i == 1, ///
    absorb(IDind wave) ///
    vce(cluster cluster_commid)

test dddiq_evt_m7



*===============================================================================
* TWO-PRE-WAVE BASELINE-CALORIE HETEROGENEITY
*
* Baseline kcal:
*   mean of 1997 and 2000
*
* Preferred heterogeneity sample:
*   observed kcal in BOTH 1997 and 2000
*
* Policy timing:
*   2004 = announcement year
*   2005 = implementation in Hunan
*   2006 = first observed post-implementation CHNS wave
*
* Outcomes:
*   kcal, carbohydrate, fat, protein
*
* Reference year in dynamic DDD:
*   2000
*===============================================================================


*-------------------------------------------------------------------------------
* 0. SAMPLE
*-------------------------------------------------------------------------------

capture drop sample_pre2_hetero

gen byte sample_pre2_hetero = ///
    sample_iq25 == 1 ///
    & pre_kcal_n_i == 2


* Basic sample check
egen byte __tag_pre2 = tag(IDind) if sample_pre2_hetero == 1

count if __tag_pre2 == 1
display "Number of individuals = " r(N)

drop __tag_pre2


*-------------------------------------------------------------------------------
* 1. POLICY PERIOD VARIABLES
*-------------------------------------------------------------------------------

capture drop post_impl ann2004

gen byte post_impl = (wave >= 2006)
gen byte ann2004   = (wave == 2004)


*-------------------------------------------------------------------------------
* 2. POOLED IMPLEMENTATION DDD VARIABLES
*
* 2004 announcement is controlled separately.
*-------------------------------------------------------------------------------

foreach v in ///
    hunan_ann2004 ///
    low_ann2004 ///
    ddd_ann2004 ///
    did_impl ///
    lowi_post_impl ///
    ddd_iq25_impl {

    capture drop `v'
}


* Announcement-period lower-order terms
gen byte hunan_ann2004 = ///
    treated_hg * ann2004 ///
    if sample_pre2_hetero == 1

gen byte low_ann2004 = ///
    lowKCAL_i_q25 * ann2004 ///
    if sample_pre2_hetero == 1

gen byte ddd_ann2004 = ///
    treated_hg * lowKCAL_i_q25 * ann2004 ///
    if sample_pre2_hetero == 1


* Implementation-period lower-order terms
gen byte did_impl = ///
    treated_hg * post_impl ///
    if sample_pre2_hetero == 1

gen byte lowi_post_impl = ///
    lowKCAL_i_q25 * post_impl ///
    if sample_pre2_hetero == 1

gen byte ddd_iq25_impl = ///
    treated_hg * lowKCAL_i_q25 * post_impl ///
    if sample_pre2_hetero == 1


*-------------------------------------------------------------------------------
* 3. POOLED IMPLEMENTATION-PERIOD DDD
*-------------------------------------------------------------------------------

local outcomes kcal carbo fat protn

eststo clear


foreach y of local outcomes {

    display ""
    display "============================================================"
    display "POOLED IMPLEMENTATION DDD: `y'"
    display "============================================================"

    reghdfe lnd3`y' ///
        hunan_ann2004 ///
        low_ann2004 ///
        ddd_ann2004 ///
        did_impl ///
        lowi_post_impl ///
        ddd_iq25_impl ///
        if sample_pre2_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo IMPL_`y'


    *-----------------------------------------------------------
    * A. Main heterogeneity parameter
    *-----------------------------------------------------------

    test ddd_iq25_impl

    scalar impl_ddd_b_`y' = _b[ddd_iq25_impl]
    scalar impl_ddd_p_`y' = r(p)


    *-----------------------------------------------------------
    * B. Announcement-period DDD
    *-----------------------------------------------------------

    test ddd_ann2004

    scalar ann_ddd_b_`y' = _b[ddd_ann2004]
    scalar ann_ddd_p_`y' = r(p)


    *-----------------------------------------------------------
    * C. Total treatment effect for LOW baseline-kcal group
    *    during implementation period
    *-----------------------------------------------------------

    lincom did_impl + ddd_iq25_impl

    scalar low_impl_b_`y' = r(estimate)
    scalar low_impl_se_`y' = r(se)
    scalar low_impl_p_`y' = r(p)


    *-----------------------------------------------------------
    * D. Total treatment effect for LOW group in announcement year
    *-----------------------------------------------------------

    lincom hunan_ann2004 + ddd_ann2004

    scalar low_ann_b_`y' = r(estimate)
    scalar low_ann_se_`y' = r(se)
    scalar low_ann_p_`y' = r(p)


    *-----------------------------------------------------------
    * E. Is implementation heterogeneity different from
    *    announcement heterogeneity?
    *-----------------------------------------------------------

    test ddd_iq25_impl = ddd_ann2004

    scalar impl_vs_ann_p_`y' = r(p)
}


*-------------------------------------------------------------------------------
* 4. EXPORT POOLED DDD TABLE
*-------------------------------------------------------------------------------

esttab ///
    IMPL_kcal ///
    IMPL_carbo ///
    IMPL_fat ///
    IMPL_protn ///
    using "$P2_TABLES/03c_pre2_implementation_DDD.rtf", ///
    replace ///
    keep( ///
        hunan_ann2004 ///
        low_ann2004 ///
        ddd_ann2004 ///
        did_impl ///
        lowi_post_impl ///
        ddd_iq25_impl ///
    ) ///
    order( ///
        hunan_ann2004 ///
        low_ann2004 ///
        ddd_ann2004 ///
        did_impl ///
        lowi_post_impl ///
        ddd_iq25_impl ///
    ) ///
    coeflabels( ///
        hunan_ann2004 ///
            "Hunan x Announcement 2004" ///
        low_ann2004 ///
            "Low baseline kcal x Announcement 2004" ///
        ddd_ann2004 ///
            "Hunan x Low kcal x Announcement 2004" ///
        did_impl ///
            "Hunan x Implementation period" ///
        lowi_post_impl ///
            "Low baseline kcal x Implementation period" ///
        ddd_iq25_impl ///
            "Hunan x Low kcal x Implementation period (DDD)" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Baseline-calorie heterogeneity: implementation-period DDD" ///
    ) ///
    addnotes( ///
        "Baseline calorie status measured using 1997 and 2000", ///
        "Sample restricted to individuals observed in both pre-policy waves", ///
        "2004 treated separately as announcement year", ///
        "Implementation period: 2006, 2009, and 2011", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 5. FULL DYNAMIC DDD
*
* 2000 = omitted reference year
*
* Clean pretrend diagnostic:
*   1997 triple interaction
*
* 2004 = announcement
* 2006/2009/2011 = implementation observations
*===============================================================================


foreach v in ///
    h97 h04 h06 h09 h11 ///
    l97 l04 l06 l09 l11 ///
    d97 d04 d06 d09 d11 {

    capture drop `v'
}


* Hunan x wave
gen byte h97 = treated_hg * (wave == 1997) if sample_pre2_hetero == 1
gen byte h04 = treated_hg * (wave == 2004) if sample_pre2_hetero == 1
gen byte h06 = treated_hg * (wave == 2006) if sample_pre2_hetero == 1
gen byte h09 = treated_hg * (wave == 2009) if sample_pre2_hetero == 1
gen byte h11 = treated_hg * (wave == 2011) if sample_pre2_hetero == 1


* Low baseline kcal x wave
gen byte l97 = lowKCAL_i_q25 * (wave == 1997) if sample_pre2_hetero == 1
gen byte l04 = lowKCAL_i_q25 * (wave == 2004) if sample_pre2_hetero == 1
gen byte l06 = lowKCAL_i_q25 * (wave == 2006) if sample_pre2_hetero == 1
gen byte l09 = lowKCAL_i_q25 * (wave == 2009) if sample_pre2_hetero == 1
gen byte l11 = lowKCAL_i_q25 * (wave == 2011) if sample_pre2_hetero == 1


* Hunan x Low kcal x wave = dynamic DDD
gen byte d97 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 1997) ///
    if sample_pre2_hetero == 1

gen byte d04 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2004) ///
    if sample_pre2_hetero == 1

gen byte d06 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2006) ///
    if sample_pre2_hetero == 1

gen byte d09 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2009) ///
    if sample_pre2_hetero == 1

gen byte d11 = ///
    treated_hg * lowKCAL_i_q25 * (wave == 2011) ///
    if sample_pre2_hetero == 1


*-------------------------------------------------------------------------------
* 6. RUN DYNAMIC DDD FOR ALL OUTCOMES
*-------------------------------------------------------------------------------

eststo clear


foreach y of local outcomes {

    display ""
    display "============================================================"
    display "DYNAMIC DDD: `y'"
    display "Reference year = 2000"
    display "============================================================"

    reghdfe lnd3`y' ///
        h97 h04 h06 h09 h11 ///
        l97 l04 l06 l09 l11 ///
        d97 d04 d06 d09 d11 ///
        if sample_pre2_hetero == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    eststo ES_`y'


    *-----------------------------------------------------------
    * PRETREND TEST
    *
    * Only one clean pre-treatment lead:
    * 1997 relative to omitted 2000
    *-----------------------------------------------------------

    test d97

    scalar pre_b_`y' = _b[d97]
    scalar pre_p_`y' = r(p)

    display "DDD PRETREND:"
    display "1997 coefficient = " %9.4f _b[d97]
    display "1997 p-value     = " %9.4f r(p)


    *-----------------------------------------------------------
    * Announcement-period DDD
    *-----------------------------------------------------------

    test d04

    scalar dyn2004_b_`y' = _b[d04]
    scalar dyn2004_p_`y' = r(p)


    *-----------------------------------------------------------
    * JOINT IMPLEMENTATION-PERIOD DDD TEST
    * 2006 + 2009 + 2011
    *-----------------------------------------------------------

    test d06 d09 d11

    scalar postjoint_p_`y' = r(p)

    display "JOINT IMPLEMENTATION DDD p-value = " %9.4f r(p)


    *-----------------------------------------------------------
    * Display individual implementation coefficients
    *-----------------------------------------------------------

    display "2006 DDD = " %9.4f _b[d06]
    display "2009 DDD = " %9.4f _b[d09]
    display "2011 DDD = " %9.4f _b[d11]
}


*-------------------------------------------------------------------------------
* 7. EXPORT DYNAMIC DDD TABLE
*-------------------------------------------------------------------------------

esttab ///
    ES_kcal ///
    ES_carbo ///
    ES_fat ///
    ES_protn ///
    using "$P2_TABLES/03c_pre2_dynamic_DDD.rtf", ///
    replace ///
    keep( ///
        d97 ///
        d04 ///
        d06 ///
        d09 ///
        d11 ///
    ) ///
    order( ///
        d97 ///
        d04 ///
        d06 ///
        d09 ///
        d11 ///
    ) ///
    coeflabels( ///
        d97 "1997 x Hunan x Low kcal" ///
        d04 "2004 x Hunan x Low kcal" ///
        d06 "2006 x Hunan x Low kcal" ///
        d09 "2009 x Hunan x Low kcal" ///
        d11 "2011 x Hunan x Low kcal" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title( ///
        "Dynamic DDD by baseline calorie status" ///
    ) ///
    addnotes( ///
        "Reference year: 2000", ///
        "1997 triple interaction is the differential pretrend diagnostic", ///
        "2004 is the announcement wave", ///
        "2006, 2009, and 2011 are post-implementation observations", ///
        "Individual and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 8. COMPACT RESULTS SUMMARY
*===============================================================================

display ""
display "=========================================================================="
display "TWO-PRE-WAVE CALORIE HETEROGENEITY SUMMARY"
display "=========================================================================="

foreach y of local outcomes {

    display ""
    display "OUTCOME: `y'"
    display "--------------------------------------------------------------------------"

    display ///
        "Pretrend DDD 1997        = " ///
        %8.4f scalar(pre_b_`y') ///
        "   p = " ///
        %7.4f scalar(pre_p_`y')

    display ///
        "Announcement DDD 2004    = " ///
        %8.4f scalar(ann_ddd_b_`y') ///
        "   p = " ///
        %7.4f scalar(ann_ddd_p_`y')

    display ///
        "Implementation DDD       = " ///
        %8.4f scalar(impl_ddd_b_`y') ///
        "   p = " ///
        %7.4f scalar(impl_ddd_p_`y')

    display ///
        "Low-group impl total DID = " ///
        %8.4f scalar(low_impl_b_`y') ///
        "   p = " ///
        %7.4f scalar(low_impl_p_`y')

    display ///
        "Low-group ann total DID  = " ///
        %8.4f scalar(low_ann_b_`y') ///
        "   p = " ///
        %7.4f scalar(low_ann_p_`y')

    display ///
        "Impl DDD = Ann DDD test  p = " ///
        %7.4f scalar(impl_vs_ann_p_`y')

    display ///
        "Joint 2006/09/11 DDD test p = " ///
        %7.4f scalar(postjoint_p_`y')
}

display "=========================================================================="
