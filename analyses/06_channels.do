*===============================================================================
* PAPER 2 — INCOME, WAGE, EXPENDITURE, BUSINESS, AND AGRICULTURAL CHANNELS
* File: analyses/06_channels.do
*
* FINAL STRICT TWO-PRE-WAVE VERSION
*
* Sample:
*   - Hunan (treated) vs Guizhou (control)
*   - baseline pure consumers
*   - waves: 1997, 2000, 2004, 2006, 2009, 2011
*
* Baseline nutritional heterogeneity:
*   - individual kcal must be observed in BOTH 1997 and 2000
*   - baseline kcal = mean of 1997 and 2000
*   - bottom quartile is calculated ONLY among those two-pre-wave individuals
*   - the same fixed low-kcal group is used for all individual channel outcomes
*
* Policy timing:
*   - 2000 = omitted/reference year in dynamic specifications
*   - 2004 = announcement / transition wave
*   - 2005 = implementation in Hunan
*   - 2006, 2009, 2011 = observed post-implementation CHNS waves
*
* Estimation:
*   - individual outcomes -> individual FE + wave FE
*   - household outcomes  -> household FE + wave FE, one row per household-wave
*   - SE clustered at community level
*   - no contemporaneous controls in preferred specifications
*
* Preferred household resource outcomes:
*   - asinh_hhinc_cpi
*   - lnhhexpense_real
*
* Preferred individual channel outcomes:
*   - monthly_wage
*   - asinh_indbus
*   - farmer_ind
*
* IMPORTANT:
*   This file does NOT reuse an old lowKCAL_i_q25 definition.
*   The preferred low-kcal group is reconstructed internally every time.
*===============================================================================


*===============================================================================
* 0. SETTINGS AND REQUIRED PACKAGES
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

