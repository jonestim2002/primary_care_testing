*** 18_188 Optimal Testing - Tim Jones - Age-sex standardised rates ***
cd "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\Tim_June2021"
set more off

*** Create some standard weights - based on everyone in the cohort (hyp/diab/ckd) ***
use "Patient_Info\patient_info", clear

* Check population
count
local totalpop = `r(N)'

* Stick to male/female gender for now
keep if inlist(gender, 1, 2)  // 20 deleted
* 1,176,836

collapse (count) freq=patid, by(gender age_grp)
gen weight = freq / `totalpop'
drop freq

save "Standardisation\asr_weights.dta", replace

*****************

*** Get numerator (test) information along with all of the demographic info ***
use "Patient_Info\patient_info", clear
drop frd_date crd_date tod_date cprd_death_date match_rank ons_dod lcd_date uts_date overall_death_date patient_latest patient_earliest study_start study_end
merge 1:m patid using "Test_Info\combined_common_tests.dta", keep(3) nogen keepusing(event_date description2 test_code)

* Get rid of tests outside of the patient's time-at-risk
drop if event_date < patient_pyar_start // (2,801,029 observations deleted)
drop if event_date > patient_pyar_end // (18,810 observations deleted)

keep if inlist(gender, 1, 2)  // (247 observations deleted)

save "Standardisation\test_info.dta", replace

*****************

