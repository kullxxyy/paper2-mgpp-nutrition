clear all 
capture log close 
cd "/Users/lenovo/PhD papers/paper 2/data/CHNS_data_analysis"
use paper2_data.dta, replace
cd "/Users/lenovo/PhD papers/paper 2"
log using paper2, replace


*****Note******
*tripal DDD method to slove the parallel trend assumption problem 

*keep if t2==1
gen year_busexp=H4*12
gen diff=hhexpense-year_busexp
sort diff
*drop if diff==0 
*list F10A HHBUS hhexpense E5 year_busexp diff H2 E5 G5 h1d G16
gen have_exp=(hhexpense > 0)
*keep if hhexpense == 0
*drop if wave<2000 

tab wave
bysort t1: sum hhexpense

*keep  if ag_only==1

*keep if hhexpense>0 
*/
*-----------------------------
* 0) Set last pre-policy year
*-----------------------------
local pre_end = 2003

*-----------------------------
* 1) Farmer member at baseline (pre-policy)
*-----------------------------
gen farmer_ind = (job == 5) if !missing(job)
bys hhid wave: egen farmer_hh_wave = max(farmer_ind)

bys hhid: egen base_farmer = max(farmer_hh_wave==1 & wave<=`pre_end')

*-----------------------------
* 2) Last-year producer evidence at baseline (pre-policy)
*    (measured at wave t, refers to t-1, but we still classify using pre-policy waves)
*-----------------------------
gen prod_land_l1 = (farmsize    > 0) if !missing(farmsize)
gen prod_inc_l1  = (HHFARM  > 0) if !missing(HHFARM)
gen prod_self_l1 = (farmconsume > 0) if !missing(farmconsume)
gen prod_exp_l1  = (farmexp     > 0) if !missing(farmexp)
gen prod_indf_l1 = (HHFISH     > 0) if !missing(HHFISH)
gen prod_indg_l1 = (hhgard     > 0) if !missing(hhgard)
gen prod_indl_l1 = (HHLVST     > 0) if !missing(HHLVST)

egen producer_l1 = rowmax(prod_land_l1 prod_inc_l1 prod_self_l1 prod_exp_l1 ///
                          prod_indf_l1 prod_indg_l1 prod_indl_l1)

bys hhid: egen base_producer = max(producer_l1==1 & wave<=`pre_end')

* Current-period producer evidence (at wave t)
replace producer_l1 = 0 if missing(producer_l1)
label define prod 0 "No ag activity" 1 "Ag activity"
label values producer_l1 prod
bysort hhid: egen ever_farmer = max(producer_l1 * (wave>=2004))

*-----------------------------
* 3) Define baseline pure consumer & keep fixed sample
*-----------------------------
gen consumer_base = (base_farmer==0 & base_producer==0)
label define cons 0 "Not baseline pure consumer" 1 "Baseline pure consumer", replace
label values consumer_base cons

tab consumer_base, missing
keep if consumer_base==1


xtset IDind wave
xtdescribe
tab wave 
tab producer_l1  t1 

preserve
keep if wave==2004 
tab wave t1 
restore 
gen consumer = (producer_l1==0 & farmer_hh_wave==0)
*keep if consumer==1

sum farmsize farmincome farmconsume farmexp indfish indgard indlvst if wave<2004
tab job if wave<2004
*/

*/
*** extreme values 
* Calories and carbohydrates
winsor2 d3kcal,  cuts(1 99) replace
winsor2 d3carbo, cuts(1 99) replace

* Fat (more aggressive)
winsor2 d3fat,   cuts(2.5 97.5) replace

* Protein (light)
winsor2 d3protn, cuts(1 99) replace

sum d3kcal d3carbo d3fat d3protn

/*
bys hhid: egen n_waves = nvals(wave)
drop if n_waves<7
*/



gen child = age < 18 if !missing(age)
bys hhid: egen n_child = total(child)

gen elderly = age >= 65 if !missing(age)
bys hhid wave: egen n_elderly = total(elderly)

gen elderly_share = n_elderly / hhsize

gen male = gender == 1 if !missing(gender)
bys hhid wave: egen n_male = total(male)


gen male_share = n_male / hhsize
sum  n_child elderly_share male_share 


***Summary statistics 
***descriptive statistics about the  difference 
***control vs treated ttest 


