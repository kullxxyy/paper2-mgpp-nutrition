*===============================================================================
* PAPER 2 — CONFIGURATION (edit paths and run switches here)
*===============================================================================
* main.do sets P2_ROOT from its argument, or from Stata's working directory.
global P2_DATA_FILE "$P2_ROOT/data/paper2_data.dta"
* If the project-local data file is absent, try the original data location.
capture confirm file "$P2_DATA_FILE"
if _rc {
    global P2_DATA_FILE "/Users/lenovo/PhD papers/paper 2/data/CHNS_data_analysis/paper2_data.dta"
}
* You can instead replace P2_DATA_FILE above with your actual absolute data path.

global P2_OUTPUT  "$P2_ROOT/output"
global P2_TABLES  "$P2_OUTPUT/tables"
global P2_FIGURES "$P2_OUTPUT/figures"
global P2_MODELS  "$P2_OUTPUT/models"
global P2_LOGS    "$P2_OUTPUT/logs"
global P2_READY   "$P2_OUTPUT/data/paper2_analysis_ready.dta"

* Analysis switches: 1 = run; 0 = skip.
global P2_RUN_DESCRIPTIVE 1
global P2_RUN_MAIN        1
global P2_RUN_KCAL_HET    1
global P2_RUN_INCOME_DDD  1
global P2_RUN_CHANNELS    1
global P2_RUN_ROBUSTNESS  1
global P2_RUN_BUSINESS    1
global P2_RUN_SHARES      1
global P2_RUN_EVENTDD     0
* The additional eventdd block is retained, but needs eventdd installed.

* Compatibility options: defaults preserve the original statistical definitions.
global P2_CHILD_HHWAVE    0
* 0: original by-hhid count over all waves; 1: count within household-wave.
global P2_INCOME_HH_Q     0
* 0: original observation-weighted baseline-income quartile;
* 1: form baseline-income quartiles using one record per household.
global P2_ES_ADD_2015     0
* 0: original five ES terms; 1: include a 2015 treated dummy as a nuisance term.
* When 2015 is present, option 1 leaves 2000 as the sole omitted survey wave
* (for the source's seven-wave panel). The displayed graph still uses five points.

* Existing third-party Stata packages are checked before analysis.
* Install manually with install_dependencies.do if necessary.
foreach folder in "$P2_OUTPUT" "$P2_TABLES" "$P2_FIGURES" "$P2_MODELS" "$P2_LOGS" "$P2_OUTPUT/data" {
    capture mkdir "`folder'"
}
