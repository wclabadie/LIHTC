********************************************************************************
* Stata/SE 14.2
* Author: Will Labadie
*
* 1. Collapses HUD data into # of LIHTC projects per county-year pair
* 2. Merges political data with LIHTC count data at county-year level
* 3. Displays relationship b/w # of projects 
********************************************************************************

clear
cd "/users/will/Dropbox/LIHTC/"
cap log close
log using "./Code/Logs/count-support.log", replace

use "./Data/LIHTC", clear
collapse (count) count=hud, by(state county year)
save "./Data/countbycnty-yr", replace

use "./Data/countbycnty-yr", clear
merge 1:1 state county year using "./Data/fullpolitical"						// Lots of unmatched. Mostly from using. Don't like that. Will have to look at why.


