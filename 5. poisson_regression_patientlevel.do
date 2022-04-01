*** 18_188 Optimal Testing - Tim Jones - Poisson Regression (All tests) ***
cd "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\Tim_June2021\Poisson_Regression"
set more off

* ML Win Filepath
global MLwiN_path "C:\Program Files\MLwiN v3.04\mlwin.exe"

* Focus on the most common tests - otherwise it gets a bit overwhelmed with zeros
local test_list 11 10 5 9 8 12 6 1 2 7 3 4

* Count the number of tests we're including
use "..\Test_Info\common_tests", clear
count
local num_tests = `r(N)'

*************

foreach cohort of numlist 1/7 {

	*** Denominators ***
	use "..\Patient_Info\patient_info", clear
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
	
	* Start of follow-up is the latest of their current start of follow-up or their index date
	replace patient_pyar_start = max(patient_pyar_start, index_date)
	drop if patient_pyar_start >= patient_pyar_end
	replace patient_pyar = (patient_pyar_end - patient_pyar_start) / 365.24
	
	expand `num_tests'
	bysort patid: gen common_test_index = _n
	merge m:1 common_test_index using "..\Test_Info\common_tests", keep(1 3) nogen	

	* Complete case analysis
	*drop if eth_num == 0 // (642,294 observations deleted)
	*drop if imd2015_5 == . // 309 deleted
	
	keep patid gender imd2015_5 pracid region num_conds index_date patient_pyar age_grp eth_num common_test_index

	tempfile denomcohort
	save `denomcohort', replace

	***************

	*** Tests ***
	use "..\Standardisation\test_info.dta", clear
	
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

	* Only keep tests during the patient years at risk
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end

	* Complete case analysis
	*drop if eth_num == 0 
	*drop if imd2015_5 == . 	

	merge m:1 test_code using "..\Test_Info\common_tests", keep(3) nogen

	collapse (count) freq=yob, by(patid pracid gender age_grp region imd2015_5 eth_num num_conds common_test_index)
	merge 1:1 patid common_test_index using `denomcohort'
	replace freq = 0 if freq == .
	replace patient_pyar = 1/365.24 if patient_pyar == 0

	label define region_lbl 1 "North East" 2 "North West" 3 "Yorkshire & The Humber" 4 "East Midlands" 5 "West Midlands" 6 "East of England" 7 "South West" 8 "South Central" 9 "London" 10 "South East Coast" 11 "Northern Ireland" 12 "Scotland" 13 "Wales"
	label values region region_lbl	

	keep patid gender imd2015_5 pracid region num_conds age_grp eth_num freq patient_pyar common_test_index
	
	*** ML WIN Information ***
	gen log_patient_pyar = log(patient_pyar)
	gen cons = 1

	* Dummy variables for age
	gen age50 = 0
	replace age50 = 1 if age_grp == 1
	gen age60 = 0
	replace age60 = 1 if age_grp == 2
	gen age70 = 0
	replace age70 = 1 if age_grp == 3
	gen age80 = 0
	replace age80 = 1 if age_grp == 4
	gen age90 = 0
	replace age90 = 1 if age_grp == 5

	gen numconds2 = 0
	replace numconds2 = 1 if num_conds == 2
	gen numconds3 = 0
	replace numconds3 = 1 if num_conds == 3

	gen imd2 = 0
	replace imd2 = 1 if imd2015_5 == 2
	gen imd3 = 0
	replace imd3 = 1 if imd2015_5 == 3
	gen imd4 = 0
	replace imd4 = 1 if imd2015_5 == 4
	gen imd5 = 0
	replace imd5 = 1 if imd2015_5 == 5

	gen eth2 = 0
	replace eth2 = 1 if eth_num == 2
	gen eth3 = 0
	replace eth3 = 1 if eth_num == 3
	gen eth4 = 0
	replace eth4 = 1 if eth_num == 4

	sort region pracid patid	
	
	save "pat_test_mlwin_data`cohort'", replace
}
	****************

