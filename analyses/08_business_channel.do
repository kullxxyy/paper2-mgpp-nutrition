*===============================================================================
* PAPER 2 — HOUSEHOLD BUSINESS CHANNEL
* File: analyses/08_business_channel.do
*
* FINAL CONSERVATIVE VERSION
*
* PURPOSE
*   Evaluate household business-income and sectoral channels without silently
*   interpreting missing HHBUS/H2 values as zero.
*
* SAMPLE
*   - Hunan vs Guizhou
*   - baseline pure-consumer households
*   - waves: 1997, 2000, 2004, 2006, 2009, 2011
*
* HETEROGENEITY
*   - household baseline calories
*   - household mean kcal calculated separately in 1997 and 2000
*   - BOTH pre-policy waves required
*   - bottom 25% calculated only among those eligible households
*
* TIMING
*   - 2000 = omitted/reference year in dynamic models
*   - 2004 = announcement / transition wave
*   - 2006, 2009, 2011 = observed implementation-period waves
*
* ESTIMATION
*   - household FE + wave FE
*   - one observation per household-wave
*   - SE clustered at community level
*   - no contemporaneous controls in preferred models
*
* IMPORTANT DATA RULES
*   1. Missing HHBUS is NOT recoded to zero by default.
*   2. Missing H2 for all members in a household-wave is NOT recoded to zero.
*   3. Business-income models using observed HHBUS are therefore interpreted as
*      observed/conditional business-income outcomes unless the CHNS codebook
*      confirms that missing means "no business".
*   4. Sector models using observed H2 are interpreted as observed-module
*      sector outcomes unless the CHNS codebook confirms otherwise.
*   5. If the codebook later confirms that missing HHBUS/H2 means no business,
*      set local assume_missing_zero = 1 below to run zero-recoded robustness.
*
* VARIABLE-CODING ASSUMPTIONS TO VERIFY
*   - H2 == 1 : commerce
*   - H2 == 3 : manufacturing
*   - deflator is a multiplier that converts nominal HHBUS into real terms
*===============================================================================


*===============================================================================
* 0. USER SWITCH
*===============================================================================

* DEFAULT = 0:
*   Do NOT treat missing HHBUS/H2 as zero.
*
* Set to 1 ONLY after verifying from the CHNS questionnaire/codebook that
* missing HHBUS/H2 means "no household business / no sector activity".
local assume_missing_zero 0


*===============================================================================
* 1. REQUIRED PACKAGES / PATHS / VARIABLES
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