foreach v in IDind hhid wave consumer_base d3kcal {
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
* 1. HUNAN–GUIZHOU PURE-CONSUMER SAMPLE
*===============================================================================

foreach v in ///
    ch_sample_hg ///
    ch_treated_hg ///
    ch_sample_pc {

    capture drop `v'
}


capture confirm variable t1

if !_rc {

    gen byte ch_sample_hg = ///
        inlist(t1, 43, 52)

    gen byte ch_treated_hg = ///
        (t1 == 43) ///
        if ch_sample_hg == 1
}
else {

    capture confirm variable province_code

    if _rc {
        display as error ///
            "Neither t1 nor province_code exists; cannot identify Hunan/Guizhou."
        exit 111
    }

    gen byte ch_sample_hg = ///
        inlist(province_code, 43, 52)

    gen byte ch_treated_hg = ///
        (province_code == 43) ///
        if ch_sample_hg == 1
}


gen byte ch_sample_pc = ///
    ch_sample_hg == 1 ///
    & consumer_base == 1 ///
    & inlist(wave, 1997, 2000, 2004, 2006, 2009, 2011)


capture label define ch_hg_treat ///
    0 "Guizhou" ///
    1 "Hunan"

if _rc {
    label define ch_hg_treat ///
        0 "Guizhou" ///
        1 "Hunan", ///
        replace
}

label values ch_treated_hg ch_hg_treat


display as text ""
display as result "============================================================"
display as result "06 CHANNELS — HUNAN / GUIZHOU PURE-CONSUMER SAMPLE"
display as result "============================================================"

tab ch_treated_hg ///
    if ch_sample_pc == 1, ///
    missing

tab wave ///
    if ch_sample_pc == 1, ///
    missing


*===============================================================================
* 2. STRICT TWO-PRE-WAVE INDIVIDUAL BASELINE-CALORIE GROUP
*
* KEY RULE:
*   q25 cutoff is calculated ONLY among individuals with BOTH:
*       1997 kcal observed
*       2000 kcal observed
*===============================================================================

foreach v in ///
    ch_kcal97 ///
    ch_kcal00 ///
    ch_pre_n ///
    ch_pre_kcal ///
    ch_qkcal ///
    ch_low_q25 ///
    ch_sample_pre2 {

    capture drop `v'
}


bysort IDind: egen double ch_kcal97 = max( ///
    cond( ///
        wave == 1997 ///
        & ch_sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


bysort IDind: egen double ch_kcal00 = max( ///
    cond( ///
        wave == 2000 ///
        & ch_sample_pc == 1 ///
        & !missing(d3kcal), ///
        d3kcal, ///
        . ///
    ) ///
)


gen byte ch_pre_n = ///
    !missing(ch_kcal97) ///
    + !missing(ch_kcal00)


gen double ch_pre_kcal = ///
    (ch_kcal97 + ch_kcal00) / 2 ///
    if ch_pre_n == 2


preserve

    keep if ///
        ch_sample_pc == 1 ///
        & ch_pre_n == 2 ///
        & !missing(ch_pre_kcal)

    keep IDind ch_pre_kcal

    bysort IDind: keep if _n == 1

    isid IDind

    quietly count
    local N_pre2 = r(N)

    display as result ///
        "Two-pre-wave individuals defining channel q25 = `N_pre2'"

    if `N_pre2' < 4 {
        display as error ///
            "Too few two-pre-wave individuals to define quartiles."
        restore
        exit 2001
    }

    xtile ch_qkcal = ch_pre_kcal, nq(4)

    gen byte ch_low_q25 = ///
        (ch_qkcal == 1) ///
        if !missing(ch_qkcal)

    keep ///
        IDind ///
        ch_qkcal ///
        ch_low_q25

    tempfile ch_kcal_groups
    save `ch_kcal_groups', replace

restore


merge m:1 IDind ///
    using `ch_kcal_groups', ///
    nogen ///
    keep(master match)


gen byte ch_sample_pre2 = ///
    ch_sample_pc == 1 ///
    & ch_pre_n == 2 ///
    & !missing(ch_low_q25)


label variable ch_pre_kcal ///
    "Mean individual kcal in 1997 and 2000"

label variable ch_low_q25 ///
    "Bottom 25% baseline kcal, both 1997 and 2000 required"


capture drop __ch_tag_pre2

egen byte __ch_tag_pre2 = tag(IDind) ///
    if ch_sample_pre2 == 1


quietly count if __ch_tag_pre2 == 1

display as result ///
    "Preferred two-pre-wave individual sample = " ///
    r(N)


tab ch_low_q25 ch_treated_hg ///
    if __ch_tag_pre2 == 1, ///
    column


drop __ch_tag_pre2


*===============================================================================
* 3. HOUSEHOLD-WAVE SAMPLE
*
* Household outcomes must be estimated once per household-wave.
*===============================================================================

capture drop ch_tag_hhwave

egen byte ch_tag_hhwave = tag(hhid wave) ///
    if ch_sample_pc == 1


quietly count if ///
    ch_sample_pc == 1 ///
    & ch_tag_hhwave == 1

display as result ///
    "Pure-consumer household-wave observations = " ///
    r(N)


*===============================================================================
* 4. POLICY PERIOD VARIABLES
*
* 2004 = announcement
* 2006+ = observed implementation period
*===============================================================================

foreach v in ///
    ch_ann2004 ///
    ch_post_impl ///
    ch_h_ann ///
    ch_h_impl {

    capture drop `v'
}


gen byte ch_ann2004 = ///
    (wave == 2004)


gen byte ch_post_impl = ///
    (wave >= 2006)


gen byte ch_h_ann = ///
    ch_treated_hg * ch_ann2004 ///
    if ch_sample_pc == 1


gen byte ch_h_impl = ///
    ch_treated_hg * ch_post_impl ///
    if ch_sample_pc == 1


label variable ch_h_ann ///
    "Hunan x Announcement 2004"

label variable ch_h_impl ///
    "Hunan x Implementation period"


*===============================================================================
* 5. COMPLETE LOW-KCAL DDD VARIABLES
*===============================================================================

foreach v in ///
    ch_l_ann ///
    ch_ddd_ann ///
    ch_l_impl ///
    ch_ddd_impl {

    capture drop `v'
}


gen byte ch_l_ann = ///
    ch_low_q25 * ch_ann2004 ///
    if ch_sample_pre2 == 1


gen byte ch_ddd_ann = ///
    ch_treated_hg * ch_low_q25 * ch_ann2004 ///
    if ch_sample_pre2 == 1


gen byte ch_l_impl = ///
    ch_low_q25 * ch_post_impl ///
    if ch_sample_pre2 == 1


gen byte ch_ddd_impl = ///
    ch_treated_hg * ch_low_q25 * ch_post_impl ///
    if ch_sample_pre2 == 1


label variable ch_l_ann ///
    "Low baseline kcal x Announcement 2004"

label variable ch_ddd_ann ///
    "Hunan x Low kcal x Announcement 2004"

label variable ch_l_impl ///
    "Low baseline kcal x Implementation period"

label variable ch_ddd_impl ///
    "Hunan x Low kcal x Implementation period (DDD)"


*===============================================================================
* 6. DYNAMIC POLICY VARIABLES
*
* Reference year = 2000.
*===============================================================================

foreach v in ///
    ch_h97 ch_h04 ch_h06 ch_h09 ch_h11 ///
    ch_l97 ch_l04 ch_l06 ch_l09 ch_l11 ///
    ch_d97 ch_d04 ch_d06 ch_d09 ch_d11 {

    capture drop `v'
}


* Hunan x year.
gen byte ch_h97 = ///
    ch_treated_hg * (wave == 1997) ///
    if ch_sample_pc == 1

gen byte ch_h04 = ///
    ch_treated_hg * (wave == 2004) ///
    if ch_sample_pc == 1

gen byte ch_h06 = ///
    ch_treated_hg * (wave == 2006) ///
    if ch_sample_pc == 1

gen byte ch_h09 = ///
    ch_treated_hg * (wave == 2009) ///
    if ch_sample_pc == 1

gen byte ch_h11 = ///
    ch_treated_hg * (wave == 2011) ///
    if ch_sample_pc == 1


* Low-kcal x year.
gen byte ch_l97 = ///
    ch_low_q25 * (wave == 1997) ///
    if ch_sample_pre2 == 1

gen byte ch_l04 = ///
    ch_low_q25 * (wave == 2004) ///
    if ch_sample_pre2 == 1

gen byte ch_l06 = ///
    ch_low_q25 * (wave == 2006) ///
    if ch_sample_pre2 == 1

gen byte ch_l09 = ///
    ch_low_q25 * (wave == 2009) ///
    if ch_sample_pre2 == 1

gen byte ch_l11 = ///
    ch_low_q25 * (wave == 2011) ///
    if ch_sample_pre2 == 1


* Hunan x Low-kcal x year = dynamic DDD.
gen byte ch_d97 = ///
    ch_treated_hg * ch_low_q25 * (wave == 1997) ///
    if ch_sample_pre2 == 1

gen byte ch_d04 = ///
    ch_treated_hg * ch_low_q25 * (wave == 2004) ///
    if ch_sample_pre2 == 1

gen byte ch_d06 = ///
    ch_treated_hg * ch_low_q25 * (wave == 2006) ///
    if ch_sample_pre2 == 1

gen byte ch_d09 = ///
    ch_treated_hg * ch_low_q25 * (wave == 2009) ///
    if ch_sample_pre2 == 1

gen byte ch_d11 = ///
    ch_treated_hg * ch_low_q25 * (wave == 2011) ///
    if ch_sample_pre2 == 1


*===============================================================================
* 7. PART A — HOUSEHOLD RESOURCE CHANNELS
*
* Preferred outcomes:
*   asinh_hhinc_cpi
*   lnhhexpense_real
*
* These are average Hunan-vs-Guizhou channel outcomes.
*===============================================================================

local hh_resource_outcomes ///
    asinh_hhinc_cpi ///
    lnhhexpense_real


*-------------------------------------------------------------------------------
* 7A. Pooled announcement / implementation effects
*-------------------------------------------------------------------------------

eststo clear

local hh_resource_models ""


foreach y of local hh_resource_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pc == 1 ///
            & ch_tag_hhwave == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            display as text ""
            display as result "============================================================"
            display as result "HOUSEHOLD RESOURCE CHANNEL: `y'"
            display as result "============================================================"

            capture noisily reghdfe `y' ///
                ch_h_ann ///
                ch_h_impl ///
                if ch_sample_pc == 1 ///
                & ch_tag_hhwave == 1, ///
                absorb(hhid wave) ///
                vce(cluster cluster_commid)

            if !_rc {

                test ch_h_impl
                local impl_p = r(p)

                estadd scalar impl_p = `impl_p'

                eststo HH_`y'

                local hh_resource_models ///
                    "`hh_resource_models' HH_`y'"

                display as result ///
                    "Implementation coefficient = " ///
                    %9.4f _b[ch_h_impl]

                display as result ///
                    "Implementation p-value     = " ///
                    %9.4f `impl_p'

                estimates save ///
                    "$P2_MODELS/06_hh_`y'.ster", ///
                    replace
            }
        }
    }
}


