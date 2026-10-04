*===============================================================================
* PAPER 2 — EXPENDITURE CHANNEL
* File: analyses/10_expenditure_channel.do
*
* Purpose:
*   Dedicated analysis of real household expenditure as a mechanism/channel.
*
* Sample:
*   - Hunan (treated) vs Guizhou (control)
*   - baseline pure consumers
*   - waves: 1997, 2000, 2004, 2006, 2009, 2011
*
* Timing:
*   - 2000 = omitted/reference year
*   - 2004 = announcement / transition wave
*   - 2005 = implementation in Hunan
*   - 2006, 2009, 2011 = observed post-implementation waves
*
* Main outcome:
*   - lnhhexpense_real = ln(real household expenditure + 1)
*
* Estimation:
*   - one observation per household-wave
*   - household FE + wave FE
*   - SE clustered at community level
*   - no contemporaneous controls in preferred specification
*
* Parts:
*   A. Average expenditure DID
*   B. Expenditure event study
*   C. Household baseline-calorie heterogeneity (secondary)
*   D. Dynamic DDD by household baseline-calorie status (secondary)
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

foreach v in hhid wave consumer_base d3kcal {
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

* Main expenditure outcome.
capture confirm variable lnhhexpense_real
if _rc {
    capture confirm variable hhexpense_real
    if _rc {
        display as error "Neither lnhhexpense_real nor hhexpense_real exists."
        exit 111
    }

    gen double lnhhexpense_real = ln(hhexpense_real + 1) ///
        if hhexpense_real > -1 & hhexpense_real < .

    label variable lnhhexpense_real ///
        "Log real household expenditure plus one"
}


*===============================================================================
* 1. HUNAN–GUIZHOU BASELINE PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in ///
    exp_sample_hg ///
    exp_treated_hg ///
    exp_sample_pc {

    capture drop `v'
}

capture confirm variable t1

if !_rc {
    gen byte exp_sample_hg = inlist(t1, 43, 52)

    gen byte exp_treated_hg = ///
        (t1 == 43) ///
        if exp_sample_hg == 1
}
else {
    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists; cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte exp_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte exp_treated_hg = ///
        (province_code == 43) ///
        if exp_sample_hg == 1
}

gen byte exp_sample_pc = ///
    exp_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)

capture label drop exp_hg_treat
label define exp_hg_treat ///
    0 "Guizhou" ///
    1 "Hunan"

label values exp_treated_hg exp_hg_treat

display as text ""
display as result "============================================================"
display as result "10 EXPENDITURE CHANNEL — HUNAN / GUIZHOU PURE CONSUMERS"
display as result "============================================================"

tab exp_treated_hg if exp_sample_pc == 1, missing
tab wave if exp_sample_pc == 1, missing


*===============================================================================
* 2. ONE OBSERVATION PER HOUSEHOLD-WAVE
*===============================================================================

capture drop exp_tag_hhwave
egen byte exp_tag_hhwave = tag(hhid wave) ///
    if exp_sample_pc == 1

quietly count if ///
    exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1 ///
    & !missing(lnhhexpense_real)

display as result ///
    "Household-wave expenditure observations = " ///
    r(N)

* Diagnostic: household expenditure should be constant within household-wave.
capture drop __exp_min __exp_max

bysort hhid wave: egen double __exp_min = ///
    min(lnhhexpense_real) ///
    if exp_sample_pc == 1

bysort hhid wave: egen double __exp_max = ///
    max(lnhhexpense_real) ///
    if exp_sample_pc == 1

quietly count if ///
    exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1 ///
    & !missing(__exp_min, __exp_max) ///
    & abs(__exp_max - __exp_min) > 1e-10

if r(N) > 0 {
    display as error ///
        "WARNING: lnhhexpense_real varies within some household-waves: " ///
        r(N)
}
else {
    display as result ///
        "Within-household-wave expenditure consistency check: PASS"
}

drop __exp_min __exp_max


*===============================================================================
* 3. POLICY VARIABLES
*
* 2004 is separated from the implementation period.
*===============================================================================

foreach v in ///
    exp_ann2004 ///
    exp_post_impl ///
    exp_h_ann ///
    exp_h_impl {

    capture drop `v'
}

gen byte exp_ann2004 = ///
    (wave == 2004)

gen byte exp_post_impl = ///
    (wave >= 2006) ///
    if inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)

gen byte exp_h_ann = ///
    exp_treated_hg * exp_ann2004 ///
    if exp_sample_pc == 1

