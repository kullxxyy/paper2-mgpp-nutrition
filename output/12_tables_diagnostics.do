*===============================================================================
* PAPER 2 — TABLES AND SAMPLE DIAGNOSTICS
* File: output/12_tables_diagnostics.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 12 — SAMPLE DIAGNOSTICS
**# PART 12 — SAMPLE DIAGNOSTICS
*===============================================================================

* A compact record of the prepared sample; no new regressions are imposed.
display as text "Compatibility: CHILD_HHWAVE=$P2_CHILD_HHWAVE; INCOME_HH_Q=$P2_INCOME_HH_Q; ES_ADD_2015=$P2_ES_ADD_2015"
tab wave treated, missing
tab lowS1_q25 lowINC_q25, missing
count if missing(pre_kcal_hh)
display as text "Observations without baseline calories: " r(N)
count if missing(pre_inc)
display as text "Observations without baseline income: " r(N)
count if wave==2015
if r(N)>0 & $P2_ES_ADD_2015==0 {
    display as text "Source ES has no 2015 dummy; 2015 joins omitted periods. See CHANGES.md / P2_ES_ADD_2015."
}
preserve
egen byte tag_hh = tag(hhid)
egen byte tag_ind = tag(IDind)
egen byte tag_hhw = tag(hhid wave)
gen byte observation = 1
collapse (sum) observations=observation households_present=tag_hhw ///
    first_observed_households=tag_hh first_observed_individuals=tag_ind, by(wave treated)
export delimited using "$P2_TABLES/sample_by_wave.csv", replace
restore
preserve
egen byte tag_hh = tag(hhid)
keep if tag_hh
gen byte household = 1
collapse (sum) households=household, by(treated lowS1_q25 lowINC_q25)
export delimited using "$P2_TABLES/baseline_group_cells.csv", replace
restore
* Tabulations and lincom/test results are also preserved in paper2_run.log.
