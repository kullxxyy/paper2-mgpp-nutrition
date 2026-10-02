*===============================================================================
* PAPER 2 — BASELINE BALANCE AND NUTRITION TRENDS
* File: output/11_descriptive.do
* Run through main.do, or load output/data/paper2_analysis_ready.dta first.
* Locals used below belong to this file; no cross-file local macros are required.
*===============================================================================

*===============================================================================
* %% PART 11 — BASELINE BALANCE AND TREND FIGURES
**# PART 11 — BASELINE BALANCE AND TREND FIGURES
*===============================================================================

tab wave 
preserve
keep if wave==2000

tab job, gen(job_)
* tabulate creates indicators by observed category order, as in the original.
* Keep only source-requested indicator names that exist in the 2000 sample.
local joblist
foreach dummy in job_1 job_3 job_5 job_6 {
    capture confirm variable `dummy'
    if !_rc local joblist `joblist' `dummy'
} 
local xlist  d3kcal d3carbo d3fat d3protn  market trans  HHINC_real ///
             n_child elderly_share male_share age ///
             `joblist' 

* Pre-policy t-tests at wave 2000 (source sample retained).
estpost ttest `xlist', by(treated) unequal
* Export to CSV (Excel-compatible)
esttab using "$P2_TABLES/balance_pre2000.csv", ///
    replace ///
    cells("mu_1(fmt(3)) mu_2(fmt(3)) b(fmt(3)) se(fmt(3)) p(fmt(3))") ///
    collabels("Control" "Treated" "Diff (C-T)" "SE" "p") ///
    nomtitles nonumber noobs compress ///
    label
restore

******line chart 
* outcomes you want to plot
local ylist d3kcal d3carbo d3fat d3protn
local glist 43 52

* (optional) means using egen (kept as your style)
foreach y of local ylist {
    bysort wave t1: egen mean_`y' = mean(`y')
}

* CI bounds (tight loop)
foreach y of local ylist {
    foreach g of local glist {

        gen `y'_high_`g' = .
        gen `y'_low_`g'  = .

        forvalues i = 1997/2015 {
            quietly capture ci mean `y' if wave == `i' & t1 == `g'
            if _rc == 0 {
                replace `y'_high_`g' = r(ub) if wave == `i' & t1 == `g'
                replace `y'_low_`g'  = r(lb) if wave == `i' & t1 == `g'
            }
        }
    }
}

***Daily Calorie Intake
twoway (rcap d3kcal_high_43 d3kcal_low_43 wave) ///
       (line mean_d3kcal wave if t1==43) ///
       (rcap d3kcal_high_52 d3kcal_low_52 wave) ///
       (line mean_d3kcal wave if t1==52), ///
       title("Daily Calorie Intake") ytitle("Calories (kcal)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control")) 
graph export "$P2_FIGURES/11_descriptive_figure_01.png", replace width(2000)

***Daily Carbohydrate Intake
twoway (rcap d3carbo_high_43 d3carbo_low_43 wave) ///
       (line mean_d3carbo wave if t1==43) ///
       (rcap d3carbo_high_52 d3carbo_low_52 wave) ///
       (line mean_d3carbo wave if t1==52), ///
       title("Daily Carbohydrate Intake") ytitle("Carbohydrates (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))
graph export "$P2_FIGURES/11_descriptive_figure_02.png", replace width(2000)

***Daily Fat Intake
twoway (rcap d3fat_high_43 d3fat_low_43 wave) ///
       (line mean_d3fat wave if t1==43) ///
       (rcap d3fat_high_52 d3fat_low_52 wave) ///
       (line mean_d3fat wave if t1==52), ///
       title("Daily Fat Intake") ytitle("Fat (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))
graph export "$P2_FIGURES/11_descriptive_figure_03.png", replace width(2000)

***Daily Protein Intake
twoway (rcap d3protn_high_43 d3protn_low_43 wave) ///
       (line mean_d3protn wave if t1==43) ///
       (rcap d3protn_high_52 d3protn_low_52 wave) ///
       (line mean_d3protn wave if t1==52), ///
       title("Daily Protein Intake") ytitle("Protein (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))
graph export "$P2_FIGURES/11_descriptive_figure_04.png", replace width(2000)
