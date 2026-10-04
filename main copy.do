*===============================================================================
* PAPER 2 — MASTER RUNNER FOR VS CODE / STATA
* File: main.do
*
* Recommended usage:
*
*   From this project folder:
*       do main.do
*
*   From anywhere:
*       do "/ABS/PATH/main.do" "/ABS/PATH/paper2_stata_vscode"
*
* IMPORTANT:
*   - This file always reports the exact project root, input data file,
*     and prep files being executed.
*   - prep/01_data_prep.do should CREATE sample flags only.
*     It should NOT permanently drop the dataset to consumer_base == 1.
*===============================================================================


*===============================================================================
* 0. PROJECT ROOT
*===============================================================================

args project_root


* EDIT ONLY THIS LINE IF THE PROJECT FOLDER MOVES.
local configured_root ///
    "/Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode"


* Explicit do-file argument takes precedence.
if `"`project_root'"' == "" & `"`configured_root'"' != "" {
    local project_root `"`configured_root'"'
}


* If neither is supplied, use the current working directory.
if `"`project_root'"' == "" {
    local project_root `"`c(pwd)'"'
}


global P2_ROOT `"`project_root'"'


*===============================================================================
* 1. VALIDATE PROJECT STRUCTURE BEFORE CLEARING MEMORY
*===============================================================================

capture confirm file "$P2_ROOT/config.do"

if _rc {

    display as error ""
    display as error "============================================================"
    display as error "ERROR: config.do NOT FOUND"
    display as error "Project folder:"
    display as error "$P2_ROOT"
    display as error ""
    display as error "Edit local configured_root at the top of main.do."
    display as error "Use the PROJECT FOLDER path, not /main.do itself."
    display as error "============================================================"

    exit 601
}


foreach f in ///
    "prep/00_checks.do" ///
    "prep/01_data_prep.do" ///
    "prep/05_baseline_groups.do" {

    capture confirm file "$P2_ROOT/`f'"

    if _rc {

        display as error ""
        display as error "============================================================"
        display as error "ERROR: REQUIRED FILE NOT FOUND"
        display as error "$P2_ROOT/`f'"
        display as error "============================================================"

        exit 601
    }
}


*===============================================================================
* 2. INITIALIZE PROJECT
*===============================================================================

clear all
set more off
capture log close _all

cd "$P2_ROOT"

do "$P2_ROOT/config.do"


*===============================================================================
* 3. START LOG
*===============================================================================

capture mkdir "$P2_OUTPUT"
capture mkdir "$P2_LOGS"

log using "$P2_LOGS/paper2_run.log", text replace


display as text ""
display as result "============================================================"
display as result "PAPER 2 — MASTER RUN"
display as result "============================================================"

display as text "Project root:"
display as result "$P2_ROOT"

display as text ""
display as text "Input data:"
display as result "$P2_DATA_FILE"

display as text ""
display as text "Prepared-data output:"
display as result "$P2_READY"

display as text ""
display as text "Prep files:"
display as result "$P2_ROOT/prep/00_checks.do"
display as result "$P2_ROOT/prep/01_data_prep.do"
display as result "$P2_ROOT/prep/05_baseline_groups.do"

display as result "============================================================"
display as text ""


*===============================================================================
* 4. HELPER PROGRAM
*===============================================================================

capture program drop p2_run

program define p2_run

    args relative reload


    * Reload the same analysis-ready data before each downstream module.
    if "`reload'" == "1" {

        capture confirm file "$P2_READY"

        if _rc {

            display as error ""
            display as error "ERROR: analysis-ready dataset not found:"
            display as error "$P2_READY"

            exit 601
        }

        use "$P2_READY", clear
    }


    * Confirm the requested do-file exists.
    capture confirm file "$P2_ROOT/`relative'"

    if _rc {

        display as error ""
        display as error "ERROR: do-file not found:"
        display as error "$P2_ROOT/`relative'"

        exit 601
    }


    display as text ""
    display as result "------------------------------------------------------------"
    display as result "RUNNING: `relative'"
    display as result "FULL PATH: $P2_ROOT/`relative'"
    display as result "------------------------------------------------------------"


    capture noisily do "$P2_ROOT/`relative'"


    local result = _rc


    if `result' {

        display as error ""
        display as error "============================================================"
        display as error "PIPELINE STOPPED"
        display as error "File: `relative'"
        display as error "Return code: `result'"
        display as error "See:"
        display as error "$P2_LOGS/paper2_run.log"
        display as error "============================================================"

        capture log close _all

        exit `result'
    }

end


*===============================================================================
* 5. PREPARATION PIPELINE
*===============================================================================


*-------------------------------------------------------------------------------
* PART 0 — INPUT AND DEPENDENCY CHECKS
*-------------------------------------------------------------------------------

p2_run "prep/00_checks.do" 0


*-------------------------------------------------------------------------------
* DIAGNOSTIC AFTER INPUT LOAD
*-------------------------------------------------------------------------------

quietly count
display as text ""
display as result "Observations after 00_checks.do = " r(N)

capture drop __main_tag_hh
egen byte __main_tag_hh = tag(hhid) if !missing(hhid)

quietly count if __main_tag_hh == 1
display as result "Unique households after 00_checks.do = " r(N)

drop __main_tag_hh


*-------------------------------------------------------------------------------
* PART 1 — DATA PREPARATION
*-------------------------------------------------------------------------------

p2_run "prep/01_data_prep.do" 0


*-------------------------------------------------------------------------------
* SAFETY DIAGNOSTIC AFTER DATA PREP
*
* IMPORTANT:
* A correct 01_data_prep.do should normally retain the full panel and create
* consumer_base as a FLAG. It should not keep only consumer_base == 1.
*-------------------------------------------------------------------------------

display as text ""
display as result "============================================================"
display as result "POST-01_DATA_PREP SAMPLE CHECK"
display as result "============================================================"

quietly count
local N_after_prep = r(N)

display as result ///
    "Observations after 01_data_prep.do = `N_after_prep'"