local test_list 11 10 5 9 8 12 6 1 2 7 3 4
postfile mlwin_results cohort common_test_index vpc3 vpc3_p25 vpc3_p75 vpc2 vpc2_p25 vpc2_p75 vpc1 vpc1_p25 vpc1_p75 using "mlwin_results", replace	
foreach cohort of numlist 1/7 {	
	foreach test of local test_list {
		use "pat_test_mlwin_data`cohort'", clear
		keep if common_test_index == `test'
		
		*runmlwin freq gender age50 age60 age70 age80 age90 numconds2 numconds3 imd2 imd3 imd4 imd5 eth2 eth3 eth4 cons, level3(region: cons) level2(pracid: cons) level1(patid:) discrete(distribution(poisson) link(log) offset(log_patient_pyar))
		runmlwin freq gender age50 age60 age70 age80 age90 numconds2 numconds3 cons, level3(region: cons) level2(pracid: cons) level1(patid:) discrete(distribution(nbinomial) link(log) offset(log_patient_pyar)) nopause

		* Postestimation of ICC
		gen beta_cons = _b[FP1:cons]
		gen beta_gender = _b[FP1:gender]
		gen beta_age50 = _b[FP1:age50]
		gen beta_age60 = _b[FP1:age60]
		gen beta_age70 = _b[FP1:age70]
		gen beta_age80 = _b[FP1:age80]
		gen beta_age90 = _b[FP1:age90]
		if inlist(`cohort', 1, 3, 5, 7) {
			gen beta_numconds2 = _b[FP1:numconds2]
			gen beta_numconds3 = _b[FP1:numconds3]
		}
		else {
			gen beta_numconds2 = 0
			gen beta_numconds3 = 0			
		}
		gen region_var = _b[RP3:var(cons)]
		gen prac_var = _b[RP2:var(cons)]
		*gen od_var = _b[OD:bcons_1]
		gen od_var = _b[OD:bcons2_1]

		/*
		* POISSON POSTESTIMATION
		gen marginal_expectation = exp(beta_cons + log_patient_pyar + (beta_gender * gender) + (beta_age50 * age50) + (beta_age60 * age60) + (beta_age70 * age70) + (beta_age80 * age80) + (beta_age90 * age90) + (beta_numconds2 * numconds2) + (beta_numconds3 * numconds3) + (region_var / 2) + (prac_var / 2) + (od_var / 2))
		gen level3_variance = (marginal_expectation^2) * (exp(region_var) - 1)
		gen level2_variance = (marginal_expectation^2) * exp(region_var) * (exp(prac_var) - 1)
		gen level1_variance = marginal_expectation + ((marginal_expectation^2) * exp(region_var + prac_var) * (exp(od_var) - 1))

		gen vpc3 = level3_variance / (level1_variance + level2_variance + level3_variance)
		gen vpc2 = level2_variance / (level1_variance + level2_variance + level3_variance)
		gen vpc1 = level1_variance / (level1_variance + level2_variance + level3_variance)
		*/
		
		* NEGATIVE BINOMIAL POSTESTIMATION
		gen marginal_expectation = exp(beta_cons + log_patient_pyar + (beta_gender * gender) + (beta_age50 * age50) + (beta_age60 * age60) + (beta_age70 * age70) + (beta_age80 * age80) + (beta_age90 * age90) + (beta_numconds2 * numconds2) + (beta_numconds3 * numconds3) + (region_var / 2) + (prac_var / 2))
		gen level3_variance = (marginal_expectation^2) * (exp(region_var) - 1)
		gen level2_variance = (marginal_expectation^2) * exp(region_var) * (exp(prac_var) - 1)
		gen level1_variance = marginal_expectation + ((marginal_expectation^2) * exp(region_var + prac_var) * od_var)

		gen vpc3 = level3_variance / (level1_variance + level2_variance + level3_variance)
		gen vpc2 = level2_variance / (level1_variance + level2_variance + level3_variance)
		gen vpc1 = level1_variance / (level1_variance + level2_variance + level3_variance)		
		
		summ vpc3, detail
		local vpc3_p25 = `r(p25)'
		local vpc3_median = `r(p50)'
		local vpc3_p75 = `r(p75)'
		summ vpc2, detail
		local vpc2_p25 = `r(p25)'
		local vpc2_median = `r(p50)'
		local vpc2_p75 = `r(p75)'
		summ vpc1, detail
		local vpc1_p25 = `r(p25)'
		local vpc1_median = `r(p50)'
		local vpc1_p75 = `r(p75)'		
		
		post mlwin_results (`cohort') (`test') (`vpc3_median') (`vpc3_p25') (`vpc3_p75') (`vpc2_median') (`vpc2_p25') (`vpc2_p75') (`vpc1_median') (`vpc1_p25') (`vpc1_p75')
	}
}

postclose mlwin_results

**************

use "mlwin_results", clear
merge m:1 common_test_index using "..\Test_Info\common_tests", keep(1 3) nogen
label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All diabetes" 4 "Only diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort cohort_lbl
keep cohort test_code vpc3 vpc3_p25 vpc3_p75 vpc2 vpc2_p25 vpc2_p75 vpc1 vpc1_p25 vpc1_p75
order cohort test_code vpc3 vpc3_p25 vpc3_p75 vpc2 vpc2_p25 vpc2_p75 vpc1 vpc1_p25 vpc1_p75
sort cohort test_code