capture which winsor2
if _rc {
    display as error "winsor2 is not installed."
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
    hhid wave IDind consumer_base ///
    d3kcal H2 HHBUS deflator {

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
* 2. HUNAN / GUIZHOU PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in ///
    bc_sample_hg ///
    bc_treated_hg ///
    bc_sample_pc {

    capture drop `v'
}


capture confirm variable t1

if !_rc {

    gen byte bc_sample_hg = ///
        inlist(t1, 43, 52)

    gen byte bc_treated_hg = ///
        (t1 == 43) ///
        if bc_sample_hg == 1
}
else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists; cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte bc_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte bc_treated_hg = ///
        (province_code == 43) ///
        if bc_sample_hg == 1
}


gen byte bc_sample_pc = ///
    bc_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


capture label define bc_hg ///
    0 "Guizhou" ///
    1 "Hunan"

if _rc {
    label define bc_hg ///
        0 "Guizhou" ///
        1 "Hunan", ///
        replace
}

label values bc_treated_hg bc_hg


display as text ""
display as result "============================================================"
display as result "08 BUSINESS CHANNEL — HUNAN / GUIZHOU PURE CONSUMERS"
display as result "============================================================"

tab bc_treated_hg ///
    if bc_sample_pc == 1, ///
    missing

tab wave ///
    if bc_sample_pc == 1, ///
    missing


*===============================================================================
* 3. ONE OBSERVATION PER HOUSEHOLD-WAVE
*===============================================================================

capture drop bc_tag_hhwave

egen byte bc_tag_hhwave = tag(hhid wave) ///
    if bc_sample_pc == 1


quietly count if ///
    bc_sample_pc == 1 ///
    & bc_tag_hhwave == 1

display as result ///
    "Pure-consumer household-wave observations = " ///
    r(N)


*===============================================================================
* 4. DATA DIAGNOSTICS FOR HHBUS AND H2
*
* These diagnostics are intentionally printed before constructing outcomes.
*===============================================================================

display as text ""
display as result "============================================================"
display as result "BUSINESS-VARIABLE DIAGNOSTICS"
display as result "============================================================"


* Clean known negative special codes in a new variable.
capture drop bc_HHBUS_clean

gen double bc_HHBUS_clean = HHBUS

replace bc_HHBUS_clean = . ///
    if inlist(bc_HHBUS_clean, -9, -99, -999, -9999)


* Household-wave HHBUS consistency check.
foreach v in ///
    __bc_hhbus_min ///
    __bc_hhbus_max ///
    __bc_hhbus_n ///
    bc_hhbus_inconsistent {

    capture drop `v'
}


bysort hhid wave: egen double __bc_hhbus_min = min( ///
    cond( ///
        bc_sample_pc == 1 ///
        & !missing(bc_HHBUS_clean), ///
        bc_HHBUS_clean, ///
        . ///
    ) ///
)


bysort hhid wave: egen double __bc_hhbus_max = max( ///
    cond( ///
        bc_sample_pc == 1 ///
        & !missing(bc_HHBUS_clean), ///
        bc_HHBUS_clean, ///
        . ///
    ) ///
)


bysort hhid wave: egen int __bc_hhbus_n = total( ///
    bc_sample_pc == 1 ///
    & !missing(bc_HHBUS_clean) ///
)


gen byte bc_hhbus_inconsistent = ///
    (__bc_hhbus_n > 1) ///
    & !missing(__bc_hhbus_min) ///
    & !missing(__bc_hhbus_max) ///
    & abs(__bc_hhbus_max - __bc_hhbus_min) > 1e-8


quietly count if ///
    bc_tag_hhwave == 1 ///
    & bc_hhbus_inconsistent == 1

display as result ///
    "HHBUS-inconsistent household-waves = " ///
    r(N)


if r(N) > 0 {
    display as error ///
        "WARNING: HHBUS differs across members within some household-waves."
    display as error ///
        "Do not interpret HHBUS as a clean repeated household-level variable until checked."
}


* HHBUS observation / zero / positive diagnostics on one household-wave row.
capture drop bc_hhbus_observed_hhw

gen byte bc_hhbus_observed_hhw = ///
    (__bc_hhbus_n > 0) ///
    if bc_tag_hhwave == 1


display as text ""
display as text "HHBUS observed status:"
tab bc_hhbus_observed_hhw ///
    if bc_tag_hhwave == 1, ///
    missing


display as text ""
display as text "HHBUS value diagnostics among observed household-waves:"

quietly count if ///
    bc_tag_hhwave == 1 ///
    & bc_hhbus_observed_hhw == 1 ///
    & __bc_hhbus_max == 0

display as result ///
    "Observed HHBUS == 0 household-waves = " ///
    r(N)


quietly count if ///
    bc_tag_hhwave == 1 ///
    & bc_hhbus_observed_hhw == 1 ///
    & __bc_hhbus_max > 0

display as result ///
    "Observed HHBUS > 0 household-waves  = " ///
    r(N)


* H2 observation diagnostics.
capture drop __bc_h2_obs_any

bysort hhid wave: egen byte __bc_h2_obs_any = max( ///
    cond( ///
        bc_sample_pc == 1, ///
        !missing(H2), ///
        . ///
    ) ///
)


display as text ""
display as text "H2 observed status:"
tab __bc_h2_obs_any ///
    if bc_tag_hhwave == 1, ///
    missing


display as text ""
display as text "Observed H2 categories:"
tab H2 ///
    if bc_sample_pc == 1 ///
    & !missing(H2), ///
    missing


* Deflator diagnostics.
display as text ""
display as text "Deflator diagnostics:"
summarize deflator ///
    if bc_sample_pc == 1, ///
    detail


*===============================================================================
* 5. HOUSEHOLD BUSINESS OUTCOMES
*===============================================================================


*-------------------------------------------------------------------------------
* 5A. Observed-module commerce / manufacturing outcomes
*
* If ANY household member has observed H2:
*   commerce      = 1 if any observed member has H2==1, otherwise 0
*   manufacturing = 1 if any observed member has H2==3, otherwise 0
*
* If NO household member has observed H2:
*   outcome remains missing by default.
*-------------------------------------------------------------------------------

foreach v in ///
    __bc_commerce_any ///
    __bc_manufact_any ///
    bc_hh_commerce_obs ///
    bc_hh_manufact_obs {

    capture drop `v'
}


bysort hhid wave: egen byte __bc_commerce_any = max( ///
    cond( ///
        bc_sample_pc == 1 ///
        & !missing(H2), ///
        H2 == 1, ///
        . ///
    ) ///
)


bysort hhid wave: egen byte __bc_manufact_any = max( ///
    cond( ///
        bc_sample_pc == 1 ///
        & !missing(H2), ///
        H2 == 3, ///
        . ///
    ) ///
)


gen byte bc_hh_commerce_obs = ///
    __bc_commerce_any ///
    if bc_tag_hhwave == 1 ///
    & __bc_h2_obs_any == 1


gen byte bc_hh_manufact_obs = ///
    __bc_manufact_any ///
    if bc_tag_hhwave == 1 ///
    & __bc_h2_obs_any == 1


label variable bc_hh_commerce_obs ///
    "Commerce activity, conditional on observed H2 module"

label variable bc_hh_manufact_obs ///
    "Manufacturing activity, conditional on observed H2 module"


*-------------------------------------------------------------------------------
* 5B. Observed household business income
*
* HHBUS is treated as a repeated household-level value only when internally
* consistent within household-wave.
*-------------------------------------------------------------------------------

foreach v in ///
    bc_HHBUS_real_obs ///
    bc_hh_bus_real_obs ///
    bc_hh_bus_income_obs {

    capture drop `v'
}


gen double bc_HHBUS_real_obs = ///
    bc_HHBUS_clean * deflator ///
    if bc_sample_pc == 1 ///
    & !missing(bc_HHBUS_clean) ///
    & !missing(deflator)


gen double bc_hh_bus_real_obs = ///
    __bc_hhbus_max * deflator ///
    if bc_tag_hhwave == 1 ///
    & bc_hhbus_observed_hhw == 1 ///
    & bc_hhbus_inconsistent == 0 ///
    & !missing(deflator)


* Winsorize only one row per household-wave.
winsor2 bc_hh_bus_real_obs ///
    if bc_tag_hhwave == 1 ///
    & !missing(bc_hh_bus_real_obs), ///
    cuts(1 99) ///
    replace


gen double bc_hh_bus_income_obs = ///
    asinh(bc_hh_bus_real_obs) ///
    if bc_tag_hhwave == 1 ///
    & !missing(bc_hh_bus_real_obs)


label variable bc_hh_bus_income_obs ///
    "asinh real HH business income, observed HHBUS only, winsorized 1/99"


*-------------------------------------------------------------------------------
* 5C. OPTIONAL ZERO-RECODED ROBUSTNESS
*
* Generated ONLY if local assume_missing_zero == 1.
*-------------------------------------------------------------------------------

capture drop bc_hh_bus_income_zero
capture drop bc_hh_commerce_zero
capture drop bc_hh_manufact_zero


if `assume_missing_zero' == 1 {

    display as error ///
        "ZERO-RECODED ROBUSTNESS ENABLED: verify codebook assumption carefully."


    gen double bc_hh_bus_income_zero = ///
        asinh( ///
            cond( ///
                bc_hhbus_observed_hhw == 1 ///
                & bc_hhbus_inconsistent == 0, ///
                __bc_hhbus_max * deflator, ///
                0 ///
            ) ///
        ) ///
        if bc_tag_hhwave == 1 ///
        & !missing(deflator)


    gen byte bc_hh_commerce_zero = ///
        cond( ///
            __bc_h2_obs_any == 1, ///
            __bc_commerce_any, ///
            0 ///
        ) ///
        if bc_tag_hhwave == 1


    gen byte bc_hh_manufact_zero = ///
        cond( ///
            __bc_h2_obs_any == 1, ///
            __bc_manufact_any, ///
            0 ///
        ) ///
        if bc_tag_hhwave == 1


    label variable bc_hh_bus_income_zero ///
        "asinh real HH business income, missing assumed zero"

    label variable bc_hh_commerce_zero ///
        "Commerce activity, missing H2 assumed zero"

    label variable bc_hh_manufact_zero ///
        "Manufacturing activity, missing H2 assumed zero"
}


*===============================================================================
* 6. HOUSEHOLD BASELINE-CALORIE HETEROGENEITY
*
* STRICT TWO-PRE-WAVE DEFINITION
*===============================================================================

foreach v in ///
    bc_hh_wave_kcal ///
    bc_tag_pre_hhwave ///
    bc_pre_n_hh ///
    bc_pre_kcal_hh ///
    bc_qkcal_hh ///
    bc_low_q25_hh {

    capture drop `v'
}


bysort hhid wave: egen double bc_hh_wave_kcal = mean( ///
    cond( ///
        bc_sample_pc == 1 ///
        & inlist(wave, 1997, 2000) ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


egen byte bc_tag_pre_hhwave = tag(hhid wave) ///
    if bc_sample_pc == 1 ///
    & inlist(wave, 1997, 2000) ///
    & !missing(bc_hh_wave_kcal)


bysort hhid: egen byte bc_pre_n_hh = total( ///
    bc_tag_pre_hhwave == 1 ///
)


bysort hhid: egen double bc_pre_kcal_hh = mean( ///
    cond( ///
        bc_tag_pre_hhwave == 1, ///
        bc_hh_wave_kcal, ///
        . ///
    ) ///
)


preserve

    keep if ///
        bc_sample_hg == 1 ///
        & consumer_base == 1 ///
        & bc_pre_n_hh == 2 ///
        & !missing(bc_pre_kcal_hh)

    keep hhid bc_pre_kcal_hh

    bysort hhid: keep if _n == 1

    isid hhid

    quietly count
    local N_pre2_hh = r(N)

    display as result ///
        "Two-pre-wave households defining business-channel q25 = `N_pre2_hh'"

    if `N_pre2_hh' < 4 {
        display as error ///
            "Too few households to define baseline-calorie quartiles."
        restore
        exit 2001
    }

    xtile bc_qkcal_hh = bc_pre_kcal_hh, nq(4)

    gen byte bc_low_q25_hh = ///
        (bc_qkcal_hh == 1) ///
        if !missing(bc_qkcal_hh)

    keep ///
        hhid ///
        bc_qkcal_hh ///
        bc_low_q25_hh

    tempfile bc_hh_kcal_group
    save `bc_hh_kcal_group', replace

restore


merge m:1 hhid ///
    using `bc_hh_kcal_group', ///
    nogen ///
    keep(master match)


label variable bc_low_q25_hh ///
    "Household baseline calories: bottom 25%, both 1997/2000 required"


capture drop bc_sample_pre2_hh

gen byte bc_sample_pre2_hh = ///
    bc_sample_pc == 1 ///
    & bc_tag_hhwave == 1 ///
    & bc_pre_n_hh == 2 ///
    & !missing(bc_low_q25_hh)


capture drop __bc_hhtag

egen byte __bc_hhtag = tag(hhid) ///
    if bc_sample_pre2_hh == 1


quietly count if __bc_hhtag == 1

display as result ///
    "Preferred two-pre-wave households = " ///
    r(N)


tab bc_low_q25_hh bc_treated_hg ///
    if __bc_hhtag == 1, ///
    column


drop __bc_hhtag


*===============================================================================
* 7. POLICY TIMING AND COMPLETE DDD
*===============================================================================

foreach v in ///
    bc_ann2004 ///
    bc_post_impl ///
    bc_h_ann ///
    bc_l_ann ///
    bc_ddd_ann ///
    bc_h_impl ///
    bc_l_impl ///
    bc_ddd_impl {

    capture drop `v'
}


gen byte bc_ann2004 = ///
    (wave == 2004)


gen byte bc_post_impl = ///
    (wave >= 2006)


gen byte bc_h_ann = ///
    bc_treated_hg * bc_ann2004 ///
    if bc_sample_pre2_hh == 1


gen byte bc_l_ann = ///
    bc_low_q25_hh * bc_ann2004 ///
    if bc_sample_pre2_hh == 1


gen byte bc_ddd_ann = ///
    bc_treated_hg * bc_low_q25_hh * bc_ann2004 ///
    if bc_sample_pre2_hh == 1


gen byte bc_h_impl = ///
    bc_treated_hg * bc_post_impl ///
    if bc_sample_pre2_hh == 1


gen byte bc_l_impl = ///
    bc_low_q25_hh * bc_post_impl ///
    if bc_sample_pre2_hh == 1


gen byte bc_ddd_impl = ///
    bc_treated_hg * bc_low_q25_hh * bc_post_impl ///
    if bc_sample_pre2_hh == 1


label variable bc_h_ann ///
    "Hunan x Announcement 2004"

label variable bc_l_ann ///
    "Low-kcal household x Announcement 2004"

label variable bc_ddd_ann ///
    "Hunan x Low-kcal household x Announcement 2004"

label variable bc_h_impl ///
    "Hunan x Implementation period"

label variable bc_l_impl ///
    "Low-kcal household x Implementation period"

label variable bc_ddd_impl ///
    "Hunan x Low-kcal household x Implementation period (DDD)"


*===============================================================================
* 8. DYNAMIC DDD VARIABLES
*
* Reference year = 2000.
*===============================================================================

foreach v in ///
    bc_h97 bc_h04 bc_h06 bc_h09 bc_h11 ///
    bc_l97 bc_l04 bc_l06 bc_l09 bc_l11 ///
    bc_d97 bc_d04 bc_d06 bc_d09 bc_d11 {

    capture drop `v'
}


* Hunan x wave.
gen byte bc_h97 = ///
    bc_treated_hg * (wave == 1997) ///
    if bc_sample_pre2_hh == 1

gen byte bc_h04 = ///
    bc_treated_hg * (wave == 2004) ///
    if bc_sample_pre2_hh == 1

gen byte bc_h06 = ///
    bc_treated_hg * (wave == 2006) ///
    if bc_sample_pre2_hh == 1

gen byte bc_h09 = ///
    bc_treated_hg * (wave == 2009) ///
    if bc_sample_pre2_hh == 1

gen byte bc_h11 = ///
    bc_treated_hg * (wave == 2011) ///
    if bc_sample_pre2_hh == 1


* Low-kcal household x wave.
gen byte bc_l97 = ///
    bc_low_q25_hh * (wave == 1997) ///
    if bc_sample_pre2_hh == 1

gen byte bc_l04 = ///
    bc_low_q25_hh * (wave == 2004) ///
    if bc_sample_pre2_hh == 1

gen byte bc_l06 = ///
    bc_low_q25_hh * (wave == 2006) ///
    if bc_sample_pre2_hh == 1

gen byte bc_l09 = ///
    bc_low_q25_hh * (wave == 2009) ///
    if bc_sample_pre2_hh == 1

gen byte bc_l11 = ///
    bc_low_q25_hh * (wave == 2011) ///
    if bc_sample_pre2_hh == 1


* Dynamic DDD.
gen byte bc_d97 = ///
    bc_treated_hg * bc_low_q25_hh * (wave == 1997) ///
    if bc_sample_pre2_hh == 1

gen byte bc_d04 = ///
    bc_treated_hg * bc_low_q25_hh * (wave == 2004) ///
    if bc_sample_pre2_hh == 1

gen byte bc_d06 = ///
    bc_treated_hg * bc_low_q25_hh * (wave == 2006) ///
    if bc_sample_pre2_hh == 1

gen byte bc_d09 = ///
    bc_treated_hg * bc_low_q25_hh * (wave == 2009) ///
    if bc_sample_pre2_hh == 1

gen byte bc_d11 = ///
    bc_treated_hg * bc_low_q25_hh * (wave == 2011) ///
    if bc_sample_pre2_hh == 1


*===============================================================================
* 9. OUTCOME LISTS
*===============================================================================

local business_outcomes ///
    bc_hh_bus_income_obs ///
    bc_hh_commerce_obs ///
    bc_hh_manufact_obs


local business_titles ///
    `" "Observed business income" "Observed commerce" "Observed manufacturing" "'


if `assume_missing_zero' == 1 {

    local business_outcomes ///
        `business_outcomes' ///
        bc_hh_bus_income_zero ///
        bc_hh_commerce_zero ///
        bc_hh_manufact_zero
}


*===============================================================================
* 10. PREFERRED POOLED BUSINESS-CHANNEL DDD
*===============================================================================

eststo clear

local business_models ""


foreach y of local business_outcomes {

    quietly count if ///
        bc_sample_pre2_hh == 1 ///
        & !missing(`y')

    local usable_n = r(N)

    display as text ""
    display as result "============================================================"
    display as result "BUSINESS CHANNEL OUTCOME: `y'"
    display as result "Usable household-wave observations = `usable_n'"
    display as result "============================================================"


    if `usable_n' >= 50 {

        capture noisily reghdfe `y' ///
            bc_h_ann ///
            bc_l_ann ///
            bc_ddd_ann ///
            bc_h_impl ///
            bc_l_impl ///
            bc_ddd_impl ///
            if bc_sample_pre2_hh == 1, ///
            absorb(hhid wave) ///
            vce(cluster cluster_commid)


        if !_rc {

            capture noisily test bc_ddd_impl

            if !_rc {
                local ddd_p = r(p)
            }
            else {
                local ddd_p = .
            }


            capture noisily lincom bc_h_impl + bc_ddd_impl

            if !_rc {
                local low_b = r(estimate)
                local low_p = r(p)
            }
            else {
                local low_b = .
                local low_p = .
            }


            capture noisily test bc_ddd_impl = bc_ddd_ann

            if !_rc {
                local impl_vs_ann_p = r(p)
            }
            else {
                local impl_vs_ann_p = .
            }


            estadd scalar ddd_p = `ddd_p'
            estadd scalar low_effect = `low_b'
            estadd scalar low_p = `low_p'
            estadd scalar impl_vs_ann_p = `impl_vs_ann_p'


            local modelname ""

            if "`y'" == "bc_hh_bus_income_obs" {
                local modelname "BUSINC_OBS"
            }

            if "`y'" == "bc_hh_commerce_obs" {
                local modelname "COMMERCE_OBS"
            }

            if "`y'" == "bc_hh_manufact_obs" {
                local modelname "MANUFACT_OBS"
            }

            if "`y'" == "bc_hh_bus_income_zero" {
                local modelname "BUSINC_ZERO"
            }

            if "`y'" == "bc_hh_commerce_zero" {
                local modelname "COMMERCE_ZERO"
            }

            if "`y'" == "bc_hh_manufact_zero" {
                local modelname "MANUFACT_ZERO"
            }


            if "`modelname'" != "" {

                eststo `modelname'

                local business_models ///
                    "`business_models' `modelname'"

                estimates save ///
                    "$P2_MODELS/08_`y'.ster", ///
                    replace
            }
        }
    }
    else {
        display as text ///
            "NOTE: `y' skipped because usable observations are too few."
    }
}


*===============================================================================
* 11. DYNAMIC BUSINESS-CHANNEL DDD
*===============================================================================

local business_es_models ""


foreach y of local business_outcomes {

    quietly count if ///
        bc_sample_pre2_hh == 1 ///
        & !missing(`y')

    local usable_n = r(N)


    if `usable_n' >= 50 {

        capture noisily reghdfe `y' ///
            bc_h97 bc_h04 bc_h06 bc_h09 bc_h11 ///
            bc_l97 bc_l04 bc_l06 bc_l09 bc_l11 ///
            bc_d97 bc_d04 bc_d06 bc_d09 bc_d11 ///
            if bc_sample_pre2_hh == 1, ///
            absorb(hhid wave) ///
            vce(cluster cluster_commid)


        if !_rc {

            capture noisily test bc_d97

            if !_rc {
                local pre_p = r(p)
            }
            else {
                local pre_p = .
            }


            capture noisily test bc_d04

            if !_rc {
                local ann_p = r(p)
            }
            else {
                local ann_p = .
            }


            capture noisily test bc_d06 bc_d09 bc_d11

            if !_rc {
                local post_p = r(p)
            }
            else {
                local post_p = .
            }


            display as result ///
                "`y' DDD pretrend p = " ///
                %9.4f `pre_p'

            display as result ///
                "`y' announcement DDD p = " ///
                %9.4f `ann_p'

            display as result ///
                "`y' joint 2006/09/11 DDD p = " ///
                %9.4f `post_p'


            estadd scalar pretrend_p = `pre_p'
            estadd scalar announcement_p = `ann_p'
            estadd scalar postjoint_p = `post_p'


            local esname ""

            if "`y'" == "bc_hh_bus_income_obs" {
                local esname "BUSINC_OBS_ES"
            }

            if "`y'" == "bc_hh_commerce_obs" {
                local esname "COMMERCE_OBS_ES"
            }

            if "`y'" == "bc_hh_manufact_obs" {
                local esname "MANUFACT_OBS_ES"
            }

            if "`y'" == "bc_hh_bus_income_zero" {
                local esname "BUSINC_ZERO_ES"
            }

            if "`y'" == "bc_hh_commerce_zero" {
                local esname "COMMERCE_ZERO_ES"
            }

            if "`y'" == "bc_hh_manufact_zero" {
                local esname "MANUFACT_ZERO_ES"
            }


            if "`esname'" != "" {

                eststo `esname'

                local business_es_models ///
                    "`business_es_models' `esname'"

                estimates save ///
                    "$P2_MODELS/08_`y'_dynamic.ster", ///
                    replace
            }
        }
        else {
            display as text ///
                "NOTE: dynamic `y' regression skipped because estimation failed."
        }
    }
}


*===============================================================================
* 12. TABLES
*===============================================================================

if "`business_models'" != "" {

    esttab ///
        `business_models' ///
        using "$P2_TABLES/08_business_channel_pooled.rtf", ///
        replace ///
        keep( ///
            bc_h_ann ///
            bc_l_ann ///
            bc_ddd_ann ///
            bc_h_impl ///
            bc_l_impl ///
            bc_ddd_impl ///
        ) ///
        order( ///
            bc_h_ann ///
            bc_l_ann ///
            bc_ddd_ann ///
            bc_h_impl ///
            bc_l_impl ///
            bc_ddd_impl ///
        ) ///
        coeflabels( ///
            bc_h_ann ///
                "Hunan x Announcement 2004" ///
            bc_l_ann ///
                "Low-kcal HH x Announcement 2004" ///
            bc_ddd_ann ///
                "Hunan x Low-kcal HH x Announcement 2004" ///
            bc_h_impl ///
                "Hunan x Implementation period" ///
            bc_l_impl ///
                "Low-kcal HH x Implementation period" ///
            bc_ddd_impl ///
                "Hunan x Low-kcal HH x Implementation period (DDD)" ///
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
                "Low-kcal Hunan implementation effect" ///
                "Low-kcal effect p-value" ///
                "Implementation DDD = Announcement DDD p-value" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 3 0) ///
        ) ///
        title("Household business channels by baseline calorie status") ///
        addnotes( ///
            "Default outcomes do not recode missing HHBUS/H2 as zero", ///
            "Observed business-income and H2-sector models may be conditional on module observation", ///
            "Household baseline calorie status requires both 1997 and 2000", ///
            "2004 is modeled separately as the announcement wave", ///
            "Implementation period: 2006, 2009, 2011", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )


    esttab ///
        `business_models' ///
        using "$P2_TABLES/08_business_channel_pooled.csv", ///
        replace ///
        keep( ///
            bc_h_ann ///
            bc_l_ann ///
            bc_ddd_ann ///
            bc_h_impl ///
            bc_l_impl ///
            bc_ddd_impl ///
        ) ///
        order( ///
            bc_h_ann ///
            bc_l_ann ///
            bc_ddd_ann ///
            bc_h_impl ///
            bc_l_impl ///
            bc_ddd_impl ///
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
                "Low-kcal Hunan implementation effect" ///
                "Low-kcal effect p-value" ///
                "Implementation DDD = Announcement DDD p-value" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 3 0) ///
        )
}