if "`hh_resource_models'" != "" {

    esttab ///
        `hh_resource_models' ///
        using "$P2_TABLES/06_household_resource_channels.rtf", ///
        replace ///
        keep( ///
            ch_h_ann ///
            ch_h_impl ///
        ) ///
        order( ///
            ch_h_ann ///
            ch_h_impl ///
        ) ///
        coeflabels( ///
            ch_h_ann ///
                "Hunan x Announcement 2004" ///
            ch_h_impl ///
                "Hunan x Implementation period" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats( ///
            impl_p ///
            N, ///
            labels( ///
                "Implementation p-value" ///
                "Observations" ///
            ) ///
            fmt(3 0) ///
        ) ///
        title("Household resource channels") ///
        addnotes( ///
            "Hunan versus Guizhou baseline pure consumers", ///
            "One observation per household-wave", ///
            "2004 is modeled separately as the announcement wave", ///
            "Implementation period: 2006, 2009, and 2011", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*-------------------------------------------------------------------------------
* 7B. Dynamic household resource channels
*-------------------------------------------------------------------------------

eststo clear

local hh_resource_es_models ""


foreach y of local hh_resource_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pc == 1 ///
            & ch_tag_hhwave == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            capture noisily reghdfe `y' ///
                ch_h97 ///
                ch_h04 ///
                ch_h06 ///
                ch_h09 ///
                ch_h11 ///
                if ch_sample_pc == 1 ///
                & ch_tag_hhwave == 1, ///
                absorb(hhid wave) ///
                vce(cluster cluster_commid)

            if !_rc {

                test ch_h97
                local pre_p = r(p)

                test ch_h04
                local ann_p = r(p)

                test ch_h06 ch_h09 ch_h11
                local post_p = r(p)

                estadd scalar pretrend_p = `pre_p'
                estadd scalar announcement_p = `ann_p'
                estadd scalar postjoint_p = `post_p'

                eststo HHES_`y'

                local hh_resource_es_models ///
                    "`hh_resource_es_models' HHES_`y'"

                display as result ///
                    "`y' pretrend p = " ///
                    %9.4f `pre_p'

                display as result ///
                    "`y' announcement p = " ///
                    %9.4f `ann_p'

                display as result ///
                    "`y' joint post p = " ///
                    %9.4f `post_p'

                estimates save ///
                    "$P2_MODELS/06_hh_dynamic_`y'.ster", ///
                    replace
            }
        }
    }
}


