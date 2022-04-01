*** 18_188 Optimal Care - Tim J - Test Counts ***
cd "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\Tim_June2021\Test_Info"
set more off

local common_tests_threshold 100 // fairly arbitrary threshold to discard uncommon tests 100 per 1000 pyar

*********************

use "../Patient_Info/patient_info.dta", clear
keep patid patient_pyar_start patient_pyar_end
merge 1:m patid using "combined_tests.dta", keep(1 3) nogen keepusing(event_date test_code description2)
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                       110,640
        from master                   110,640  
        from using                          0  

    matched                        34,521,795  
    -----------------------------------------
*/

* Get rid of tests outside of the patient's time-at-risk
drop if event_date < patient_pyar_start // (2,484,526 observations deleted)
drop if event_date > patient_pyar_end // (127,747 observations deleted)

collapse (count) freq=event_date, by(patid test_code description2)

merge m:1 patid using "../Patient_Info/patient_info", nogen keepusing(patient_pyar patient_pyar_start patient_pyar_end)
/*

    Result                           # of obs.
    -----------------------------------------
    not matched                       133,746
        from master                         0  
        from using                    133,746  

    matched                        10,039,526  
    -----------------------------------------

*/
replace freq = 0 if freq == .

preserve
	bysort patid: gen patindex = _n  // Counting PYAR for each patient only once
	summ(patient_pyar) if patindex == 1
	local all_pyar = `r(sum)'
	collapse (sum) freq, by(test_code description2)
	gen overall_test_rate = (freq / `all_pyar') * 1000
	count if overall_test_rate > `common_tests_threshold'
	keep if overall_test_rate > `common_tests_threshold'
	keep description2 test_code overall_test_rate
	
	* Get rid of tests more likely to be ordered from secondary care
	drop if strpos(description2, "Serum bicarbonate")
	drop if strpos(description2, "Serum chloride")
	
	* Get rid of those we don't think are monitoring tests
	drop if strpos(description2, "Chemical function")
	drop if strpos(description2, "Clotting")
	drop if strpos(description2, "Prostate specific")
	drop if strpos(description2, "Diabetic retinopathy")
	gen common_test_index = _n
	save "common_tests", replace
restore

merge m:1 test_code using "common_tests", keep(3) nogen
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                             0
    matched                         7,381,240  
    -----------------------------------------
*/	


merge m:1 patid using "../Patient_Info/patient_info", nogen keepusing(patient_pyar hyp_flag dm_flag ckd_flag hyp_only dm_only ckd_only)
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                       145,906
        from master                         0  
        from using                    145,906  

    matched                         7,381,240  
    -----------------------------------------
*/
replace freq = 0 if freq == .

save "counts_bytest_bypatient", replace  // 7,527,146

****************

* Update the combined test info to be just the common tests
use "combined_tests.dta", clear
merge m:1 test_code using "common_tests", keep(3) nogen
/*
    Result                           # of obs.
    -----------------------------------------
    not matched                             0
    matched                        27,711,097  
    -----------------------------------------
*/
save "combined_common_tests.dta", replace

****************

* Try to create the table of testing rates by cohort and for everyone versus only those tested
use "counts_bytest_bypatient", clear

* Count the whole cohort
bysort patid: gen index = _n
count if index == 1
local allcount = `r(N)'

tempname testing_rates
postfile `testing_rates' str34 test_name N all_hyp all_hyp_tested only_hyp only_hyp_tested all_diab all_diab_tested only_diab only_diab_tested all_ckd all_ckd_tested only_ckd only_ckd_tested all all_tested using "table_testing_rates.dta", replace

* Work out some appropriate PYAR values for the different cohorts
bysort patid: gen patindex = _n  // Counting PYAR for each patient only once
summ(patient_pyar) if patindex == 1 & hyp_flag == 1
local all_hyp_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1 & hyp_only == 1
local only_hyp_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1 & dm_flag == 1
local all_diab_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1 & dm_only == 1
local only_diab_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1 & ckd_flag == 1
local all_ckd_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1 & ckd_only == 1
local only_ckd_pyar = `r(sum)'
summ(patient_pyar) if patindex == 1
local all_pyar = `r(sum)'