if "`business_es_models'" != "" {

    esttab ///
        `business_es_models' ///
        using "$P2_TABLES/08_business_channel_dynamic_DDD.rtf", ///
        replace ///
        keep( ///
            bc_d97 ///
            bc_d04 ///
            bc_d06 ///
            bc_d09 ///
            bc_d11 ///
        ) ///
        order( ///
            bc_d97 ///
            bc_d04 ///
            bc_d06 ///
            bc_d09 ///
            bc_d11 ///
        ) ///
        coeflabels( ///
            bc_d97 "1997 x Hunan x Low-kcal HH" ///
            bc_d04 "2004 x Hunan x Low-kcal HH" ///
            bc_d06 "2006 x Hunan x Low-kcal HH" ///
            bc_d09 "2009 x Hunan x Low-kcal HH" ///
            bc_d11 "2011 x Hunan x Low-kcal HH" ///
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
                "DDD pretrend p-value: 1997 vs 2000" ///
                "Announcement DDD p-value: 2004" ///
                "Joint post DDD p-value: 2006/09/11" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 0) ///
        ) ///
        title("Dynamic household business-channel DDD") ///
        addnotes( ///
            "Reference year: 2000", ///
            "1997 triple interaction is the differential-pretrend diagnostic", ///
            "Missing HHBUS/H2 are not recoded to zero by default", ///
            "Household baseline calorie status requires both 1997 and 2000", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )


    esttab ///
        `business_es_models' ///
        using "$P2_TABLES/08_business_channel_dynamic_DDD.csv", ///
        replace ///
        keep( ///
            bc_d97 ///
            bc_d04 ///
            bc_d06 ///
            bc_d09 ///
            bc_d11 ///
        ) ///
        order( ///
            bc_d97 ///
            bc_d04 ///
            bc_d06 ///
            bc_d09 ///
            bc_d11 ///
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
                "DDD pretrend p-value: 1997 vs 2000" ///
                "Announcement DDD p-value: 2004" ///
                "Joint post DDD p-value: 2006/09/11" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 0) ///
        )
}


*===============================================================================
* 13. END
*===============================================================================

drop __bc_hhbus_min ///
     __bc_hhbus_max ///
     __bc_hhbus_n ///
     __bc_h2_obs_any ///
     __bc_commerce_any ///
     __bc_manufact_any


display as text ""
display as result "============================================================"
display as result "END OF 08 BUSINESS CHANNEL"
display as result "============================================================"