if "`hh_resource_es_models'" != "" {

    esttab ///
        `hh_resource_es_models' ///
        using "$P2_TABLES/06_household_resource_channels_dynamic.rtf", ///
        replace ///
        keep( ///
            ch_h97 ///
            ch_h04 ///
            ch_h06 ///
            ch_h09 ///
            ch_h11 ///
        ) ///
        order( ///
            ch_h97 ///
            ch_h04 ///
            ch_h06 ///
            ch_h09 ///
            ch_h11 ///
        ) ///
        coeflabels( ///
            ch_h97 "1997 x Hunan" ///
            ch_h04 "2004 x Hunan" ///
            ch_h06 "2006 x Hunan" ///
            ch_h09 "2009 x Hunan" ///
            ch_h11 "2011 x Hunan" ///
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
                "Pretrend p-value: 1997 vs 2000" ///
                "Announcement p-value: 2004" ///
                "Joint post p-value: 2006/09/11" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 0) ///
        ) ///
        title("Dynamic household resource channels") ///
        addnotes( ///
            "Reference year: 2000", ///
            "1997 x Hunan is the pretrend diagnostic", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*===============================================================================
* 8. PART B — INDIVIDUAL WAGE, BUSINESS-INCOME, AND OCCUPATIONAL CHANNELS
*
* Outcomes:
*   monthly_wage
*   asinh_indbus
*   farmer_ind
*
* Preferred sample:
*   strict two-pre-wave individual low-kcal sample
*===============================================================================

local ind_channel_outcomes ///
    monthly_wage ///
    asinh_indbus ///
    farmer_ind


*-------------------------------------------------------------------------------
* 8A. Pooled low-kcal DDD
*-------------------------------------------------------------------------------

eststo clear

local ind_channel_models ""


foreach y of local ind_channel_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pre2 == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            display as text ""
            display as result "============================================================"
            display as result "INDIVIDUAL CHANNEL DDD: `y'"
            display as result "============================================================"

            reghdfe `y' ///
                ch_h_ann ///
                ch_l_ann ///
                ch_ddd_ann ///
                ch_h_impl ///
                ch_l_impl ///
                ch_ddd_impl ///
                if ch_sample_pre2 == 1, ///
                absorb(IDind wave) ///
                vce(cluster cluster_commid)


            test ch_ddd_impl
            local ddd_p = r(p)


            lincom ch_h_impl + ch_ddd_impl
            local low_b = r(estimate)
            local low_p = r(p)


            test ch_ddd_impl = ch_ddd_ann
            local impl_vs_ann_p = r(p)


            display as result ///
                "Implementation DDD coefficient = " ///
                %9.4f _b[ch_ddd_impl]

            display as result ///
                "Implementation DDD p-value     = " ///
                %9.4f `ddd_p'

            display as result ///
                "Low-kcal total Hunan effect    = " ///
                %9.4f `low_b'

            display as result ///
                "Low-kcal total p-value         = " ///
                %9.4f `low_p'


            estadd scalar ddd_p = `ddd_p'
            estadd scalar low_effect = `low_b'
            estadd scalar low_p = `low_p'
            estadd scalar impl_vs_ann_p = `impl_vs_ann_p'


            eststo IND_`y'

            local ind_channel_models ///
                "`ind_channel_models' IND_`y'"

            estimates save ///
                "$P2_MODELS/06_ind_`y'.ster", ///
                replace
        }
    }
}


