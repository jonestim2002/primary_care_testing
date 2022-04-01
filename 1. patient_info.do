*** 18_188 Optimal Care - Tim J - Patient Information ***
cd "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\Tim_June2021\Patient_Info"

local outlier_rate 52
local followup_threshold = 1
local remove_outliers yes

*** Save the linked data as Stata files to be merged ***

* ONS deaths
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Linkages\GOLD_linked\death_patient_18_188R_Request2_DM.txt", encoding(ISO-8859-2) clear 
gen ons_dod = date(dod, "DMY")
format %d ons_dod
drop dod
drop if ons_dod == .
save "ons_deaths.dta", replace

* IMD (deprivation)
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Linkages\GOLD_linked\patient_imd2015_18_188R_Request2.txt", clear 
keep patid imd2015_5
save "patient_imd", replace

* HES ethnicity
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Linkages\GOLD_linked\hes_patient_18_188R_Request2_DM.txt", clear 
keep patid gen_ethnicity
save "patient_ethnicity", replace

* Pregnancy Register
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Linkages\GOLD_linked\pregnancy_register_2018_07.txt", clear 
gen preg_start = date(pregstart, "DMY")
gen preg_end = date(pregend, "DMY")
format %d preg_start preg_end
keep patid preg_start preg_end

* Check if there has been a pregnancy during the study period 
gen preg_during_study = 0
replace preg_during_study = 1 if preg_end > date("01/06/2013", "DMY")
collapse (max) preg_during_study, by(patid)
save "pregnancy_register", replace

****************

*** Save the practice information as a Stata file to be merged ***
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Data_Extract_Dec2018\18_188_all_dec2018_Extract_Practice_001.txt", clear 
gen lcd_date = date(lcd, "DMY")
gen uts_date = date(uts, "DMY")
format %d lcd_date uts_date
drop lcd uts
save "practices.dta", replace

*****************

*** Get the main patient file and merge in the other information ***
import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Data_Extract_Dec2018\18_188_all_dec2018_Extract_Patient_001.txt", clear  // 1,206,118 people

gen frd_date = date(frd, "DMY")
gen crd_date = date(crd, "DMY")
gen tod_date = date(tod, "DMY")
gen cprd_death_date = date(deathdate, "DMY")
format %d frd_date crd_date tod_date cprd_death_date
keep patid gender yob mob frd_date crd_date tod_date cprd_death_date

merge 1:1 patid using "ons_deaths.dta", keep(1 3) nogen
merge 1:1 patid using "patient_imd.dta", keep(1 3) nogen
merge 1:1 patid using "patient_ethnicity.dta", keep(1 3) nogen
merge 1:1 patid using "pregnancy_register.dta", keep(1 3) nogen
merge 1:1 patid using "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Data_Extract_Dec2018\pat_index_dates.dta", keep(1 3) nogen

gen pracid = real(substr(string(patid, "%20.0g"), -3, .))
merge m:1 pracid using "practices.dta", keep(1 3) nogen

* Drop if they have a pregnancy ending after the study start date (01/06/2013)
drop if preg_during_study == 1
drop preg_during_study  // (7,507 observations deleted)
count // 1,198,611

* mob is always 0 for these patients so drop it
drop mob

* Create dates for their earliest diagnosis of hypertension, diabetes, and CKD
gen hyp_index_date = date(hyp_indexdate, "DMY")
gen dm_index_date = date(dm_indexdate, "DMY")
gen ckd_index_date = date(ckd3_indexdate, "DMY")
format %d hyp_index_date dm_index_date ckd_index_date
drop hyp_indexdate dm_indexdate ckd3_indexdate

gen hyp_flag = cond(hyp_index_date ~= ., 1, 0)
gen dm_flag = cond(dm_index_date ~= ., 1, 0)
gen ckd_flag = cond(ckd_index_date ~= ., 1, 0)

gen hyp_only = 0
replace hyp_only = 1 if hyp_flag == 1 & dm_flag == 0 & ckd_flag == 0
gen dm_only = 0
replace dm_only = 1 if dm_flag == 1 & hyp_flag == 0 & ckd_flag == 0
gen ckd_only = 0
replace ckd_only = 1 if ckd_flag == 1 & hyp_flag == 0 & dm_flag == 0