capture drop __main_tag_hh
egen byte __main_tag_hh = tag(hhid) if !missing(hhid)

quietly count if __main_tag_hh == 1
local N_hh_after_prep = r(N)

display as result ///
    "Unique households after 01_data_prep.do = `N_hh_after_prep'"

drop __main_tag_hh


capture confirm variable consumer_base

if _rc {

    display as error ""
    display as error "ERROR: consumer_base was not created by 01_data_prep.do."

    capture log close _all
    exit 111
}


quietly count if consumer_base == 1
local N_consumer_obs = r(N)

display as result ///
    "Observations flagged consumer_base == 1 = `N_consumer_obs'"


capture drop __main_tag_cons_hh

egen byte __main_tag_cons_hh = tag(hhid) ///
    if consumer_base == 1 ///
    & !missing(hhid)

quietly count if __main_tag_cons_hh == 1
local N_consumer_hh = r(N)

display as result ///
    "Unique households flagged consumer_base == 1 = `N_consumer_hh'"

drop __main_tag_cons_hh


* Detect accidental sample collapse.
* This is not an econometric restriction; it is a coding-safety check.
if `N_after_prep' < 1000 {

    display as error ""
    display as error "============================================================"
    display as error "WARNING: DATASET APPEARS TO HAVE COLLAPSED"
    display as error "Only `N_after_prep' observations remain after 01_data_prep.do."
    display as error ""
    display as error "Check that 01_data_prep.do does NOT contain:"
    display as error "    keep if consumer_base == 1"
    display as error ""
    display as error "The main prep file should create sample flags, not drop the panel."
    display as error "============================================================"

    capture log close _all
    exit 2001
}


display as result "============================================================"
display as text ""


*-------------------------------------------------------------------------------
* PART 5 — BASELINE AND EXPLORATORY GROUPS
*-------------------------------------------------------------------------------

p2_run "prep/05_baseline_groups.do" 0


*-------------------------------------------------------------------------------
* SAVE ONE COMMON ANALYSIS-READY DATASET
*-------------------------------------------------------------------------------

save "$P2_READY", replace


display as text ""
display as result "Analysis-ready dataset saved:"
display as result "$P2_READY"
display as text ""


*===============================================================================
* 6. ANALYSIS MODULES
*
* Every module starts from exactly the same saved prepared dataset.
*===============================================================================


if $P2_RUN_DESCRIPTIVE {
    p2_run "output/11_descriptive.do" 1
}


if $P2_RUN_MAIN {
    p2_run "analyses/02_nutrition_main.do" 1
}


if $P2_RUN_KCAL_HET {
    p2_run "analyses/03_kcal_heterogeneity.do" 1
}


if $P2_RUN_INCOME_DDD {
    p2_run "analyses/04_income_ddd.do" 1
}


if $P2_RUN_CHANNELS {
    p2_run "analyses/06_channels.do" 1
}


if $P2_RUN_ROBUSTNESS {
    p2_run "analyses/07_robustness.do" 1
}


if $P2_RUN_BUSINESS {
    p2_run "analyses/08_business_channel.do" 1
}


if $P2_RUN_SHARES {
    p2_run "analyses/09_nutrition_shares.do" 1
}


if $P2_RUN_EVENTDD {
    p2_run "analyses/10_eventdd_shares.do" 1
}


* Always run final table/diagnostic output.
p2_run "output/12_tables_diagnostics.do" 1


*===============================================================================
* 7. FINISH
*===============================================================================

display as text ""
display as result "============================================================"
display as result "PAPER 2 PIPELINE FINISHED SUCCESSFULLY"
display as result "============================================================"

display as text "Results folder:"
display as result "$P2_OUTPUT"

display as text "Prepared dataset:"
display as result "$P2_READY"

display as text "Log:"
display as result "$P2_LOGS/paper2_run.log"

display as result "============================================================"


log close
