*** 18_188 Optimal Care - Tim J - Test info ***
cd "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\Tim_June2021"
set more off

*** OLD VERSION FROM RITA's WORK
use "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data Analysis\Programs\02 Select Tests\Entity_select_lab_tests_Master_Final_Lookup.dta", clear
drop if strpos(final_decision, "Exclude") // Get rid of the test panels where there was consensus to exclude: infection titres, other biochemistry tests, Schilling test - b12 absorption, serum bicarbonate, uric acid blood level
keep enttype description category description2
replace description2 = "Drug levels" if description == "Drug levels" // Jess and Katharine recommend this is not part of Urine Biochemistry and to rename to ACR / Microalbumin
replace description2 = "ACR / Microalbumin" if description2 == "Urine Biochemistry"
encode description2, gen(test_code)
save "Test_Info\test_lookup_old.dta", replace

*** Identify which tests to explore using the CPRD entity file ***
import excel "Z:\Lookups\Gold\2018_12\entity.xls", sheet("entity") firstrow clear  // 501
keep enttype description filetype category

drop if filetype == "Clinical"  // 177 dropped, 324 remain
drop filetype
drop if inlist(category, "Asthma", "Diagnostic Imaging", "Diagnostic Tests", "Examination Findings", "Maternity", "Microbiology", "Miscellaneous", "Other Pathology Tests")  // 125 dropped, 199 remain

* Drop the ones that say "Other..." as miscellaneous
drop if strpos(description, "Other")  // 4 dropped, 195 remain

merge 1:1 enttype using "Test_Info\test_lookup_old.dta", keep(1 3) nogen keepusing(description2)
replace description2 = description if description2 == ""
encode description2, gen(test_code)
save "Test_Info\test_lookup.dta", replace

******************

* Loop through all of the test files to minimise based on tests used and study dates
local files : dir "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Data_Extract_Dec2018\" files "*Test*.txt", respectcase
local filenum = 0
foreach file in `files' {
	di "`file'"
	local filenum = `filenum' + 1
	import delimited "\\ads.bris.ac.uk\filestore\HealthSci SafeHaven\CPRD Projects UOB\Projects\18_188\Data\Data_Extract_Dec2018\\`file'", clear
	gen event_date = date(eventdate, "DMY")
	format %d event_date
	keep patid event_date enttype 

	drop if event_date < date("01/06/2013", "DMY")
	drop if event_date > date("31/05/2018", "DMY")

	merge m:1 enttype using "Test_Info\test_lookup.dta", keep(3) nogen  // Only keep the tests in our lookup table

	bysort patid event_date description2: gen index = _n
	keep if index == 1  // This drops a lot of tests - not sure if that's something to explore? Basically counting batteries of tests on same day as 1
	save "Test_Info\file_`filenum'.dta", replace
}

clear
foreach filenum of numlist 1/71 {
	append using "Test_Info\file_`filenum'.dta"
}
drop index
save "Test_Info\combined_tests.dta", replace