gen num_conds = hyp_flag + dm_flag + ckd_flag

tab num_conds
/*
  num_conds |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |    821,551       68.54       68.54
          2 |    314,735       26.26       94.80
          3 |     62,325        5.20      100.00
------------+-----------------------------------
      Total |  1,198,611      100.00
*/


* Sort out death dates - preferentially use the ONS death date if there is ONS and CPRD death dates
gen overall_death_date = ons_dod
replace overall_death_date = cprd_death_date if overall_death_date == .


* Do some checks on the active registration
egen patient_latest = rowmin(tod_date lcd_date overall_death_date)
egen patient_earliest = rowmax(crd_date uts_date)

* Drop if their earliest date is after the end of the study time (31/05/2018)
drop if patient_earliest > date("31/05/2018", "DMY")  // (8,957 observations deleted)
drop if patient_latest < date("01/06/2013", "DMY") // (220 observations deleted)
count  // 1,189,434

* Drop if they're under 18 in 2013 as this is only a small number
drop if (yob + 1800) > 1995  // (774 observations deleted)
count // 1,188,660

* Drop if their latest date is before their earliest date
drop if patient_latest < patient_earliest // (4,112 observations deleted)
count // 1,184,549

gen study_start = date("01/06/2013", "DMY")
gen study_end = date("31/05/2018", "DMY")

egen index_date = rowmin(hyp_index_date dm_index_date ckd_index_date)

egen patient_pyar_start = rowmax(patient_earliest study_start index_date)
egen patient_pyar_end = rowmin(patient_latest study_end)

drop if patient_pyar_start > patient_pyar_end  // (7,713 observations deleted)

gen patient_pyar = (patient_pyar_end - patient_pyar_start) / 365.24

* Give them 1 day of follow-up if they left on the same day they started
replace patient_pyar = 1/365.24 if patient_pyar == 0

* Go for one of the middle years for working out age of cohort
gen age_in_2016 = 2016 - yob - 1800
egen age_grp = cut(age_in_2016), at(0 50 60 70 80 90 150) icodes label

* Ethnicity - 0 is missing/unknown, 1 is white, 2 is black, 3 is asian, 4 is other
gen eth_num = 1 // White
replace eth_num = 0 if gen_ethnicity == "" | gen_ethnicity == "Unknown"
replace eth_num = 2 if inlist(gen_ethnicity, "Bl_Afric", "Bl_Carib", "Bl_Other")
replace eth_num = 3 if inlist(gen_ethnicity, "Indian", "Bangladesi", "Pakistani", "Oth_Asian")
replace eth_num = 4 if inlist(gen_ethnicity, "Other", "Mixed", "Chinese")
label define eth_num_lbl 0 "Missing or Unknown" 1 "White" 2 "Black" 3 "Asian" 4 "Other"
label values eth_num eth_num_lbl

save "patient_info_all", replace  // 1,176,836 people

********************************

*** Identify outlier patients *** 
use "patient_info_all.dta", clear

merge 1:m patid using "../Test_Info/combined_tests.dta", keep(1 3) nogen
/*
 Result                           # of obs.
    -----------------------------------------
    not matched                       122,169
        from master                   122,169  
        from using                          0  

    matched                        36,410,136  
    -----------------------------------------
*/

* Get rid of tests outside of the patient's time-at-risk
drop if event_date < patient_pyar_start // (2,850,286 observations deleted)
drop if event_date > patient_pyar_end // (141,671 observations deleted)

collapse (count) freq=enttype (firstnm) patient_pyar, by(patid)

merge m:1 patid using "../Patient_Info/patient_info_all.dta", nogen keepusing(patient_pyar)
replace freq = 0 if freq == . // (158,996 real changes made)

* People need to contribute at least 1 year of follow-up
*count if patient_pyar < 1/12  // (25,134 observations deleted) 2.14% of total
count if patient_pyar < `followup_threshold'  // 235,489, 20.01% of total
gen little_followup = 0
replace little_followup = 1 if patient_pyar < `followup_threshold'

gen test_rate = freq / patient_pyar

