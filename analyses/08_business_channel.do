*===============================================================================
* PAPER 2 — LAG-ADJUSTED HOUSEHOLD BUSINESS CHANNEL
* File: analyses/08_business_channel.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 8 — BUSINESS SECTOR, INCOME AND LAG-ADJUSTED DID
**# PART 8 — BUSINESS SECTOR, INCOME AND LAG-ADJUSTED DID
*===============================================================================

capture drop bus_commerce bus_manufacturing
gen bus_commerce      = (H2==1) if !missing(H2)
gen bus_manufacturing = (H2==3) if !missing(H2)

* Household-wave dummies
bys hhid wave: egen hh_commerce = max(bus_commerce)
bys hhid wave: egen hh_manufact = max(bus_manufacturing)

* 2. Business income
capture drop HHBUS_real asinh_HHBUS hh_bus_income

* Recode special missing values only
replace HHBUS = . if inlist(HHBUS,-9,-99,-999,-9999)

gen HHBUS_real = HHBUS * deflator
winsor2 HHBUS_real, cuts(1 99) replace
gen asinh_HHBUS = asinh(HHBUS_real)

bys hhid wave: egen hh_bus_income = max(asinh_HHBUS)

* 3. Lag-adjusted DID
capture drop behavior_year post_lag did_lag did_lag_low

gen behavior_year = wave - 1
gen post_lag = (behavior_year >= 2004)
gen did_lag = treated * post_lag
gen did_lag_low = did_lag * lowS1_q25

capture drop tag_hhwave
egen tag_hhwave = tag(hhid wave)

* 4. Controls
local X_HH "hhsize market trans n_child elderly_share male_share"

* 5. Regressions: ONE observation per household-wave
eststo clear

foreach y in hh_bus_income hh_commerce hh_manufact {

    reghdfe `y' ///
        did_lag did_lag_low `X_HH' ///
        if tag_hhwave==1, ///
        absorb(hhid wave) vce(cluster COMMID)
    estimates save "$P2_MODELS/08_business_channel_model_01_`y'_`g'.ster", replace

    lincom did_lag + did_lag_low

    estadd scalar low_effect = r(estimate)
    estadd scalar low_p      = r(p)

    eststo `y'
}

* 6. Table
esttab hh_bus_income hh_commerce hh_manufact, ///
    keep(did_lag did_lag_low) ///
    coeflabels( ///
        did_lag     "MGPP" ///
        did_lag_low "MGPP x low-kcal") ///
    mtitles("Business income" "Commerce" "Manufacturing") ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(low_effect low_p N, ///
        labels("Low-kcal effect" "p-value" "Observations") ///
        fmt(3 3 0))

* Save this displayed table.
esttab hh_bus_income hh_commerce hh_manufact using "$P2_TABLES/08_business_channel_table_01.rtf", replace ///
    keep(did_lag did_lag_low) ///
    coeflabels( ///
        did_lag     "MGPP" ///
        did_lag_low "MGPP x low-kcal") ///
    mtitles("Business income" "Commerce" "Manufacturing") ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(low_effect low_p N, ///
        labels("Low-kcal effect" "p-value" "Observations") ///
        fmt(3 3 0))

* Save this displayed table.
esttab hh_bus_income hh_commerce hh_manufact using "$P2_TABLES/08_business_channel_table_01.csv", replace ///
    keep(did_lag did_lag_low) ///
    coeflabels( ///
        did_lag     "MGPP" ///
        did_lag_low "MGPP x low-kcal") ///
    mtitles("Business income" "Commerce" "Manufacturing") ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(low_effect low_p N, ///
        labels("Low-kcal effect" "p-value" "Observations") ///
        fmt(3 3 0))