* Count the number of tests we're including
use "Test_Info\common_tests", clear
count
local num_tests = `r(N)'

********************

*** REGION ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Regions Denominators ***
	use "Patient_info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(region gender age_grp)

	expand `num_tests'
	bysort region gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile region_denom`cohort'
	save `region_denom`cohort'', replace

	***************

	*** Region Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end
	
	collapse (count) freq=patid, by(region gender age_grp test_code)
	merge m:1 region gender age_grp test_code using `region_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(region test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep region test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile region_asr`cohort'
	save `region_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `region_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl
label define region_lbl 1 "North East" 2 "North West" 3 "Yorkshire & The Humber" 4 "East Midlands" 5 "West Midlands" 6 "East of England" 7 "South West" 8 "South Central" 9 "London" 10 "South East Coast" 11 "Northern Ireland" 12 "Scotland" 13 "Wales"
label values region region_lbl

order cohort_num region test_code crude_rate asr
save "Standardisation\region.dta", replace

******************

*** DEPRIVATION ***

* Count the number of tests we're including
use "Test_Info\common_tests", clear
count
local num_tests = `r(N)'
* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** IMD Denominators ***
	use "Patient_Info\patient_info", clear
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

	
	* Label missing IMD as group 6
	replace imd2015_5 = 6 if imd2015_5 == .

	collapse (sum) pyar=patient_pyar, by(imd2015_5 gender age_grp)

	expand `num_tests'
	bysort imd2015_5 gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen	

	tempfile imd_denom`cohort'
	save `imd_denom`cohort'', replace

	***************

	*** IMD Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end
	
	* Label missing IMD as group 6
	replace imd2015_5 = 6 if imd2015_5 == .	
	
	collapse (count) freq=patid, by(imd2015_5 gender age_grp test_code)
	merge m:1 imd2015_5 gender age_grp test_code using `imd_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(imd2015_5 test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep imd2015_5 test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile imd_asr`cohort'
	save `imd_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `imd_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl
label define dep_lbl 1 "1 - Least Deprived" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6 - Missing"
label values imd2015_5 dep_lbl

order cohort_num imd2015_5 test_code crude_rate asr
save "Standardisation\imd2015_5.dta", replace

*******************************

*** ETHNICITY ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Ethnicity Denominators ***
	use "Patient_Info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(eth_num gender age_grp)

	expand `num_tests'
	bysort eth_num gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen	

	tempfile eth_denom`cohort'
	save `eth_denom`cohort'', replace

	***************

	*** Ethnicity Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end	

	collapse (count) freq=patid, by(eth_num gender age_grp test_code)
	merge m:1 eth_num gender age_grp test_code using `eth_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(eth_num test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep eth_num test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile eth_asr`cohort'
	save `eth_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `eth_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl

order cohort_num eth_num test_code crude_rate asr
save "Standardisation\eth_num.dta", replace

**************************

*** GENDER (without standardisation) ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Gender Denominators ***
	use "Patient_Info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(gender)

	expand `num_tests'
	bysort gender: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile gender_denom`cohort'
	save `gender_denom`cohort'', replace

	***************

	*** Gender Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end	
	
	keep if inlist(gender, 1, 2)
	
	collapse (count) freq=patid, by(gender test_code)
	merge m:1 gender test_code using `gender_denom`cohort''
	replace freq = 0 if freq == .

	gen crude_rate = (freq / pyar) * 1000
	keep gender test_code crude_rate
	
	gen cohort_num = `cohort'

	tempfile gender_asr`cohort'
	save `gender_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `gender_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl
label define gender_lbl 1 "Men" 2 "Women"
label values gender gender_lbl

order cohort_num gender test_code crude_rate
save "Standardisation\gender.dta", replace


*******************************

*** AGE GROUP ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Ethnicity Denominators ***
	use "Patient_Info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(age_grp)

	expand `num_tests'
	bysort age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile age_denom`cohort'
	save `age_denom`cohort'', replace

	***************

	*** Age Group Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end	
	
	keep if inlist(gender, 1, 2)
	
	collapse (count) freq=patid, by(age_grp test_code)
	merge m:1 age_grp test_code using `age_denom`cohort''
	replace freq = 0 if freq == .

	gen crude_rate = (freq / pyar) * 1000
	keep age_grp test_code crude_rate
	
	gen cohort_num = `cohort'

	tempfile age_asr`cohort'
	save `age_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `age_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl

order cohort_num age_grp test_code crude_rate
save "Standardisation\age_grp.dta", replace


*******************************

*** CALENDAR YEARS ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Year Denominators ***
	use "Patient_Info\patient_info", clear
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
	
	drop age_in_2016
	drop age_grp
	
	foreach year of numlist 2013/2017 {
		* Working out age of cohort
		gen age_in_`year' = `year' - yob - 1800
		egen age_grp`year' = cut(age_in_`year'), at(0 50 60 70 80 90 150) icodes label
		
		* Count person-years at risk for each year 2013/14-2017/18
		local next_year = `year' + 1
		
		gen patient_pyar`year' = 1 
		replace patient_pyar`year' = (patient_pyar_end - date("01/06/`year'", "DMY")) / 365.24 if patient_pyar_start < date("01/06/`year'", "DMY") & patient_pyar_end <= date("31/05/`next_year'", "DMY")
		replace patient_pyar`year' = (date("31/05/`next_year'", "DMY") - patient_pyar_start) / 365.24 if patient_pyar_start >= date("01/06/`year'", "DMY") & patient_pyar_end > date("31/05/`next_year'", "DMY")
		replace patient_pyar`year' = (patient_pyar_end - patient_pyar_start) / 365.24 if patient_pyar_start >= date("01/06/`year'", "DMY") & patient_pyar_end <= date("31/05/`next_year'", "DMY")
		replace patient_pyar`year' = 0 if patient_pyar_end < date("01/06/`year'", "DMY") | patient_pyar_start > date("31/05/`next_year'", "DMY")
	}

	rename patient_pyar patient_pyar_all
	reshape long age_grp patient_pyar, i(patid gender) j(year)

	collapse (sum) pyar=patient_pyar, by(year gender age_grp)

	expand `num_tests'
	bysort year gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile year_denom`cohort'
	save `year_denom`cohort'', replace

	***************

	*** Yearly Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end
	
	* Year of test
	gen year = 2013
	replace year = 2014 if event_date >= date("01/06/2014", "DMY") & event_date <= date("31/05/2015", "DMY") 
	replace year = 2015 if event_date >= date("01/06/2015", "DMY") & event_date <= date("31/05/2016", "DMY") 
	replace year = 2016 if event_date >= date("01/06/2016", "DMY") & event_date <= date("31/05/2017", "DMY") 
	replace year = 2017 if event_date >= date("01/06/2017", "DMY") & event_date <= date("31/05/2018", "DMY") 
	
	rename age_grp age_grp_2016
	
	gen age = year - yob - 1800
	egen age_grp = cut(age), at(0 50 60 70 80 90 150) icodes label
	
	collapse (count) freq=patid, by(year gender age_grp test_code)
	merge m:1 year gender age_grp test_code using `year_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(year test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep year test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile year_asr`cohort'
	save `year_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `year_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl

order cohort_num year test_code crude_rate asr
save "Standardisation\year.dta", replace


***************************

*** YEAR SINCE DIAGNOSIS ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Year Denominators ***
	use "Patient_Info\patient_info", clear
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
	
	gen index_date_plus_one = index_date + 365
	
	gen patient_pyar_firstyear = 0
	replace patient_pyar_firstyear = 1 if index_date >= patient_pyar_start & index_date_plus_one <= patient_pyar_end
	replace patient_pyar_firstyear = patient_pyar if patient_pyar_start >= index_date & patient_pyar_end <= index_date_plus_one
	
	replace patient_pyar_firstyear = (patient_pyar_end - index_date) / 365.24 if patient_pyar_start < index_date & patient_pyar_end >= index_date & patient_pyar_end < index_date_plus_one
	replace patient_pyar_firstyear = min((index_date_plus_one - patient_pyar_start) / 365.24, 1) if patient_pyar_end > index_date_plus_one & patient_pyar_start <= index_date_plus_one
	
	
	gen patient_pyar_other_years = 0
	replace patient_pyar_other_years = patient_pyar if index_date_plus_one < date("01/06/2013", "DMY")
	replace patient_pyar_other_years = (patient_pyar_end - index_date_plus_one) / 365.24 if index_date_plus_one >= patient_pyar_start & index_date_plus_one <= patient_pyar_end
	
	rename patient_pyar_firstyear patient_pyar0
	rename patient_pyar_other_years patient_pyar1

	rename patient_pyar patient_pyar_all
	reshape long patient_pyar, i(patid gender age_grp) j(cond_length)

	collapse (sum) pyar=patient_pyar, by(cond_length gender age_grp)

	expand `num_tests'
	bysort cond_length gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile cond_denom`cohort'
	save `cond_denom`cohort'', replace

	***************

	*** Years since diagnosis Tests ***
	use "Standardisation\test_info.dta", clear
	

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
	
	gen index_date_plus_one = index_date + 365
	
	* Get rid of any tests before the index date
	drop if event_date < index_date
	
	gen cond_length = 0
	replace cond_length = 1 if event_date >= index_date_plus_one
	
	collapse (count) freq=patid, by(cond_length gender age_grp test_code)
	merge m:1 cond_length gender age_grp test_code using `cond_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(cond_length test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep cond_length test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile cond_asr`cohort'
	save `cond_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `cond_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl
label define cond_length_lbl 0 "< 1 year" 1 ">= 1 year"
label values cond_length cond_length_lbl

order cohort_num cond_length test_code crude_rate asr
save "Standardisation\cond_length.dta", replace

********************

*** NUMBER OF CONDITIONS ***

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Year Denominators ***
	use "Patient_Info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(num_conds gender age_grp)

	expand `num_tests'
	bysort num_conds gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile numconds_denom`cohort'
	save `numconds_denom`cohort'', replace	
	
	***************

	*** Number of Conditions Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end
	
	collapse (count) freq=patid, by(num_conds gender age_grp test_code)
	merge m:1 num_conds gender age_grp test_code using `numconds_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(num_conds test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep num_conds test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile numconds_asr`cohort'
	save `numconds_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `numconds_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl

order cohort_num num_conds test_code crude_rate asr
save "Standardisation\num_conds.dta", replace

********************

*** PRACTICE ***

* Count the number of tests we're including
use "Test_Info\common_tests", clear
count
local num_tests = `r(N)'

* Loop through the different cohorts
foreach cohort of numlist 1/7 {
*** Practice Denominators ***
	use "Patient_info\patient_info", clear
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

	collapse (sum) pyar=patient_pyar, by(pracid gender age_grp)

	expand `num_tests'
	bysort pracid gender age_grp: gen common_test_index = _n
	
	merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen

	tempfile practice_denom`cohort'
	save `practice_denom`cohort'', replace

	***************

	*** Practice Tests ***
	use "Standardisation\test_info.dta", clear
	
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
	
	drop if event_date < patient_pyar_start
	drop if event_date > patient_pyar_end
	
	collapse (count) freq=patid, by(pracid gender age_grp test_code)
	merge m:1 pracid gender age_grp test_code using `practice_denom`cohort''
	replace freq = 0 if freq == .

	gen rate = (freq / pyar) * 1000
	merge m:1 gender age_grp using "Standardisation\asr_weights.dta", keep(1 3) nogen
	gen weighted_rate = rate * weight
	collapse (sum) freq pyar asr=weighted_rate, by(pracid test_code)
	gen crude_rate = (freq / pyar) * 1000
	keep pracid test_code crude_rate asr
	
	gen cohort_num = `cohort'

	tempfile practice_asr`cohort'
	save `practice_asr`cohort'', replace
}

clear
foreach cohort of numlist 1/7 {
	append using `practice_asr`cohort''
}

label define cohort_lbl 1 "All hypertension" 2 "Only hypertension" 3 "All Diabetes" 4 "Only Diabetes" 5 "All CKD" 6 "Only CKD" 7 "Whole Cohort"
label values cohort_num cohort_lbl

order cohort_num pracid test_code crude_rate asr
save "Standardisation\practices.dta", replace

**********************

*** Make a combined table ***
local filenames region imd2015_5 eth_num gender age_grp year cond_length num_conds

foreach filename of local filenames {
	use "Standardisation/`filename'", clear
	if "`filename'" == "year" | "`filename'" == "num_conds" {
		tostring(`filename'), gen(varname)
	}
	else {
		decode `filename', gen(varname)
	}
	drop `filename'
	gen varfamily = "`filename'"
	tempfile temp_`filename'
	save `temp_`filename'', replace
}

clear
foreach filename of local filenames {
	append using `temp_`filename''
}

gen my_rate = asr
replace my_rate = crude_rate if inlist(varfamily, "gender", "age_grp")
drop crude_rate asr
reshape wide my_rate, i(cohort_num varfamily varname) j(test_code)
sort varfamily varname

order cohort_num varfamily varname my_rate73 my_rate57 my_rate30 my_rate54 my_rate43 my_rate100 my_rate36 my_rate1 my_rate14 my_rate40 my_rate15 my_rate29
sort cohort_num varfamily varname

save "Standardisation\combined_table", replace

***************

*** Do 90/10 ratio by region
use "Standardisation\region.dta", clear
merge m:1 test_code using "Test_Info\common_tests.dta", keep(1 3) nogen

postfile region_percentiles cohort common_test_index p10 p90 ratio using "Standardisation\region_percentiles", replace

foreach cohort of numlist 1/7 {
    foreach test of numlist 1/12 {
	    summ asr if cohort_num == `cohort' & common_test_index == `test', detail
		local p10 = `r(p10)'
		local p90 = `r(p90)'
		local ratio = `p90' / `p10'
		post region_percentiles (`cohort') (`test') (`p10') (`p90') (`ratio')
	}
}

postclose region_percentiles

use "Standardisation\region_percentiles", clear
merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen
gsort cohort -overall_test_rate

***************

*** Do 90/10 ratio by practice
use "Standardisation\practices.dta", clear
merge m:1 test_code using "Test_Info\common_tests.dta", keep(1 3) nogen

postfile practice_percentiles cohort common_test_index p10 p90 ratio using "Standardisation\practice_percentiles", replace

foreach cohort of numlist 1/7 {
    foreach test of numlist 1/12 {
	    summ asr if cohort_num == `cohort' & common_test_index == `test', detail
		local p10 = `r(p10)'
		local p90 = `r(p90)'
		local ratio = `p90' / `p10'
		post practice_percentiles (`cohort') (`test') (`p10') (`p90') (`ratio')
	}
}

postclose practice_percentiles

use "Standardisation\practice_percentiles", clear
merge m:1 common_test_index using "Test_Info\common_tests", keep(3) nogen
gsort cohort -overall_test_rate