gen byte exp_h_impl = ///
    exp_treated_hg * exp_post_impl ///
    if exp_sample_pc == 1

label variable exp_h_ann ///
    "Hunan x Announcement 2004"

label variable exp_h_impl ///
    "Hunan x Implementation period"


*===============================================================================
* 4. PART A — AVERAGE EXPENDITURE DID
*===============================================================================

eststo clear

reghdfe lnhhexpense_real ///
    exp_h_ann ///
    exp_h_impl ///
    if exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1, ///
    absorb(hhid wave) ///
    vce(cluster cluster_commid)

test exp_h_ann
local ann_p = r(p)

test exp_h_impl
local impl_p = r(p)

estadd scalar announcement_p = `ann_p'
estadd scalar implementation_p = `impl_p'

eststo EXP_DID

display as text ""
display as result "AVERAGE EXPENDITURE DID"
display as result ///
    "Announcement coefficient   = " ///
    %9.4f _b[exp_h_ann] ///
    "   p = " %9.4f `ann_p'

display as result ///
    "Implementation coefficient = " ///
    %9.4f _b[exp_h_impl] ///
    "   p = " %9.4f `impl_p'

estimates save ///
    "$P2_MODELS/10_expenditure_DID.ster", ///
    replace

esttab EXP_DID ///
    using "$P2_TABLES/10_expenditure_DID.rtf", ///
    replace ///
    keep(exp_h_ann exp_h_impl) ///
    order(exp_h_ann exp_h_impl) ///
    coeflabels( ///
        exp_h_ann  "Hunan x Announcement 2004" ///
        exp_h_impl "Hunan x Implementation period" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats( ///
        announcement_p ///
        implementation_p ///
        N, ///
        labels( ///
            "Announcement p-value" ///
            "Implementation p-value" ///
            "Observations" ///
        ) ///
        fmt(3 3 0) ///
    ) ///
    title("Real household expenditure: average DID") ///
    addnotes( ///
        "Hunan versus Guizhou baseline pure consumers", ///
        "One observation per household-wave", ///
        "2004 modeled separately as announcement/transition", ///
        "Implementation period = 2006, 2009, 2011", ///
        "Household and wave fixed effects", ///
        "SE clustered at community level" ///
    )

esttab EXP_DID ///
    using "$P2_TABLES/10_expenditure_DID.csv", ///
    replace ///
    keep(exp_h_ann exp_h_impl) ///
    b(%9.4f) ///
    se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(announcement_p implementation_p N, fmt(4 4 0))


*===============================================================================
* 5. PART B — EXPENDITURE EVENT STUDY
*
* Reference year = 2000.
* 1997 is the clean pre-policy lead.
*===============================================================================

foreach v in ///
    exp_h97 ///
    exp_h04 ///
    exp_h06 ///
    exp_h09 ///
    exp_h11 {

    capture drop `v'
}

gen byte exp_h97 = ///
    exp_treated_hg * (wave == 1997) ///
    if exp_sample_pc == 1

gen byte exp_h04 = ///
    exp_treated_hg * (wave == 2004) ///
    if exp_sample_pc == 1

gen byte exp_h06 = ///
    exp_treated_hg * (wave == 2006) ///
    if exp_sample_pc == 1

gen byte exp_h09 = ///
    exp_treated_hg * (wave == 2009) ///
    if exp_sample_pc == 1

gen byte exp_h11 = ///
    exp_treated_hg * (wave == 2011) ///
    if exp_sample_pc == 1

reghdfe lnhhexpense_real ///
    exp_h97 ///
    exp_h04 ///
    exp_h06 ///
    exp_h09 ///
    exp_h11 ///
    if exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1, ///
    absorb(hhid wave) ///
    vce(cluster cluster_commid)

test exp_h97
local pretrend_p = r(p)

test exp_h04
local event_ann_p = r(p)

test exp_h06 exp_h09 exp_h11
local postjoint_p = r(p)

estadd scalar pretrend_p = `pretrend_p'
estadd scalar announcement_p = `event_ann_p'
estadd scalar postjoint_p = `postjoint_p'

eststo EXP_ES

display as text ""
display as result "EXPENDITURE EVENT STUDY"
display as result ///
    "1997 pretrend p       = " ///
    %9.4f `pretrend_p'

display as result ///
    "2004 announcement p   = " ///
    %9.4f `event_ann_p'

display as result ///
    "2006/2009/2011 joint p = " ///
    %9.4f `postjoint_p'

estimates save ///
    "$P2_MODELS/10_expenditure_eventstudy.ster", ///
    replace

esttab EXP_ES ///
    using "$P2_TABLES/10_expenditure_eventstudy.rtf", ///
    replace ///
    keep(exp_h97 exp_h04 exp_h06 exp_h09 exp_h11) ///
    order(exp_h97 exp_h04 exp_h06 exp_h09 exp_h11) ///
    coeflabels( ///
        exp_h97 "1997 x Hunan" ///
        exp_h04 "2004 x Hunan" ///
        exp_h06 "2006 x Hunan" ///
        exp_h09 "2009 x Hunan" ///
        exp_h11 "2011 x Hunan" ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats( ///
        pretrend_p ///
        announcement_p ///
        postjoint_p ///
        N, ///
        labels( ///
            "Pretrend p-value" ///
            "Announcement p-value" ///
            "Joint post p-value" ///
            "Observations" ///
        ) ///
        fmt(3 3 3 0) ///
    ) ///
    title("Real household expenditure: event study") ///
    addnotes( ///
        "Reference year = 2000", ///
        "1997 x Hunan is the pretrend diagnostic", ///
        "Household and wave fixed effects", ///
        "SE clustered at community level" ///
    )

esttab EXP_ES ///
    using "$P2_TABLES/10_expenditure_eventstudy.csv", ///
    replace ///
    keep(exp_h97 exp_h04 exp_h06 exp_h09 exp_h11) ///
    b(%9.4f) ///
    se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(pretrend_p announcement_p postjoint_p N, fmt(4 4 4 0))


* Optional event-study graph.
capture which coefplot

if !_rc & "$P2_FIGURES" != "" {

    coefplot EXP_ES, ///
        keep( ///
            exp_h97 ///
            exp_h04 ///
            exp_h06 ///
            exp_h09 ///
            exp_h11 ///
        ) ///
        order( ///
            exp_h97 ///
            exp_h04 ///
            exp_h06 ///
            exp_h09 ///
            exp_h11 ///
        ) ///
        coeflabels( ///
            exp_h97 = "1997" ///
            exp_h04 = "2004" ///
            exp_h06 = "2006" ///
            exp_h09 = "2009" ///
            exp_h11 = "2011" ///
        ) ///
        vertical ///
        yline(0, lpattern(dash)) ///
        ytitle("Effect on log real household expenditure") ///
        xtitle("Survey year; reference = 2000") ///
        title("MGPP and real household expenditure") ///
        legend(off)

    graph export ///
        "$P2_FIGURES/10_expenditure_eventstudy.png", ///
        replace ///
        width(2000)
}


*===============================================================================
* 6. PART C — HOUSEHOLD BASELINE-CALORIE STATUS
*
* SECONDARY mechanism analysis.
*
* Because expenditure is a household-level outcome, this section defines
* baseline calorie status at the household level:
*   1. mean individual kcal within household-wave
*   2. require a household value in BOTH 1997 and 2000
*   3. average the two pre-policy household-wave means
*   4. define bottom quartile among eligible households
*
* This is intentionally separate from the preferred individual-level low-kcal
* definition used for individual nutrition outcomes.
*===============================================================================

foreach v in ///
    exp_hh_kcal_wave ///
    exp_kcal97 ///
    exp_kcal00 ///
    exp_pre_n ///
    exp_pre_kcal ///
    exp_qkcal ///
    exp_low_q25 {

    capture drop `v'
}

bysort hhid wave: egen double exp_hh_kcal_wave = ///
    mean(d3kcal) ///
    if exp_sample_pc == 1

bysort hhid: egen double exp_kcal97 = max( ///
    cond( ///
        wave == 1997 ///
        & exp_sample_pc == 1 ///
        & exp_tag_hhwave == 1, ///
        exp_hh_kcal_wave, ///
        . ///
    ) ///
)

bysort hhid: egen double exp_kcal00 = max( ///
    cond( ///
        wave == 2000 ///
        & exp_sample_pc == 1 ///
        & exp_tag_hhwave == 1, ///
        exp_hh_kcal_wave, ///
        . ///
    ) ///
)

gen byte exp_pre_n = ///
    !missing(exp_kcal97) ///
    + !missing(exp_kcal00)

gen double exp_pre_kcal = ///
    (exp_kcal97 + exp_kcal00) / 2 ///
    if exp_pre_n == 2

preserve

    keep if ///
        exp_sample_pc == 1 ///
        & exp_tag_hhwave == 1 ///
        & exp_pre_n == 2 ///
        & !missing(exp_pre_kcal)

    keep hhid exp_pre_kcal

    bysort hhid: keep if _n == 1

    isid hhid

    quietly count
    local N_exp_pre2 = r(N)

    display as result ///
        "Households defining expenditure-channel kcal q25 = " ///
        `N_exp_pre2'

    if `N_exp_pre2' < 4 {
        display as error ///
            "Too few eligible households to define baseline-calorie quartiles."
        restore
        exit 2001
    }

    xtile exp_qkcal = exp_pre_kcal, nq(4)

    gen byte exp_low_q25 = ///
        (exp_qkcal == 1) ///
        if !missing(exp_qkcal)

    keep ///
        hhid ///
        exp_qkcal ///
        exp_low_q25

    tempfile exp_kcal_groups

    save `exp_kcal_groups', replace

restore

merge m:1 hhid ///
    using `exp_kcal_groups', ///
    nogen ///
    keep(master match)