gen lnd3kcal=ln(d3kcal)
gen lnd3carbo=ln(d3carbo)
gen lnd3fat=ln(d3fat)
gen lnd3protn=ln(d3protn)

gen lnhhexpense_real=ln(hhexpense_real+1)
gen lnHHINC_real=ln(HHINC_real+1)

bysort have_exp: sum d3fat lnd3fat

local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share  lnHHINC_real"

tab wave 
preserve
keep if wave==2000

tab job, gen(job_)
local joblist job_1 job_3 job_5 job_6 
local xlist  d3kcal d3carbo d3fat d3protn  market trans  HHINC_real ///
             n_child elderly_share male_share age ///
             job_1 job_3 job_5 job_6 

* Post t-tests
estpost ttest `xlist', by(treated) unequal
* Export to CSV (Excel-compatible)
esttab using "balance_pre2004.csv", ///
    replace ///
    cells("mu_1(fmt(3)) mu_2(fmt(3)) b(fmt(3)) se(fmt(3)) p(fmt(3))") ///
    collabels("Control" "Treated" "Diff (T-C)" "SE" "p") ///
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

***Daily Carbohydrate Intake
twoway (rcap d3carbo_high_43 d3carbo_low_43 wave) ///
       (line mean_d3carbo wave if t1==43) ///
       (rcap d3carbo_high_52 d3carbo_low_52 wave) ///
       (line mean_d3carbo wave if t1==52), ///
       title("Daily Carbohydrate Intake") ytitle("Carbohydrates (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))

***Daily Fat Intake
twoway (rcap d3fat_high_43 d3fat_low_43 wave) ///
       (line mean_d3fat wave if t1==43) ///
       (rcap d3fat_high_52 d3fat_low_52 wave) ///
       (line mean_d3fat wave if t1==52), ///
       title("Daily Fat Intake") ytitle("Fat (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))

***Daily Protein Intake
twoway (rcap d3protn_high_43 d3protn_low_43 wave) ///
       (line mean_d3protn wave if t1==43) ///
       (rcap d3protn_high_52 d3protn_low_52 wave) ///
       (line mean_d3protn wave if t1==52), ///
       title("Daily Protein Intake") ytitle("Protein (g)") xtitle("Time (year)") ///
       xline(2004) ///
       legend(label(1 "95% CI") label(2 "Treated (2004)") label(3 "95% CI") label(4 "Control"))



******analysis 
***
* Event time relative to 2004
gen event_time = wave - 2004

* Only real event times in your data
gen evt_m7 = (treated==1 & event_time==-7)   // 1997
gen evt_m4 = (treated==1 & event_time==-4)   // 2000 (baseline)
gen evt_p0 = (treated==1 & event_time==0)    // 2004 (transition)
gen evt_p2 = (treated==1 & event_time==2)    // 2006
gen evt_p5 = (treated==1 & event_time==5)    // 2009
gen evt_p7 = (treated==1 & event_time==7)    // 2011

* Normalize at 2000
drop evt_m4

local outcomes d3kcal d3carbo d3fat d3protn
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share lnHHINC_real "

eststo clear

foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7 evt_p0 evt_p2 evt_p5 evt_p7 ///
        `RD1', ///
        absorb(hhid wave) cluster(COMMID)

    eststo ES_`y'
}

foreach y of local outcomes {
    reghdfe ln`y' evt_m7 evt_p0 evt_p2 evt_p5 evt_p7 `RD1', ///
        absorb(hhid wave) cluster(COMMID)
    di "Pre-trend test for `y'"
    test evt_m7
}

esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    keep(evt_*) ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")


program define draw_es
    args model ttl

    preserve
    clear
    set obs 5
    gen event_time = -7 in 1
    replace event_time = 0 in 2
    replace event_time = 2 in 3
    replace event_time = 5 in 4
    replace event_time = 7 in 5

    gen coef = .
    gen se   = .

    est restore `model'
    matrix b = e(b)
    matrix V = e(V)

    foreach k in m7 p0 p2 p5 p7 {
        local r = cond("`k'"=="m7",1,cond("`k'"=="p0",2,cond("`k'"=="p2",3,cond("`k'"=="p5",4,5))))
        replace coef = b[1,"evt_`k'"] in `r'
        replace se   = sqrt(V["evt_`k'","evt_`k'"]) in `r'
    }

    gen ub = coef + 1.645*se
    gen lb = coef - 1.645*se

    twoway ///
        (rcap ub lb event_time) ///
        (scatter coef event_time, msymbol(O)), ///
        yline(0, lpattern(dash)) ///
        xline(-4, lpattern(dash)) ///
        xtitle("Event time (years relative to 2000)") ///
        ytitle("Effect (log)") ///
        title("Event study: `ttl' (baseline = 2000)") ///
        legend(off)
    restore