if "`ind_channel_models'" != "" {

    esttab ///
        `ind_channel_models' ///
        using "$P2_TABLES/06_individual_channels_DDD.rtf", ///
        replace ///
        keep( ///
            ch_h_ann ///
            ch_l_ann ///
            ch_ddd_ann ///
            ch_h_impl ///
            ch_l_impl ///
            ch_ddd_impl ///
        ) ///
        order( ///
            ch_h_ann ///
            ch_l_ann ///
            ch_ddd_ann ///
            ch_h_impl ///
            ch_l_impl ///
            ch_ddd_impl ///
        ) ///
        coeflabels( ///
            ch_h_ann ///
                "Hunan x Announcement 2004" ///
            ch_l_ann ///
                "Low kcal x Announcement 2004" ///
            ch_ddd_ann ///
                "Hunan x Low kcal x Announcement 2004" ///
            ch_h_impl ///
                "Hunan x Implementation period" ///
            ch_l_impl ///
                "Low kcal x Implementation period" ///
            ch_ddd_impl ///
                "Hunan x Low kcal x Implementation period (DDD)" ///
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
        title("Individual wage, business-income, and occupational channels") ///
        addnotes( ///
            "Low-kcal group is defined only among individuals observed in both 1997 and 2000", ///
            "Individual and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*-------------------------------------------------------------------------------
* 8B. Dynamic low-kcal DDD
*-------------------------------------------------------------------------------

eststo clear

local ind_channel_es_models ""


foreach y of local ind_channel_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pre2 == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            reghdfe `y' ///
                ch_h97 ch_h04 ch_h06 ch_h09 ch_h11 ///
                ch_l97 ch_l04 ch_l06 ch_l09 ch_l11 ///
                ch_d97 ch_d04 ch_d06 ch_d09 ch_d11 ///
                if ch_sample_pre2 == 1, ///
                absorb(IDind wave) ///
                vce(cluster cluster_commid)


            test ch_d97
            local pre_p = r(p)


            test ch_d04
            local ann_p = r(p)


            test ch_d06 ch_d09 ch_d11
            local post_p = r(p)


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


            eststo INDES_`y'

            local ind_channel_es_models ///
                "`ind_channel_es_models' INDES_`y'"

            estimates save ///
                "$P2_MODELS/06_ind_dynamic_`y'.ster", ///
                replace
        }
    }
}