count if test_rate > `outlier_rate' // Rate > 100 1,912, 0.16% of population; Rate > 52 13,473, 1.14% of population

gen outlier_rate = 0
replace outlier_rate = 1 if test_rate > `outlier_rate'
keep if little_followup | outlier_rate
keep patid little_followup outlier_rate
save "outlier_patients", replace	

******************

* Remove outliers
if "`remove_outliers'" == "yes" {
	use "patient_info_all", clear
	merge 1:1 patid using "outlier_patients", keep(1) nogen
	save "patient_info", replace // 933,907
}

********************

*** Produce a table of patient demographics ***
use "patient_info", clear

postfile patient_info str25 varname allhyp_value allhyp_pct onlyhyp_value onlyhyp_pct alldiab_value alldiab_pct onlydiab_value onlydiab_pct allckd_value allckd_pct onlyckd_value onlyckd_pct using "patient_demographics.dta", replace

local cohort_list hyp_flag hyp_only dm_flag dm_only ckd_flag ckd_only

count
local all_count = `r(N)'

* Counts of people in each cohort
foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1
	local `cohort'_total = `r(N)'
	local `cohort'_total_pct = (``cohort'_total' / `all_count') * 100
}

post patient_info ("N") (`hyp_flag_total') (`hyp_flag_total_pct') (`hyp_only_total') (`hyp_only_total_pct') (`dm_flag_total') (`dm_flag_total_pct') (`dm_only_total') (`dm_only_total_pct') (`ckd_flag_total') (`ckd_flag_total_pct') (`ckd_only_total') (`ckd_only_total_pct')

* Amount of follow-up (with SD) - fairly normally distributed
foreach cohort of varlist `cohort_list' {
	summ patient_pyar if `cohort' == 1
	local `cohort'_pyarmean = `r(mean)'
	local `cohort'_pyarsd = `r(sd)'
}

post patient_info ("Average follow-up (sd)") (`hyp_flag_pyarmean') (`hyp_flag_pyarsd') (`hyp_only_pyarmean') (`hyp_only_pyarsd') (`dm_flag_pyarmean') (`dm_flag_pyarsd') (`dm_only_pyarmean') (`dm_only_pyarsd') (`ckd_flag_pyarmean') (`ckd_flag_pyarsd') (`ckd_only_pyarmean') (`ckd_only_pyarsd')


* Sex (% women)
foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & gender == 2
	local `cohort'_women = `r(N)'
	local `cohort'_women_pct = (``cohort'_women' / ``cohort'_total') * 100
}

post patient_info ("Women (%)") (`hyp_flag_women') (`hyp_flag_women_pct') (`hyp_only_women') (`hyp_only_women_pct') (`dm_flag_women') (`dm_flag_women_pct') (`dm_only_women') (`dm_only_women_pct') (`ckd_flag_women') (`ckd_flag_women_pct') (`ckd_only_women') (`ckd_only_women_pct')

* Age groups
foreach agegrp of numlist 0/5 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & age_grp == `agegrp'
		local `cohort'_`agegrp' = `r(N)'
		local `cohort'_`agegrp'_pct = (``cohort'_`agegrp'' / ``cohort'_total') * 100
	}
	
	post patient_info ("Age Group `agegrp'") (`hyp_flag_`agegrp'') (`hyp_flag_`agegrp'_pct') (`hyp_only_`agegrp'') (`hyp_only_`agegrp'_pct') (`dm_flag_`agegrp'') (`dm_flag_`agegrp'_pct') (`dm_only_`agegrp'') (`dm_only_`agegrp'_pct') (`ckd_flag_`agegrp'') (`ckd_flag_`agegrp'_pct') (`ckd_only_`agegrp'') (`ckd_only_`agegrp'_pct')
}


label define region_lbl 1 "North East" 2 "North West" 3 "Yorkshire & The Humber" 4 "East Midlands" 5 "West Midlands" 6 "East of England" 7 "South West" 8 "South Central" 9 "London" 10 "South East Coast" 11 "Northern Ireland" 12 "Scotland" 13 "Wales"
label values region region_lbl