levelsof description2, local(tests)
foreach test of local tests {
    * Sum up the frequencies of this test for different cohorts
	summ(freq) if description2 == "`test'" & hyp_flag == 1
	local all_hyp_freq = `r(sum)'
	summ(freq) if description2 == "`test'" & hyp_only == 1
	local only_hyp_freq = `r(sum)'
	summ(freq) if description2 == "`test'" & dm_flag == 1
	local all_diab_freq = `r(sum)'
	summ(freq) if description2 == "`test'" & dm_only == 1
	local only_diab_freq = `r(sum)'	
	summ(freq) if description2 == "`test'" & ckd_flag == 1
	local all_ckd_freq = `r(sum)'
	summ(freq) if description2 == "`test'" & ckd_only == 1
	local only_ckd_freq = `r(sum)'
	
	* Sum up the pyar for those who were tested at least once with this test for different cohorts
	summ(patient_pyar) if description2 == "`test'" & hyp_flag == 1
	local all_hyp_tested_pyar = `r(sum)'
	summ(patient_pyar) if description2 == "`test'" & hyp_only == 1
	local only_hyp_tested_pyar = `r(sum)'
	summ(patient_pyar) if description2 == "`test'" & dm_flag == 1
	local all_diab_tested_pyar = `r(sum)'
	summ(patient_pyar) if description2 == "`test'" & dm_only == 1
	local only_diab_tested_pyar = `r(sum)'	
	summ(patient_pyar) if description2 == "`test'" & ckd_flag == 1
	local all_ckd_tested_pyar = `r(sum)'
	summ(patient_pyar) if description2 == "`test'" & ckd_only == 1
	local only_ckd_tested_pyar = `r(sum)'
	summ(patient_pyar) if description2 == "`test'"
	local all_tested_pyar = `r(sum)'
	
	* Produce rates (per 1000) for the different cohorts
	if `all_hyp_pyar' ~= 0 {
		local all_hyp_rate = (`all_hyp_freq' / `all_hyp_pyar') * 1000
	}
	else {
	    local all_hyp_rate 0
	}
		
	if `all_hyp_tested_pyar' ~= 0 {
		local all_hyp_tested_rate = (`all_hyp_freq' / `all_hyp_tested_pyar') * 1000
	}
	else {
	    local all_hyp_tested_rate 0
	}
	
	if `only_hyp_pyar' ~= 0 {
		local only_hyp_rate = (`only_hyp_freq' / `only_hyp_pyar') * 1000
	}
	else {
	    local only_hyp_rate 0
	}
	
	if `only_hyp_tested_pyar' ~= 0 {
		local only_hyp_tested_rate = (`only_hyp_freq' / `only_hyp_tested_pyar') * 1000	
	}
	else {
	    local only_hyp_tested_rate 0
	}
	
	if `all_diab_pyar' ~= 0 {
		local all_diab_rate = (`all_diab_freq' / `all_diab_pyar') * 1000
	}
	else {
	    local all_diab_rate 0
	}
	
	if `all_diab_tested_pyar' ~= 0 {
		local all_diab_tested_rate = (`all_diab_freq' / `all_diab_tested_pyar') * 1000
	}
	else {
	    local all_diab_tested_rate 0
	}
	
	if `only_diab_pyar' ~= 0 {
		local only_diab_rate = (`only_diab_freq' / `only_diab_pyar') * 1000
	}
	else {
	    local only_diab_rate 0
	}
	
	if `only_diab_tested_pyar' ~= 0 {
		local only_diab_tested_rate = (`only_diab_freq' / `only_diab_tested_pyar') * 1000	
	}
	else {
	    local only_diab_tested_rate 0
	}
	
	if `all_ckd_pyar' ~= 0 {
		local all_ckd_rate = (`all_ckd_freq' / `all_ckd_pyar') * 1000
	}
	else {
	    local all_ckd_rate 0
	}
	
	if `all_ckd_tested_pyar' ~= 0 {
		local all_ckd_tested_rate = (`all_ckd_freq' / `all_ckd_tested_pyar') * 1000
	}
	else {
	    local all_ckd_tested_rate 0
	}
	
	if `only_ckd_pyar' ~= 0 {
		local only_ckd_rate = (`only_ckd_freq' / `only_ckd_pyar') * 1000
	}
	else {
	    local only_ckd_rate 0
	}
	
	if `only_ckd_tested_pyar' ~= 0 {
		local only_ckd_tested_rate = (`only_ckd_freq' / `only_ckd_tested_pyar') * 1000		
	}
	else {
	    local only_ckd_tested_rate 0
	}
	
	* All tests in all cohorts
	summ(freq) if description2 == "`test'"
	local all_freq = `r(sum)'
	local num_tested = `r(N)'
	local all_rate = (`all_freq' / `all_pyar') * 1000
	local all_tested_rate = (`all_freq' / `all_tested_pyar') * 1000
	

	post `testing_rates' ("`test'") (`num_tested') (`all_hyp_rate') (`all_hyp_tested_rate') (`only_hyp_rate') (`only_hyp_tested_rate') (`all_diab_rate') (`all_diab_tested_rate') (`only_diab_rate') (`only_diab_tested_rate') (`all_ckd_rate') (`all_ckd_tested_rate') (`only_ckd_rate') (`only_ckd_tested_rate') (`all_rate') (`all_tested_rate')
}

postclose `testing_rates'

****************

* Do rankings by testing rates for each condition
use "table_testing_rates.dta", clear
gsort -all
gen all_tests_rank = _n
gsort -only_hyp
gen only_hyp_rank = _n
gsort -only_diab
gen only_diab_rank = _n
gsort -only_ckd
gen only_ckd_rank = _n
gsort -all

keep test_name all all_tests_rank only_hyp only_hyp_rank only_diab only_diab_rank only_ckd only_ckd_rank N
order test_name all all_tests_rank only_hyp only_hyp_rank only_diab only_diab_rank only_ckd only_ckd_rank N

save "test_rankings", replace

***********************

*** Look at individual testing rates and their variation by test ***

* Count the number of tests we're including
use "common_tests", clear
count
local num_tests = `r(N)'

postfile box_plots cohort str34 test_name p10 p25 p50 p75 p90 using "box_plot_info.dta", replace

* Create denominators for whole cohort
foreach cohort of numlist 1/7 {
*** Practice Denominators ***
	use "..\Patient_info\patient_info", clear
	keep if inlist(gender, 1, 2) // (20 observations deleted)
	
	* Keep a particular cohort
	if `cohort' == 1 {
		keep if hyp_flag == 1
		replace index_date = hyp_index_date
	}
	else if `cohort' == 2 {
		keep if hyp_only == 1
		replace index_date = hyp_index_date
	}
	else if `cohort' == 3 {
		keep if dm_flag == 1
		replace index_date = dm_index_date
	}
	else if `cohort' == 4 {
		keep if dm_only == 1
		replace index_date = dm_index_date
	}
	else if `cohort' == 5 {
		keep if ckd_flag == 1
		replace index_date = ckd_index_date
	}
	else if `cohort' == 6 {
		keep if ckd_only == 1
		replace index_date = ckd_index_date
	}	
	
	* Drop if their index date is after the study period
	drop if index_date > date("31/05/2018", "DMY")
	
	replace patient_pyar_start = max(patient_pyar_start, index_date)
	drop if patient_pyar_start >= patient_pyar_end
	replace patient_pyar = (patient_pyar_end - patient_pyar_start) / 365.24

	expand `num_tests'
	bysort patid: gen common_test_index = _n
	
	merge m:1 common_test_index using "common_tests", keep(3) nogen

	tempfile patient_denom`cohort'
	save `patient_denom`cohort'', replace
	