end

draw_es ES_d3kcal   "Calories"
draw_es ES_d3carbo  "Carbohydrates"
draw_es ES_d3fat    "Fat"
draw_es ES_d3protn  "Protein"


***less control 
*gen job_miss = missing(job)
*replace job = 0 if missing(job)
local RD1 " c.age##c.age i.job  hhsize market trans n_child elderly_share male_share  lnHHINC_real "
* Run + store
eststo clear
reghdfe lnd3kcal   did `RD1', absorb(IDind wave) cluster(COMMID)
eststo kcal
reghdfe lnd3carbo  did `RD1', absorb(IDind wave) cluster(COMMID)
eststo carbo
reghdfe lnd3fat    did `RD1', absorb(IDind wave) cluster(COMMID)
eststo fat
reghdfe lnd3protn  did `RD1', absorb(IDind wave) cluster(COMMID)
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")


*n_child elderly_share male_share
/*
bys hhid: egen pre_kcal1 = mean(d3kcal) if wave<2004
bys hhid: egen pre_kcal_hh = max(pre_kcal1)
xtile qkcal = pre_kcal_hh, nq(6)
gen lowS1_q25 = (qkcal==1)
label var lowS1_q25 "Low subsistence: bottom 25% pre-kcal"
*/


bys hhid: egen pre_kcal1 = mean(d3kcal) if wave<2004
bys hhid: egen pre_kcal_hh = max(pre_kcal1)
preserve
keep hhid pre_kcal_hh
drop if missing(pre_kcal_hh)
bys hhid: keep if _n == 1
xtile qkcal_hh = pre_kcal_hh, nq(4)
tempfile qfile
save `qfile'
restore
merge m:1 hhid using `qfile', nogen
gen lowS1_q25 = (qkcal_hh == 1)
label var lowS1_q25 "Low subsistence: bottom 25% of pre-policy household calories"

****************************************************
******nutiition outcomes with lowS1_q25*************
****************************************************

local RD1 " c.age##c.age i.job  hhsize market trans   n_child elderly_share male_share lnHHINC_real "
* Run + store
eststo clear
reghdfe lnd3kcal c.age##c.age did##i.lowS1_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25
eststo kcal
reghdfe lnd3carbo  did##i.lowS1_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25
eststo carbo
reghdfe lnd3fat    did##i.lowS1_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25
eststo fat
reghdfe lnd3protn  did##i.lowS1_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")


preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
        `RD1', absorb(hhid wave) cluster(COMMID)
    
    eststo ES_`y'

    test 1.lowS1_q25#1.evt_m7

}
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")
restore


****************************************************
******income change by lowS1_q25********************
****************************************************
local RD1 "  i.job  hhsize market trans   n_child elderly_share male_share  "
reghdfe lnHHINC_real   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe lnHHINC_real ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7

 
rename C8 monthly_wage
replace monthly_wage=. if monthly_wage==-9999
replace monthly_wage=. if monthly_wage==-999
replace monthly_wage=. if monthly_wage==-9

local RD1 " i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe monthly_wage   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe monthly_wage ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7

****nutrition share 
gen kcal_carb = d3carbo * 4
gen kcal_fat = d3fat * 9
gen kcal_protein = d3protn * 4

gen total_kcal = kcal_carb + kcal_fat + kcal_protein

gen carb_share = kcal_carb / total_kcal
gen fat_share = kcal_fat / total_kcal
gen protein_share = kcal_protein / total_kcal

local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe carb_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe carb_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7


local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe fat_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe fat_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7

local RD1 "c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe protein_share   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " i.job hhsize market trans   n_child elderly_share male_share "
reghdfe protein_share ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7


