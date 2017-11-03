********************************************************************************
* Stata/SE 14.2
* Author: Will Labadie
*
* 1. Imports Census data relating 2015 FIPS codes to county names
* 2. Merges county names w/ LIHTC HUD data based on 2015 FIPS codes
* 3. Cleans HUD data 
* 4. Builds gubernatorial election data, specified at county-election year level
* 5. Fills in off-election years
* 6. Merges with state-year governor party data
********************************************************************************

clear
cd "/users/will/Dropbox/LIHTC/"
cap log close
log using ".//LIHTC_git/Code/county-year.log", replace

* Set gloabl variable defining the range of years to use (for CQ data)
global years "1987" "1988" "1989" "1990" "1991" "1992" "1993" "1994" "1995" "1996" "1997" "1998" "1999" "2000" "2001" "2002" "2003" "2004" "2005" "2006" "2007" "2008" "2009" "2010" "2011" "2012" "2013" "2014" "2015"
* Prep FIPS-county data
import delimited "./Raw/2010fips", clear
drop code
save "./Data/fips-county", replace

* Prep HUD data (uses FIPS codes not counties)
import delimited "./Data/LIHTCPUB.csv", clear
merge m:1 st2010 cnty2010 using "./Data/fips-county" 							// 1.8 percent of obs not matched
* About half unmatched from master (no fips codes), half from using 
* (no LIHTC projects in those counties).
drop if _merge == 1 | _merge == 2
drop _merge
rename yr_alloc year
encode hud_id, gen(hud)
drop if year == 1984 | year == 8888 | year == 9999 // Can't find what these encodings mean yet, dropping for now (894 obs)
replace county = subinstr(county," County","",.)
replace county = subinstr(county," Municipality","",.)
replace county = subinstr(county," Borough","",.)
replace county = subinstr(county," Parish","",.)
replace county = subinstr(county," Municipio","",.)
save "./Data/LIHTC", replace


* Can now use the CQ data, which is only specified at the county level
import delimited "./Raw/CQ_gub_county/2016", varnames(5) clear
keep state county winningparty dem rep
gen year = 2016
save "./Data/CQ/2016", replace
save "./Data/CQ/full", replace

* A program to clean each year's county-level gubernatorial election data
capture program drop buildeach_CQ
program buildeach_CQ
	syntax [, filename(string) maxrow(string)]
	foreach thing in `filename' {
		import delimited "./Raw/CQ_gub_county/`thing'", varnames(5) clear
		keep state county winningparty dem rep
		gen year = `thing'
		save "./Data/CQ/`thing'", replace
	}
end
buildeach_CQ, filename("$years")

* A program to combine all years' county-level gub data
capture program drop buildbig_CQ
program buildbig_CQ
	syntax[, filename(string)]
	use "./Data/CQ/full", clear
	foreach year in `filename' {
		append using "./Data/CQ/`year'"
	}
end
buildbig_CQ, filename("$years")
drop if dem == . 																// drops rows full of citing info
recast str2 state
replace county = proper(county)

* Fill in off-election years
global each4_1986 "AK" "AL" "AR" "AZ" "CA" "CO" "CT" "FL" "GA" "HI" "IA" "ID" "IL" "KS" "MA" "MD" "ME" "MI" "MN" "NE" "NM" "NV" "NY" "OH" "OK" "PA" "SC" "SD" "TN" "TX" "WY"
global each4_1984 "IN" "MO" "MT" "NC" "ND" "WA" 
global each4_1987 "KY" "LA" "MS"
global each4_1985 "NJ" "VA"
global each2_1986 "NH" "VT"
* Special rules: OR RI UT WI WV