***
	* Get the numberator of tests per patient for each test
	use "counts_bytest_bypatient", clear
   
	* Keep a particular cohort
	if `cohort' == 1 {
		keep if hyp_flag == 1
		// replace index_date = hyp_index_date
	}
	else if `cohort' == 2 {
		keep if hyp_only == 1
		// replace index_date = hyp_index_date
	}
	else if `cohort' == 3 {
		keep if dm_flag == 1
		// replace index_date = dm_index_date
	}
	else if `cohort' == 4 {
		keep if dm_only == 1
		// replace index_date = dm_index_date
	}
	else if `cohort' == 5 {
		keep if ckd_flag == 1
		// replace index_date = ckd_index_date
	}
	else if `cohort' == 6 {
		keep if ckd_only == 1
		// replace index_date = ckd_index_date
	}	
	
	merge m:1 patid test_code using `patient_denom`cohort''
	
	replace freq = 0 if freq == .
	gen test_rate = freq / patient_pyar

	levelsof description2, local(tests)
	foreach test of local tests {
		summ test_rate if description2 == "`test'", detail
		local p10 = `r(p10)'
		local p25 = `r(p25)'
		local p50 = `r(p50)'
		local p75 = `r(p75)'
		local p90 = `r(p90)'
		
		post box_plots (`cohort') ("`test'") (`p10') (`p25') (`p50') (`p75') (`p90')
	}
}
postclose box_plots

