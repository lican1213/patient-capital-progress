*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar74_dist_gdpweight.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十四轮：附表6（2）距离改为省内按 GDP 加权）
* Purpose:  规则见本 exploration README 第三十四轮（运行前写定）。只把距离的省内平均由等权改为
*           按目的城市 2014 年 GDP 加权，其余同 ar68 附表6（2）。
* Inputs:   deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/advisor_send_20261008/距离对数_省内GDP加权.dta（ar74_build_gdpdist_prov.py）
* Outputs:  本 exploration 的 output/tables/ar74_dist_gdpweight.csv
* Log:      explorations/advisor_revision_20261005/logs/ar74_dist_gdpweight.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar74
log using "`EXP'/logs/ar74_dist_gdpweight.log", name(ar74) replace text
which reghdfe

use "data/derived/advisor_send_20261008/距离对数_省内GDP加权.dta", clear
tempfile gd
save `gd'

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd year dest using `gd', keep(master match)
assert _merge == 3
drop _merge
keep if year >= 2015
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
correlate lndist lndist_gdp lndist_gdp_f Seg0_z

tempfile res
postfile R str2 col str10 var double(b se p) long(N nc) using `res', replace
capture program drop rec
program define rec
    syntax, Col(string) Var(string) Term(string)
    post R ("`col'") ("`var'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(N_clust))
end

local FE fy fd dyr
* （a）原等权距离，应复现 ar68 Seg0f_z 附表6（2）
reghdfe entry c.Patient#c.Seg0_z c.Patient#c.lndist, absorb(`FE') vce(cluster firm)
rec, col(a) var(PxSeg) term(c.Patient#c.Seg0_z)
rec, col(a) var(PxDist) term(c.Patient#c.lndist)
* （b）省内 GDP 加权距离（当年总部）
reghdfe entry c.Patient#c.Seg0_z c.Patient#c.lndist_gdp, absorb(`FE') vce(cluster firm)
rec, col(b) var(PxSeg) term(c.Patient#c.Seg0_z)
rec, col(b) var(PxDist) term(c.Patient#c.lndist_gdp)
* （c）省内 GDP 加权距离（首年总部，与市场分割同一母公司城市）
reghdfe entry c.Patient#c.Seg0_z c.Patient#c.lndist_gdp_f, absorb(`FE') vce(cluster firm)
rec, col(c) var(PxSeg) term(c.Patient#c.Seg0_z)
rec, col(c) var(PxDist) term(c.Patient#c.lndist_gdp_f)
* （d）（b）同一样本只放分割交互
reghdfe entry c.Patient#c.Seg0_z if !missing(lndist_gdp), absorb(`FE') vce(cluster firm)
rec, col(d) var(PxSeg) term(c.Patient#c.Seg0_z)

postclose R
use `res', clear
list, noobs clean
export delimited using "`EXP'/output/tables/ar74_dist_gdpweight.csv", replace
log close ar74