gen ln_monthly_wage=ln(monthly_wage)
gen ln_farmconsume = ln(1 + farmconsume)
local RD1 "  hhsize market trans   n_child elderly_share male_share "
reghdfe ln_farmconsume did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25


local RD1 " i.job   hhsize market trans   n_child elderly_share male_share  "
reghdfe farmconsume   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25







local RD1 " i.job   hhsize market trans   n_child elderly_share male_share  "
reghdfe lnhhexpense_real   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

reghdfe lnhhexpense_real ///
    evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
    `RD1', absorb(hhid wave) cluster(COMMID)
test 1.lowS1_q25#1.evt_m7



// tab agri_part
// gen agri_part = hhexpense > 0 if !missing(hhexpense)
// local RD1 "  hhsize market trans   n_child elderly_share male_share "
// reghdfe agri_part did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
// lincom 1.did + 1.did#1.lowS1_q25






local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe indbus   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age i.job  hhsize market trans   n_child elderly_share male_share  "
reghdfe farmer_ind   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25
sum farmer_ind


sum monthly_wage indwage farmer_ind indbus
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe monthly_wage   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
reghdfe farmer_ind   did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1_q25


*********


gen d3kcal_pre1 = d3kcal if wave < 2004
bys hhid: egen pre_kcal_hh1 = mean(d3kcal_pre)

egen pre_kcal_std1 = std(pre_kcal_hh1)
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
reghdfe lnHHINC_real did##c.pre_kcal_std1 `RD1', absorb(hhid wave) cluster(COMMID)
lincom 1.did + 1.did#c.pre_kcal_std1


preserve
keep hhid pre_kcal_hh
drop if missing(pre_kcal_hh)
bys hhid: keep if _n == 1
isid hhid

xtile q4 = pre_kcal_hh, nq(4)
xtile q5 = pre_kcal_hh, nq(5)
xtile q6 = pre_kcal_hh, nq(6)
xtile q10 = pre_kcal_hh, nq(10)

tempfile qfile
save `qfile'
restore

merge m:1 hhid using `qfile', nogen

gen low_q4  = (q4==1)
gen low_q5  = (q5==1)
gen low_q6  = (q6==1)
gen low_q10 = (q10==1)

local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
foreach g in low_q4 low_q5 low_q6 low_q10 {
    di "========== `g' =========="
    reghdfe lnHHINC_real did##i.`g' `RD1', absorb(hhid wave) cluster(COMMID)
    lincom 1.did + 1.did#1.`g'
}
 



gen q = qkcal_hh if !missing(qkcal_hh)
gen group3 = .
replace group3 = 1 if q==1
replace group3 = 2 if q==2
replace group3 = 3 if q>=3

label define g3 1 "bottom" 2 "midlow" 3 "upper"
label values group3 g3

local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"

reghdfe lnHHINC_real did##ib3.group3 `RD1', absorb(hhid wave) cluster(COMMID)

* total effect for bottom
lincom 1.did + 1.did#1.group3

* total effect for midlow
lincom 1.did + 1.did#2.group3

* difference between bottom and midlow
lincom 1.did#1.group3 - 1.did#2.group3









****************************************************
******nutiition outcomes with lowINC_q25*************
****************************************************
* Pre-policy income
bys hhid: egen pre_inc1 = mean(lnHHINC_real) if wave < 2004
bys hhid: egen pre_inc = max(pre_inc1)

* Bottom quartile of baseline income
xtile qinc = pre_inc, nq(4)
gen lowINC_q25 = (qinc==1)
label var lowINC_q25 "Low income: bottom 25% pre-policy"

preserve
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share  "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowINC_q25
eststo kcal
reghdfe lnd3carbo  did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowINC_q25
eststo carbo
reghdfe lnd3fat    did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowINC_q25
eststo fat
reghdfe lnd3protn  did##i.lowINC_q25 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowINC_q25
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
restore 

preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowINC_q25  evt_p0##i.lowINC_q25   evt_p2##i.lowINC_q25   evt_p5##i.lowINC_q25   evt_p7##i.lowINC_q25  ///
        `RD1', absorb(hhid wave) cluster(commid)
    
    eststo ES_`y'

    test 1.lowINC_q25#1.evt_m7

}
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")
restore


****************************************************
******DDD anaylsis *********************************
****************************************************
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"