use "box_plot_info", clear
merge m:1 test_name using "test_rankings", keep(1 3) keepusing(all) nogen
gsort cohort -all
drop all

*******************

* Count the number of people with at least one test for each test type
use "counts_bytest_bypatient", clear
bysort patid: gen index = _n
count if index == 1 & hyp_flag == 1
local hyp_flag_total = `r(N)'
count if index == 1 & hyp_only == 1
local hyp_only_total = `r(N)'
count if index == 1 & dm_flag == 1
local dm_flag_total = `r(N)'
count if index == 1 & dm_only == 1
local dm_only_total = `r(N)'
count if index == 1 & ckd_flag == 1
local ckd_flag_total = `r(N)'
count if index == 1 & ckd_only == 1
local ckd_only_total = `r(N)'
count if index == 1
local all_total = `r(N)'

drop if freq == 0
gen all = 1

merge m:1 test_code using "common_tests", keep(1 3) nogen

local cohort_list hyp_flag hyp_only dm_flag dm_only ckd_flag ckd_only all
postfile count_nonzero str10 cohort test1 test2 test3 test4 test5 test6 test7 test8 test9 test10 test11 test12 using "nonzero_counts_bytest", replace

foreach cohort of local cohort_list {
    foreach test of numlist 1/12 {
	    count if `cohort' == 1 & common_test_index == `test'
		local count_`cohort'_`test' = `r(N)'
		local pct_`cohort'_`test' = (`count_`cohort'_`test'' / ``cohort'_total') * 100
	}
   
	post count_nonzero ("`cohort' Count") (`count_`cohort'_1') (`count_`cohort'_2') (`count_`cohort'_3') (`count_`cohort'_4') (`count_`cohort'_5') ///
	(`count_`cohort'_6') (`count_`cohort'_7') (`count_`cohort'_8') (`count_`cohort'_9') (`count_`cohort'_10') (`count_`cohort'_11') ///
	(`count_`cohort'_12') 
	post count_nonzero ("`cohort' %") (`pct_`cohort'_1') (`pct_`cohort'_2') (`pct_`cohort'_3') (`pct_`cohort'_4') (`pct_`cohort'_5') ///
	(`pct_`cohort'_6') (`pct_`cohort'_7') (`pct_`cohort'_8') (`pct_`cohort'_9') (`pct_`cohort'_10') (`pct_`cohort'_11') ///
	(`pct_`cohort'_12')
}

postclose count_nonzero

*****

use "nonzero_counts_bytest", clear
order cohort test11 test10 test5 test9 test8 test12 test6 test1 test2 test7 test3 test4
save "nonzero_counts_bytest", replace