* Region (%)
foreach region of numlist 1/13 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & region == `region'
		local `cohort'_`region' = `r(N)'
		local `cohort'_`region'_pct = (``cohort'_`region'' / ``cohort'_total') * 100
	}
	
	post patient_info ("Region `region'") (`hyp_flag_`region'') (`hyp_flag_`region'_pct') (`hyp_only_`region'') (`hyp_only_`region'_pct') (`dm_flag_`region'') (`dm_flag_`region'_pct') (`dm_only_`region'') (`dm_only_`region'_pct') (`ckd_flag_`region'') (`ckd_flag_`region'_pct') (`ckd_only_`region'') (`ckd_only_`region'_pct')
}

* Deprivation - there will be a lot of missing due to lack of linkage eligibility
foreach imd of numlist 1/5 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & imd2015_5 ~= .
		local `cohort'_imd_nonmissing = `r(N)'		
		
		count if `cohort' == 1 & imd2015_5 == `imd'
		local `cohort'_`imd' = `r(N)'
		local `cohort'_`imd'_pct = (``cohort'_`imd'' / ``cohort'_imd_nonmissing') * 100
	}
	
	post patient_info ("IMD Quintile `imd'") (`hyp_flag_`imd'') (`hyp_flag_`imd'_pct') (`hyp_only_`imd'') (`hyp_only_`imd'_pct') (`dm_flag_`imd'') (`dm_flag_`imd'_pct') (`dm_only_`imd'') (`dm_only_`imd'_pct') (`ckd_flag_`imd'') (`ckd_flag_`imd'_pct') (`ckd_only_`imd'') (`ckd_only_`imd'_pct')
}

foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & imd2015_5 == .
	local `cohort'_missing = `r(N)'
	local `cohort'_missing_pct = (``cohort'_missing' / ``cohort'_total') * 100	
}

post patient_info ("IMD % Missing") (`hyp_flag_missing') (`hyp_flag_missing_pct') (`hyp_only_missing') (`hyp_only_missing_pct') (`dm_flag_missing') (`dm_flag_missing_pct') (`dm_only_missing') (`dm_only_missing_pct') (`ckd_flag_missing') (`ckd_flag_missing_pct') (`ckd_only_missing') (`ckd_only_missing_pct')

* Ethnicity - there will a lot of missing due to lack of linkage eligibility and some missing even when eligible
foreach eth of numlist 1/4 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & eth_num ~= 0
		local `cohort'_eth_nonmissing = `r(N)'		
		
		count if `cohort' == 1 & eth_num == `eth'
		local `cohort'_`eth' = `r(N)'
		local `cohort'_`eth'_pct = (``cohort'_`eth'' / ``cohort'_eth_nonmissing') * 100
	}
	
	post patient_info ("Ethnicity `eth'") (`hyp_flag_`eth'') (`hyp_flag_`eth'_pct') (`hyp_only_`eth'') (`hyp_only_`eth'_pct') (`dm_flag_`eth'') (`dm_flag_`eth'_pct') (`dm_only_`eth'') (`dm_only_`eth'_pct') (`ckd_flag_`eth'') (`ckd_flag_`eth'_pct') (`ckd_only_`eth'') (`ckd_only_`eth'_pct')
}

foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & eth_num == 0
	local `cohort'_missing = `r(N)'
	local `cohort'_missing_pct = (``cohort'_missing' / ``cohort'_total') * 100	
}

post patient_info ("Ethnicity % Missing") (`hyp_flag_missing') (`hyp_flag_missing_pct') (`hyp_only_missing') (`hyp_only_missing_pct') (`dm_flag_missing') (`dm_flag_missing_pct') (`dm_only_missing') (`dm_only_missing_pct') (`ckd_flag_missing') (`ckd_flag_missing_pct') (`ckd_only_missing') (`ckd_only_missing_pct')

postclose patient_info

***********************

*** Compare included patients to those excluded for various reasons ***
use "patient_info_all", clear
merge 1:1 patid using "outlier_patients", keep(1 3) nogen
replace little_followup = 0 if little_followup == .
replace outlier_rate = 0 if outlier_rate == .
gen included = 0
replace included = 1 if little_followup == 0 & outlier_rate == 0

postfile patient_info str20 varname included_value included_pct follow_value follow_pct outlier_value outlier_pct using "excluded_demographics.dta", replace

local cohort_list included little_followup outlier_rate

count
local all_count = `r(N)'

foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1
	local `cohort'_total = `r(N)'
	local `cohort'_total_pct = (``cohort'_total' / `all_count') * 100
}