eststo clear
foreach y in lnd3kcal lnd3carbo lnd3fat lnd3protn {

    reghdfe `y' ///
        did##i.lowS1_q25##i.lowINC_q25 ///
        `RD1', ///
        absorb(IDind wave) cluster(COMMID)

    eststo `y'
    lincom 1.did
    lincom 1.did + 1.did#1.lowS1_q25
    lincom 1.did + 1.did#1.lowINC_q25
    lincom 1.did + 1.did#1.lowS1_q25 + 1.did#1.lowINC_q25 + 1.did#1.lowS1_q25#1.lowINC_q25

}


preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowS1_q25##i.lowINC_q25  evt_p0##i.lowS1_q25##i.lowINC_q25   evt_p2##i.lowS1_q25##i.lowINC_q25 evt_p5##i.lowS1_q25##i.lowINC_q25   evt_p7##i.lowS1_q25##i.lowINC_q25  ///
        `RD1', absorb(hhid wave) cluster(commid)
    
    eststo ES_`y'
    test 1.evt_m7#1.lowS1_q25#1.lowINC_q25

}
esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")

restore




local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 did `RD1', absorb(hhid wave) cluster(commid)

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.lowS1_q25

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe producer_l1 evt_m7##i.lowS1_q25 evt_p0##i.lowS1_q25 evt_p2##i.lowS1_q25 evt_p5##i.lowS1_q25 evt_p7##i.lowS1_q25 `RD1', ///
    absorb(hhid wave) cluster(commid)




local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal did##i.ever_farmer `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer `RD1', ///
    absorb(hhid wave) cluster(commid)





preserve 
keep if lowS1_q25==1
local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal did##i.ever_farmer `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3kcal evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer `RD1', ///
    absorb(hhid wave) cluster(commid)

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3carbo did##i.ever_farmer `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3carbo evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer `RD1', ///
    absorb(hhid wave) cluster(commid)


local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3fat did##i.ever_farmer `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3fat evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer `RD1', ///
    absorb(hhid wave) cluster(commid)


local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3protn did##i.ever_farmer `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.ever_farmer

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe lnd3protn evt_m7##i.ever_farmer evt_p0##i.ever_farmer evt_p2##i.ever_farmer evt_p5##i.ever_farmer evt_p7##i.ever_farmer `RD1', ///
    absorb(hhid wave) cluster(commid)

restore 

***robustness check 
* Example: define low subsistence group by pre-policy calories
bys hhid: egen pre_kcal = mean(d3kcal) if wave<2004   // adjust to your pre period definition
bys hhid: egen pre_kcal2 = max(pre_kcal)
xtile lowS = pre_kcal2, nq(2)
gen lowS1 = (lowS==1)   // bottom quartile = “near subsistence”

preserve
local outcomes d3kcal d3carbo d3fat d3protn
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe ln`y' ///
        evt_m7##i.lowS1  evt_p0##i.lowS1   evt_p2##i.lowS1   evt_p5##i.lowS1   evt_p7##i.lowS1  ///
        `RD1', absorb(hhid wave) cluster(commid)
    
    eststo ES_`y'

    test 1.lowS1#1.evt_m7

}

esttab ES_d3kcal ES_d3carbo ES_d3fat ES_d3protn, ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event-study estimates (normalized at 2000)") ///
    addnotes("Baseline: 2000 wave","Clustered SE at community level")
restore


local RD1 " c.age##c.age i.job hhsize market trans  n_child elderly_share male_share lnHHINC_real"
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1
eststo kcal
reghdfe lnd3carbo  did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1
eststo carbo
reghdfe lnd3fat    did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1
eststo fat
reghdfe lnd3protn  did##i.lowS1 `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.lowS1
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")






replace farmer_hh_wave = 0 if missing(farmer_hh_wave)
tab farmer_hh_wave

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe farmer_hh_wave did `RD1', absorb(hhid wave) cluster(commid)

local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share lnHHINC_real"
reghdfe farmer_hh_wave did##i.lowS1_q25 `RD1', absorb(hhid wave) cluster(commid)
* Effect for low-S: beta_did + beta_interaction
lincom 1.did + 1.did#1.lowS1_q25

preserve
local outcomes farmer_hh_wave
local RD1 " c.age##c.age hhsize market trans   n_child elderly_share male_share lnHHINC_real"

eststo clear
foreach y of local outcomes {

    reghdfe `y' ///
        evt_m7##i.lowS1_q25  evt_p0##i.lowS1_q25   evt_p2##i.lowS1_q25   evt_p5##i.lowS1_q25   evt_p7##i.lowS1_q25  ///
        `RD1', absorb(hhid wave) cluster(commid)
    
    eststo ES_`y'

    test 1.lowS1_q25#1.evt_m7

}
restore 



* Controls
local RD1 "c.age##c.age i.job hhsize market trans n_child elderly_share male_share"
* Outcomes
local outcomes lnd3kcal lnd3carbo lnd3fat lnd3protn

* Run DDD regressions
eststo clear
foreach y of local outcomes {

    reghdfe `y' ///
    evt_m7##i.lowS1##i.ever_farmer ///
        `RD1', ///
        absorb(IDind wave) cluster(COMMID)

    eststo `y'
}


* Export table
esttab lnd3kcal lnd3carbo lnd3fat lnd3protn, ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    addnotes("DDD: did × lowS1 × farmer entry" ///
             "Household and wave fixed effects" ///
             "t statistics in parentheses")




bys hhid: egen post_enter = max(producer*(wave>=2004))   // choose post window
bys hhid: egen treated_hh = max(treated)
tab post_enter treated_hh, row
local RD1 " c.age##c.age  hhsize market trans n_child elderly_share male_share "
reg post_enter treated_hh `RD1', vce(cluster commid)



local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share "
reghdfe producer_l1 did `RD1', absorb(hhid wave) cluster(commid)

gen rural=t2-1
preserve
keep if ever_farmer==0
local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.rural
eststo kcal
reghdfe lnd3carbo  did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.rural
eststo carbo
reghdfe lnd3fat    did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.rural
eststo fat
reghdfe lnd3protn  did##i.rural `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.rural
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
restore 


* shares
gen kcal_imp = 4*d3carbo + 9*d3fat + 4*d3protn
gen sC_imp = (4*d3carbo)/kcal_imp
gen sF_imp = (9*d3fat)/kcal_imp
gen sP_imp = (4*d3protn)/kcal_imp
gen Q2 = ln((9*(d3fat+0.1) + 4*(d3protn+0.1)) / (4*(d3carbo+0.1)))

* Compute median of total calories
summarize kcal_imp, detail
local med_kcal = r(p50)
* Indicator for low-calorie (near-subsistence) households
gen low_kcal = kcal_imp < `med_kcal'

summ kcal_imp, detail
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)

gen kcal_q = .
replace kcal_q = 1 if kcal_imp <  `p25'
replace kcal_q = 2 if kcal_imp >= `p25' & kcal_imp < `p50'
replace kcal_q = 3 if kcal_imp >= `p50' & kcal_imp < `p75'
replace kcal_q = 4 if kcal_imp >= `p75'


preserve
sum lnHHINC_real, detail
gen low_income = (lnHHINC_real <= r(p50))
label define lowinc 0 "High income" 1 "Low income"
label values low_income lowinc


local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_income
eststo kcal
reghdfe lnd3carbo  did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_income
eststo carbo
reghdfe lnd3fat    did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_income
eststo fat
reghdfe lnd3protn  did##i.low_income `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_income
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")
restore 

* Quartiles
xtile q_income = lnHHINC_real, nq(4)
fvset base 1 q_income
label define qinc 1 "Q1 (lowest)" 2 "Q2" 3 "Q3" 4 "Q4 (highest)", replace
label values q_income qinc

local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share "

eststo clear

foreach y in lnd3kcal lnd3carbo lnd3fat lnd3protn {

    reghdfe `y' did##i.q_income `RD1', absorb(IDind wave) cluster(COMMID)

    quietly lincom 1.did
    estadd scalar DID_Q1 = r(estimate)

    quietly lincom 1.did + 1.did#2.q_income
    estadd scalar DID_Q2 = r(estimate)

    quietly lincom 1.did + 1.did#3.q_income
    estadd scalar DID_Q3 = r(estimate)

    quietly lincom 1.did + 1.did#4.q_income
    estadd scalar DID_Q4 = r(estimate)

    * store with nice names
    if "`y'"=="lnd3kcal"   eststo kcal
    if "`y'"=="lnd3carbo"  eststo carbo
    if "`y'"=="lnd3fat"    eststo fat
    if "`y'"=="lnd3protn"  eststo protn
}

esttab kcal carbo fat protn, ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    b(%9.3f) t(%9.2f) ///
    stats(DID_Q1 DID_Q2 DID_Q3 DID_Q4, ///
          labels("DID effect: Q1 (lowest)" "DID effect: Q2" "DID effect: Q3" "DID effect: Q4 (highest)") ///
          fmt(%9.3f %9.3f %9.3f %9.3f)) ///
    addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")



local RD1 " c.age##c.age i.job hhsize market trans   n_child elderly_share male_share "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo kcal
reghdfe lnd3carbo  did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo carbo
reghdfe lnd3fat    did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo fat
reghdfe lnd3protn  did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")




local RD1 " c.age##c.age i.job hhsize market trans c.lnHHINC_real n_child elderly_share male_share  "
* Run + store
eststo clear
reghdfe lnd3kcal   did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
eststo kcal
reghdfe lnd3carbo  did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
eststo carbo
reghdfe lnd3fat    did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
eststo fat
reghdfe lnd3protn  did##i.kcal_q `RD1', absorb(IDind wave) cluster(COMMID)
eststo protn
esttab kcal carbo fat protn, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")



preserve
gen imple_year=.
replace imple_year=2004 if t1==43
gen timeToTreat = wave-imple_year

local add = 18   // number of event-time values (-7 to 10) = 10 - (-7) + 1 = 18
insobs `add'

local k = _N - `add' + 1   // starting observation for new rows

forvalues x = -7/10{
    replace timeToTreat = `x' in `k'
    local ++k
}
    local RD1 " c.age##c.age i.job hhsize market trans n_child elderly_share male_share   lnHHINC_real"
eventdd  sC_imp  `RD' ,hdfe absorb(i.hhid i.wave ) cluster(commid) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Household farm expense") xlabel(-7(1)10)) 
 estat leads  
eventdd  sF_imp  `RD' ,hdfe absorb(i.hhid i.wave ) cluster(commid) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Household farm expense") xlabel(-7(1)10)) 
 estat leads  
eventdd  sP_imp  `RD' ,hdfe absorb(i.hhid i.wave ) cluster(commid) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("fat") xlabel(-7(1)10)) 
 estat leads  
eventdd  Q2  `RD' ,hdfe absorb(i.hhid i.wave ) cluster(commid) timevar(timeToTreat)  ci(rcap)  accum leads(7) lags(10)  level(90) graph_op(ytitle("Household farm expense") xlabel(-7(1)10)) 
 estat leads 
restore



local RD1 " c.age##c.age i.job hhsize market trans c.lnHHINC_real  n_child elderly_share male_share  "
eststo clear
reghdfe sC_imp did `RD1', absorb(IDind wave) cluster(COMMID)
eststo sC_imp
reghdfe sF_imp did `RD1', absorb(IDind wave) cluster(COMMID)
eststo sF_imp
reghdfe sP_imp did `RD1', absorb(IDind wave) cluster(COMMID)
eststo sP_imp
reghdfe Q2  did `RD1', absorb(IDind wave) cluster(COMMID)
eststo Q2
esttab sC_imp sF_imp sP_imp  Q2, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")



* Example: low-calorie households
eststo clear
local RD1 " c.age##c.age i.job hhsize index comm  c.lnHHINC_real   "
reghdfe sC_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo sC_imp
reghdfe sF_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo sF_imp
reghdfe sP_imp did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo sP_imp
reghdfe Q2    did##i.low_kcal `RD1', absorb(IDind wave) cluster(COMMID)
lincom 1.did + 1.did#1.low_kcal
eststo Q2
esttab sC_imp sF_imp sP_imp  Q2, star(* 0.10 ** 0.05 *** 0.01) b(%9.3f) t(%9.2f) addnotes("t statistics in parentheses","* p<0.10, ** p<0.05, *** p<0.01")




*********************************************************************************
*********************************************************************************
*********************************************************************************
*********************************************************************************
*********************************************************************************

*******************************************************
* BUSINESS CHANNEL
*******************************************************

* 1. Business sector: use H2
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