if "`ind_channel_es_models'" != "" {

    esttab ///
        `ind_channel_es_models' ///
        using "$P2_TABLES/06_individual_channels_dynamic_DDD.rtf", ///
        replace ///
        keep( ///
            ch_d97 ///
            ch_d04 ///
            ch_d06 ///
            ch_d09 ///
            ch_d11 ///
        ) ///
        order( ///
            ch_d97 ///
            ch_d04 ///
            ch_d06 ///
            ch_d09 ///
            ch_d11 ///
        ) ///
        coeflabels( ///
            ch_d97 "1997 x Hunan x Low kcal" ///
            ch_d04 "2004 x Hunan x Low kcal" ///
            ch_d06 "2006 x Hunan x Low kcal" ///
            ch_d09 "2009 x Hunan x Low kcal" ///
            ch_d11 "2011 x Hunan x Low kcal" ///
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
        title("Dynamic individual channel DDD") ///
        addnotes( ///
            "Reference year: 2000", ///
            "1997 triple interaction is the differential-pretrend diagnostic", ///
            "Low-kcal group is fixed from the strict 1997/2000 baseline sample", ///
            "Individual and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*===============================================================================
* 9. PART C — HOUSEHOLD AGRICULTURAL-PARTICIPATION OUTCOMES
*
* Outcomes:
*   producer_l1
*   farmer_hh_wave
*
* These are outcomes, NOT subgroup definitions.
*===============================================================================

local hh_ag_outcomes ///
    producer_l1 ///
    farmer_hh_wave


*-------------------------------------------------------------------------------
* 9A. Pooled effects
*-------------------------------------------------------------------------------

eststo clear

local hh_ag_models ""


foreach y of local hh_ag_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pc == 1 ///
            & ch_tag_hhwave == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            reghdfe `y' ///
                ch_h_ann ///
                ch_h_impl ///
                if ch_sample_pc == 1 ///
                & ch_tag_hhwave == 1, ///
                absorb(hhid wave) ///
                vce(cluster cluster_commid)


            test ch_h_impl
            local impl_p = r(p)


            estadd scalar impl_p = `impl_p'


            display as result ///
                "`y' implementation effect = " ///
                %9.4f _b[ch_h_impl]

            display as result ///
                "`y' implementation p      = " ///
                %9.4f `impl_p'


            eststo AG_`y'

            local hh_ag_models ///
                "`hh_ag_models' AG_`y'"

            estimates save ///
                "$P2_MODELS/06_ag_`y'.ster", ///
                replace
        }
    }
}


if "`hh_ag_models'" != "" {

    esttab ///
        `hh_ag_models' ///
        using "$P2_TABLES/06_agricultural_participation.rtf", ///
        replace ///
        keep( ///
            ch_h_ann ///
            ch_h_impl ///
        ) ///
        order( ///
            ch_h_ann ///
            ch_h_impl ///
        ) ///
        coeflabels( ///
            ch_h_ann ///
                "Hunan x Announcement 2004" ///
            ch_h_impl ///
                "Hunan x Implementation period" ///
        ) ///
        b(%9.3f) ///
        se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats( ///
            impl_p ///
            N, ///
            labels( ///
                "Implementation p-value" ///
                "Observations" ///
            ) ///
            fmt(3 0) ///
        ) ///
        title("Agricultural participation outcomes") ///
        addnotes( ///
            "Participation variables are outcomes, not subgroup definitions", ///
            "One observation per household-wave", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*-------------------------------------------------------------------------------
* 9B. Dynamic household agricultural participation
*-------------------------------------------------------------------------------

eststo clear

local hh_ag_es_models ""


foreach y of local hh_ag_outcomes {

    capture confirm variable `y'

    if !_rc {

        quietly count if ///
            ch_sample_pc == 1 ///
            & ch_tag_hhwave == 1 ///
            & !missing(`y')

        if r(N) >= 50 {

            reghdfe `y' ///
                ch_h97 ///
                ch_h04 ///
                ch_h06 ///
                ch_h09 ///
                ch_h11 ///
                if ch_sample_pc == 1 ///
                & ch_tag_hhwave == 1, ///
                absorb(hhid wave) ///
                vce(cluster cluster_commid)


            test ch_h97
            local pre_p = r(p)


            test ch_h04
            local ann_p = r(p)


            test ch_h06 ch_h09 ch_h11
            local post_p = r(p)


            estadd scalar pretrend_p = `pre_p'
            estadd scalar announcement_p = `ann_p'
            estadd scalar postjoint_p = `post_p'


            eststo AGES_`y'

            local hh_ag_es_models ///
                "`hh_ag_es_models' AGES_`y'"
        }
    }
}