post patient_info ("N") (`included_total') (`included_total_pct') (`little_followup_total') (`little_followup_total_pct') (`outlier_rate_total') (`outlier_rate_total_pct')

* Sex (% women)
foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & gender == 2
	local `cohort'_women = `r(N)'
	local `cohort'_women_pct = (``cohort'_women' / ``cohort'_total') * 100
}

post patient_info ("Women (%)") (`included_women') (`included_women_pct') (`little_followup_women') (`little_followup_women_pct') (`outlier_rate_women') (`outlier_rate_women_pct')

* Average Age (SD)
foreach cohort of varlist `cohort_list' {
	summ age_in_2016 if `cohort' == 1 
	local `cohort'_age = `r(mean)'
	local `cohort'_age_sd = `r(sd)'
}

post patient_info ("Average age (SD)") (`included_age') (`included_age_sd') (`little_followup_age') (`little_followup_age_sd') (`outlier_rate_age') (`outlier_rate_age_sd') 

label define region_lbl 1 "North East" 2 "North West" 3 "Yorkshire & The Humber" 4 "East Midlands" 5 "West Midlands" 6 "East of England" 7 "South West" 8 "South Central" 9 "London" 10 "South East Coast" 11 "Northern Ireland" 12 "Scotland" 13 "Wales"
label values region region_lbl

* Region (%)
foreach region of numlist 1/13 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & region == `region'
		local `cohort'_`region' = `r(N)'
		local `cohort'_`region'_pct = (``cohort'_`region'' / ``cohort'_total') * 100
	}
	
	post patient_info ("Region `region'") (`included_`region'') (`included_`region'_pct') (`little_followup_`region'') (`little_followup_`region'_pct') (`outlier_rate_`region'') (`outlier_rate_`region'_pct') 
}

* Deprivation - there will be a lot of missing due to lack of linkage eligibility
foreach imd of numlist 1/5 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & imd2015_5 ~= .
		local `cohort'_imd_nonmissing = `r(N)'		
		
		count if `cohort' == 1 & imd2015_5 == `imd'
		local `cohort'_`imd' = `r(N)'
		local `cohort'_`imd'_pct = (``cohort'_`imd'' / ``cohort'_imd_nonmissing') * 100
	}
	
	post patient_info ("IMD Quintile `imd'") (`included_`imd'') (`included_`imd'_pct') (`little_followup_`imd'') (`little_followup_`imd'_pct') (`outlier_rate_`imd'') (`outlier_rate_`imd'_pct') 
}

foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & imd2015_5 == .
	local `cohort'_missing = `r(N)'
	local `cohort'_missing_pct = (``cohort'_missing' / ``cohort'_total') * 100	
}

post patient_info ("IMD % Missing") (`included_missing') (`included_missing_pct') (`little_followup_missing') (`little_followup_missing_pct') (`outlier_rate_missing') (`outlier_rate_missing_pct') 

* Ethnicity - there will a lot of missing due to lack of linkage eligibility and some missing even when eligible
foreach eth of numlist 1/4 {
	foreach cohort of varlist `cohort_list' {
		count if `cohort' == 1 & eth_num ~= 0
		local `cohort'_eth_nonmissing = `r(N)'		
		
		count if `cohort' == 1 & eth_num == `eth'
		local `cohort'_`eth' = `r(N)'
		local `cohort'_`eth'_pct = (``cohort'_`eth'' / ``cohort'_eth_nonmissing') * 100
	}
	
	post patient_info ("Ethnicity `eth'") (`included_`eth'') (`included_`eth'_pct') (`little_followup_`eth'') (`little_followup_`eth'_pct') (`outlier_rate_`eth'') (`outlier_rate_`eth'_pct') 
}

foreach cohort of varlist `cohort_list' {
	count if `cohort' == 1 & eth_num == 0
	local `cohort'_missing = `r(N)'
	local `cohort'_missing_pct = (``cohort'_missing' / ``cohort'_total') * 100	
}

post patient_info ("Ethnicity % Missing") (`included_missing') (`included_missing_pct') (`little_followup_missing') (`little_followup_missing_pct') (`outlier_rate_missing') (`outlier_rate_missing_pct') 

postclose patient_info




