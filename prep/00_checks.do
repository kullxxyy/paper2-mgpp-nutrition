*===============================================================================
* PAPER 2 — INPUT AND DEPENDENCY CHECKS
* File: prep/00_checks.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

capture confirm file "$P2_DATA_FILE"
if _rc {
    display as error "paper2_data.dta not found. Edit P2_DATA_FILE in config.do."
    exit 601
}
foreach command in winsor2 reghdfe ftools eststo esttab estpost estadd {
    capture which `command'
    if _rc {
        display as error "Missing command: `command'. Run install_dependencies.do, then main.do."
        exit 199
    }
}
if $P2_RUN_EVENTDD {
    capture which eventdd
    if _rc {
        display as error "eventdd is enabled but not installed. See install_dependencies.do."
        exit 199
    }
}
use "$P2_DATA_FILE", clear
* Stata variable names are case-sensitive. Normalize only the community ID.
capture confirm variable COMMID
if _rc {
    confirm variable commid
    rename commid COMMID
}
else {
    capture confirm variable commid
    if !_rc {

        quietly count if !missing(COMMID) & !missing(commid) & COMMID != commid
        display as text ///
            "COMMID and commid differ in " r(N) ///
            " observations where both are nonmissing."

        quietly count if missing(commid) & !missing(COMMID)
        display as text ///
            "commid missing but COMMID available: " r(N)

        quietly count if missing(COMMID) & !missing(commid)
        display as text ///
            "COMMID missing but commid available: " r(N)
    }
}

local required IDind hhid wave COMMID t1 treated did job farmsize HHFARM ///
    farmconsume farmexp HHFISH hhgard HHLVST d3kcal d3carbo d3fat d3protn ///
    age gender hhsize market trans hhexpense_real HHINC_real
foreach variable of local required {
    confirm numeric variable `variable'
}

* Personal, household and year IDs must be complete
assert !missing(IDind, hhid, wave)

* Report missing community IDs
quietly count if missing(COMMID)
display as text "Observations with missing COMMID: " r(N)

isid IDind wave
assert inlist(treated, 0, 1) if !missing(treated)
assert inlist(did, 0, 1) if !missing(did)
* The input treatment indicator is reused; no new treatment timing is imposed.
capture assert did == treated * (wave >= 2004) if !missing(did, treated, wave)
if _rc display as text "NOTE: input did differs from treated*(wave>=2004); original did is retained."
if $P2_RUN_CHANNELS confirm numeric variable C8
if $P2_RUN_ROBUSTNESS confirm numeric variable t2
if $P2_RUN_BUSINESS {
    foreach variable in H2 HHBUS deflator {
        confirm numeric variable `variable'
    }
}