label variable exp_pre_kcal ///
    "Mean household kcal across 1997 and 2000"

label variable exp_low_q25 ///
    "Bottom 25% household baseline kcal, 1997 and 2000 required"


*===============================================================================
* 7. PART C1 — POOLED EXPENDITURE DDD BY BASELINE CALORIES
*===============================================================================

foreach v in ///
    exp_l_ann ///
    exp_ddd_ann ///
    exp_l_impl ///
    exp_ddd_impl {

    capture drop `v'
}

gen byte exp_l_ann = ///
    exp_low_q25 * exp_ann2004 ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_ddd_ann = ///
    exp_treated_hg * exp_low_q25 * exp_ann2004 ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_l_impl = ///
    exp_low_q25 * exp_post_impl ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_ddd_impl = ///
    exp_treated_hg * exp_low_q25 * exp_post_impl ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

reghdfe lnhhexpense_real ///
    exp_h_ann ///
    exp_l_ann ///
    exp_ddd_ann ///
    exp_h_impl ///
    exp_l_impl ///
    exp_ddd_impl ///
    if exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25), ///
    absorb(hhid wave) ///
    vce(cluster cluster_commid)

test exp_ddd_impl
local ddd_impl_p = r(p)

lincom exp_h_impl + exp_ddd_impl
local low_impl_b = r(estimate)
local low_impl_p = r(p)

test exp_ddd_impl = exp_ddd_ann
local ddd_impl_vs_ann_p = r(p)

estadd scalar ddd_p = `ddd_impl_p'
estadd scalar low_effect = `low_impl_b'
estadd scalar low_p = `low_impl_p'
estadd scalar impl_vs_ann_p = `ddd_impl_vs_ann_p'

eststo EXP_DDD

display as text ""
display as result "EXPENDITURE HETEROGENEITY — HOUSEHOLD LOW-KCAL GROUP"
display as result ///
    "Implementation DDD coefficient = " ///
    %9.4f _b[exp_ddd_impl] ///
    "   p = " %9.4f `ddd_impl_p'

display as result ///
    "Low-kcal total Hunan effect    = " ///
    %9.4f `low_impl_b' ///
    "   p = " %9.4f `low_impl_p'

estimates save ///
    "$P2_MODELS/10_expenditure_DDD.ster", ///
    replace

esttab EXP_DDD ///
    using "$P2_TABLES/10_expenditure_DDD.rtf", ///
    replace ///
    keep( ///
        exp_h_ann ///
        exp_l_ann ///
        exp_ddd_ann ///
        exp_h_impl ///
        exp_l_impl ///
        exp_ddd_impl ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats( ///
        ddd_p ///
        low_effect ///
        low_p ///
        impl_vs_ann_p ///
        N, ///
        labels( ///
            "Implementation DDD p-value" ///
            "Low-kcal total implementation effect" ///
            "Low-kcal total-effect p-value" ///
            "Implementation DDD = announcement DDD p-value" ///
            "Observations" ///
        ) ///
        fmt(3 3 3 3 0) ///
    ) ///
    title("Real household expenditure: heterogeneity by baseline calories") ///
    addnotes( ///
        "Household low-kcal status is defined from both 1997 and 2000", ///
        "Bottom quartile of pre-policy household mean calorie intake", ///
        "Household and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 8. PART D — DYNAMIC EXPENDITURE DDD
*
* Reference year = 2000.
* The coefficient exp_d97 is the DDD pretrend diagnostic.
*===============================================================================

foreach v in ///
    exp_l97 exp_l04 exp_l06 exp_l09 exp_l11 ///
    exp_d97 exp_d04 exp_d06 exp_d09 exp_d11 {

    capture drop `v'
}

* Low-kcal x year.
gen byte exp_l97 = ///
    exp_low_q25 * (wave == 1997) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_l04 = ///
    exp_low_q25 * (wave == 2004) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_l06 = ///
    exp_low_q25 * (wave == 2006) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_l09 = ///
    exp_low_q25 * (wave == 2009) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_l11 = ///
    exp_low_q25 * (wave == 2011) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

* Hunan x low-kcal x year.
gen byte exp_d97 = ///
    exp_treated_hg * exp_low_q25 * (wave == 1997) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_d04 = ///
    exp_treated_hg * exp_low_q25 * (wave == 2004) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_d06 = ///
    exp_treated_hg * exp_low_q25 * (wave == 2006) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_d09 = ///
    exp_treated_hg * exp_low_q25 * (wave == 2009) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

gen byte exp_d11 = ///
    exp_treated_hg * exp_low_q25 * (wave == 2011) ///
    if exp_sample_pc == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25)

reghdfe lnhhexpense_real ///
    exp_h97 exp_h04 exp_h06 exp_h09 exp_h11 ///
    exp_l97 exp_l04 exp_l06 exp_l09 exp_l11 ///
    exp_d97 exp_d04 exp_d06 exp_d09 exp_d11 ///
    if exp_sample_pc == 1 ///
    & exp_tag_hhwave == 1 ///
    & exp_pre_n == 2 ///
    & !missing(exp_low_q25), ///
    absorb(hhid wave) ///
    vce(cluster cluster_commid)

test exp_d97
local ddd_pretrend_p = r(p)

test exp_d06 exp_d09 exp_d11
local ddd_postjoint_p = r(p)

estadd scalar ddd_pretrend_p = `ddd_pretrend_p'
estadd scalar ddd_postjoint_p = `ddd_postjoint_p'

eststo EXP_DDD_ES

display as text ""
display as result "DYNAMIC EXPENDITURE DDD"
display as result ///
    "DDD pretrend p          = " ///
    %9.4f `ddd_pretrend_p'

display as result ///
    "DDD joint post p        = " ///
    %9.4f `ddd_postjoint_p'

estimates save ///
    "$P2_MODELS/10_expenditure_DDD_eventstudy.ster", ///
    replace

esttab EXP_DDD_ES ///
    using "$P2_TABLES/10_expenditure_DDD_eventstudy.rtf", ///
    replace ///
    keep( ///
        exp_h97 exp_h04 exp_h06 exp_h09 exp_h11 ///
        exp_d97 exp_d04 exp_d06 exp_d09 exp_d11 ///
    ) ///
    b(%9.3f) ///
    se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats( ///
        ddd_pretrend_p ///
        ddd_postjoint_p ///
        N, ///
        labels( ///
            "DDD pretrend p-value" ///
            "DDD joint post p-value" ///
            "Observations" ///
        ) ///
        fmt(3 3 0) ///
    ) ///
    title("Real household expenditure: dynamic heterogeneity") ///
    addnotes( ///
        "Reference year = 2000", ///
        "exp_d97 is the DDD pretrend diagnostic", ///
        "Household and wave fixed effects", ///
        "SE clustered at community level" ///
    )


*===============================================================================
* 9. FINAL SUMMARY
*===============================================================================

display as text ""
display as result "======================================================================"
display as result "10 EXPENDITURE CHANNEL COMPLETED"
display as result "======================================================================"

display as result ///
    "Average implementation effect p = " ///
    %9.4f `impl_p'

display as result ///
    "Average DID pretrend p          = " ///
    %9.4f `pretrend_p'

display as result ///
    "Average dynamic joint post p    = " ///
    %9.4f `postjoint_p'

display as result ///
    "Low-kcal implementation DDD p   = " ///
    %9.4f `ddd_impl_p'

display as result ///
    "Dynamic DDD pretrend p          = " ///
    %9.4f `ddd_pretrend_p'

display as result ///
    "Dynamic DDD joint post p        = " ///
    %9.4f `ddd_postjoint_p'

display as result "======================================================================"

*===============================================================================
* END OF analyses/10_expenditure_channel.do
*===============================================================================