if "`hh_ag_es_models'" != "" {

    esttab ///
        `hh_ag_es_models' ///
        using "$P2_TABLES/06_agricultural_participation_dynamic.rtf", ///
        replace ///
        keep( ///
            ch_h97 ///
            ch_h04 ///
            ch_h06 ///
            ch_h09 ///
            ch_h11 ///
        ) ///
        order( ///
            ch_h97 ///
            ch_h04 ///
            ch_h06 ///
            ch_h09 ///
            ch_h11 ///
        ) ///
        coeflabels( ///
            ch_h97 "1997 x Hunan" ///
            ch_h04 "2004 x Hunan" ///
            ch_h06 "2006 x Hunan" ///
            ch_h09 "2009 x Hunan" ///
            ch_h11 "2011 x Hunan" ///
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
                "Pretrend p-value: 1997 vs 2000" ///
                "Announcement p-value: 2004" ///
                "Joint post p-value: 2006/09/11" ///
                "Observations" ///
            ) ///
            fmt(3 3 3 0) ///
        ) ///
        title("Dynamic agricultural participation outcomes") ///
        addnotes( ///
            "Reference year: 2000", ///
            "One observation per household-wave", ///
            "Household and wave fixed effects", ///
            "SE clustered at community level" ///
        )
}


*===============================================================================
* 10. OPTIONAL CONTEMPORANEOUS-CONTROL ROBUSTNESS
*
* Not preferred.
* Current household income is NOT used as a control in wage regressions.
*===============================================================================

local HH_CTRL ///
    "hhsize market trans n_child elderly_share male_share"

local IND_CTRL ///
    "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"


* Household-income robustness.
capture confirm variable asinh_hhinc_cpi

if !_rc {

    capture noisily reghdfe asinh_hhinc_cpi ///
        ch_h_ann ///
        ch_h_impl ///
        `HH_CTRL' ///
        if ch_sample_pc == 1 ///
        & ch_tag_hhwave == 1, ///
        absorb(hhid wave) ///
        vce(cluster cluster_commid)

    if !_rc {

        test ch_h_impl

        display as text ///
            "CONTROL ROBUSTNESS — household income implementation p = " ///
            %9.4f r(p)
    }
}


* Wage-DDD robustness.
capture confirm variable monthly_wage

if !_rc {

    capture noisily reghdfe monthly_wage ///
        ch_h_ann ///
        ch_l_ann ///
        ch_ddd_ann ///
        ch_h_impl ///
        ch_l_impl ///
        ch_ddd_impl ///
        `IND_CTRL' ///
        if ch_sample_pre2 == 1, ///
        absorb(IDind wave) ///
        vce(cluster cluster_commid)

    if !_rc {

        test ch_ddd_impl

        display as text ///
            "CONTROL ROBUSTNESS — wage implementation DDD p = " ///
            %9.4f r(p)
    }
}


*===============================================================================
* 11. DESCRIPTIVE POST-POLICY ENTRY DIAGNOSTICS
*
* DESCRIPTIVE ONLY.
* Never use post-entry / ever-farmer status to define causal nutrition subgroups.
*===============================================================================

capture confirm variable producer_l1

if !_rc {

    foreach v in ///
        ch_post_enter ///
        ch_treated_hh ///
        ch_tag_hh {

        capture drop `v'
    }


    bysort hhid: egen byte ch_post_enter = max( ///
        cond( ///
            inlist(wave, 2006, 2009, 2011) ///
            & producer_l1 == 1, ///
            1, ///
            0 ///
        ) ///
    )


    bysort hhid: egen byte ch_treated_hh = max(ch_treated_hg)


    egen byte ch_tag_hh = tag(hhid) ///
        if ch_sample_hg == 1


    display as text ""
    display as result "============================================================"
    display as result "DESCRIPTIVE POST-POLICY ENTRY DIAGNOSTIC"
    display as result "============================================================"


    tab ch_post_enter ch_treated_hh ///
        if ch_tag_hh == 1, ///
        row
}


capture confirm variable ever_farmer

if !_rc {

    display as text ///
        "NOTE: ever_farmer exists but is NOT used as a causal subgroup variable."
}


*===============================================================================
* 12. END NOTES
*
* 1. q25 is ALWAYS defined only among individuals with BOTH 1997 and 2000 kcal.
* 2. Individual channel regressions use the same fixed strict two-pre-wave group.
* 3. Household outcomes use one row per household-wave.
* 4. 2004 is separated from the observed implementation period.
* 5. Main specifications contain no contemporaneous controls.
* 6. With only one clean pre-treatment lead (1997 vs 2000), pretrend tests are
*    diagnostics rather than proof of parallel trends.
*===============================================================================

display as text ""
display as result "============================================================"
display as result "END OF 06 CHANNEL ANALYSIS"
display as result "============================================================"
