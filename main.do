*===============================================================================
* PAPER 2 — MASTER RUNNER FOR VS CODE / STATA
* Usage from this project's working directory: do main.do
* Usage from anywhere: do "/ABS/PATH/main.do" "/ABS/PATH/paper2_stata_vscode"
*===============================================================================
args project_root

* EDIT THIS ONE LINE: paste the absolute project FOLDER path, without /main.do.
* Example only: /Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode
* Once filled in, this also works when VS Code sends a temporary do-file.
local configured_root "/Users/lenovo/PhD papers/paper 2/do-file/paper2_stata_vscode"

* An explicit do-file argument takes precedence over the configured folder.
if `"`project_root'"' == "" & `"`configured_root'"' != "" {
    local project_root `"`configured_root'"'
}
if `"`project_root'"' == "" {
    local project_root `"`c(pwd)'"'
}
global P2_ROOT `"`project_root'"'
capture confirm file "$P2_ROOT/config.do"
if _rc {
    display as error "Cannot find config.do in the project folder:"
    display as error "$P2_ROOT"
    display as text "Edit local configured_root at the top of main.do."
    display as text "Paste the project folder path, NOT the path ending in /main.do."
    exit 601
}

* Validate the project folder before clearing any data already open in Stata.
clear all
set more off
capture log close _all
cd "$P2_ROOT"
do "$P2_ROOT/config.do"
log using "$P2_LOGS/paper2_run.log", text replace
display as text "Project folder: $P2_ROOT"
display as text "Input data: $P2_DATA_FILE"

capture program drop p2_run
program define p2_run
    args relative reload
    if "`reload'" == "1" use "$P2_READY", clear
    display as text "Running: `relative'"
    capture noisily do "$P2_ROOT/`relative'"
    local result = _rc
    if `result' {
        display as error "Stopped in `relative'; return code `result'. See output/logs/paper2_run.log."
        capture log close _all
        exit `result'
    }
end

* %% PART 0 — INPUT AND DEPENDENCY CHECKS
p2_run "prep/00_checks.do" 0
* %% PART 1 — DATA PREPARATION
p2_run "prep/01_data_prep.do" 0
* %% PART 5 — BASELINE AND EXPLORATORY GROUPS
p2_run "prep/05_baseline_groups.do" 0
save "$P2_READY", replace

* Reload the same prepared sample before every analysis module.
* This prevents renames, replaces, preserve/restore, or exploratory edits
* in one module from changing the next module's starting data.
if $P2_RUN_DESCRIPTIVE p2_run "output/11_descriptive.do" 1
if $P2_RUN_MAIN        p2_run "analyses/02_nutrition_main.do" 1
if $P2_RUN_KCAL_HET    p2_run "analyses/03_kcal_heterogeneity.do" 1
if $P2_RUN_INCOME_DDD  p2_run "analyses/04_income_ddd.do" 1
if $P2_RUN_CHANNELS    p2_run "analyses/06_channels.do" 1
if $P2_RUN_ROBUSTNESS  p2_run "analyses/07_robustness.do" 1
if $P2_RUN_BUSINESS    p2_run "analyses/08_business_channel.do" 1
if $P2_RUN_SHARES      p2_run "analyses/09_nutrition_shares.do" 1
if $P2_RUN_EVENTDD     p2_run "analyses/10_eventdd_shares.do" 1
p2_run "output/12_tables_diagnostics.do" 1
display as result "Finished. Results: $P2_OUTPUT"
log close