foreach state in "$each4_1986" {
	expand 2 if state == "`state'", generate(one) 								// copies each row for election years in states that hold elections every 4 years, starting in 1986
	replace year = year+1 if one == 1 											// replaces year with next year in the copied row, i.e. if original year in data was 1990, the copied row's year will be 1991
	expand 2 if one == 1, generate(two) 										// etc
	replace year = year+1 if two == 1
	expand 2 if two == 1, generate(three)
	replace year = year+1 if three == 1
	drop one two three
}
foreach state in "$each4_1984" {
	expand 2 if state == "`state'", generate(one) 								// copies each row for election years in states that hold elections every 4 years, starting in 1984
	replace year = year+1 if one == 1 											// replaces year with next year in the copied row, i.e. if original year in data was 1990, the copied row's year will be 1991
	expand 2 if one == 1 & year != 2017, generate(two) 							// Don't want to copy 2017 data to non-existent 2018
	replace year = year+1 if two == 1
	expand 2 if two == 1, generate(three)
	replace year = year+1 if three == 1
	drop one two three
}
foreach state in "$each4_1987" {
	expand 2 if state == "`state'", generate(one) 								// copies each row for election years in states that hold elections every 4 years, starting in 1987
	replace year = year+1 if one == 1 											// replaces year with next year in the copied row, i.e. if original year in data was 1990, the copied row's year will be 1991
	expand 2 if one == 1, generate(two) 										// etc
	replace year = year+1 if two == 1
	expand 2 if two == 1 & year != 2017, generate(three)						// Don't want to copy 2017 data to non-existent 2018 
	replace year = year+1 if three == 1
	drop one two three
}
foreach state in "$each4_1985" {
	expand 2 if state == "`state'", generate(one) 								// copies each row for election years in states that hold elections every 4 years, starting in 1985
	replace year = year+1 if one == 1 											// replaces year with next year in the copied row, i.e. if original year in data was 1990, the copied row's year will be 1991
	expand 2 if one == 1, generate(two) 										// etc
	replace year = year+1 if two == 1
	expand 2 if two == 1, generate(three)
	replace year = year+1 if three == 1
	drop one two three
}
foreach state in "$each2_1986" {
	expand 2 if state == "`state'", generate(one) 								// copies each row for election years in states that hold elections every 2 years, starting in 1986
	replace year = year+1 if one == 1 											// replaces year with next year in the copied row, i.e. if original year in data was 1990, the copied row's year will be 1991
	drop one
}

expand 2 if state == "OR", generate(one)										// OR had elections every 4 years starting 1986 but special election in 2016.
replace year = year+1 if one == 1
expand 2 if one == 1 & year != 2017 & year != 2015, generate(two)				// Don't want to copy 2017 data to non-existent 2018. Don't want to copy 2015 data to election year 2016.
replace year = year+1 if two == 1
expand 2 if two == 1, generate (three)
replace year = year+1 if three == 1
drop one two three

expand 2 if state == "RI", generate(one)										// RI had elections every 4 years starting in 1994 and had elections every 2 years before that
replace year = year+1 if one == 1												
expand 2 if one == 1 & year >= 1995, generate(two)								// copies election data to the next year only for post-election years after 1995, when 4-year elections started
replace year = year+1 if two == 1
expand 2 if two == 1, generate(three)											// this will be the year before the next election
replace year = year+1 if three == 1 
drop one two three

expand 2 if state == "UT", generate(one)										// UT has elections every 4 years but had a special election in 2010
replace year = year+1 if one == 1 
expand 2 if one == 1 & year != 2009 & year != 2011 & year != 2017, generate(two) // 2008 & 2010 were basically two-year terms - don't want to copy post-election year (2009 & 2011) data to next year (2010 and 2012) which were elections. Note there isn't actually any data for the 2010 special election.
replace year = year+1 if two == 1
expand 2 if two == 1, generate(three)
replace year = year+1 if three == 1
drop one two three

expand 2 if state == "WI", generate(one)										// WI has elections every 4 years but had a special election in 2012. Note no data on 2012 special election.
replace year = year+1 if one == 1
expand 2 if one == 1 & year != 2011 & year != 2013, generate(two)				// Don't want to copy 2011 and 2013 data to 2012 and 2014, which were election years
replace year = year+1 if two == 1
expand 2 if two == 1, generate(three)
replace year = year+1 if three == 1
drop one two three

expand 2 if state == "WV" & year != 2011, generate(one)							// WV has elections every 4 years but had a special election in 2011. Don't want to copy 2011 data to 2012 which was an election year. Note no data on 2011 special election.
replace year = year+1 if one == 1 
expand 2 if one == 1 & year != 2017, generate(two)								// Don't want to copy 2017 data to 2018 because that hasn't happened yet
replace year = year+1 if two == 1
expand 2 if two ==1 & year != 2010, generate(three)								// Don't want to copy 2010 data to 2011 which was a special election year
replace year = year+1 if three == 1
drop one two three

save "./Data/CQ/filled", replace

* fake change
