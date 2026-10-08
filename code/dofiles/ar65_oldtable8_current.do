*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar65_oldtable8_current.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十七轮：旧表8 三列用当期补跑）
* Purpose:  规则见本 exploration README 第二十七轮（运行前写定）。导师截图3021 旧表8：
*           （1）Patient×基期市场分割；（2）再加 Patient×距离对数；（3）企业与目的省双向聚类；
*           （4）标准化 Patient、标准化短期机构持股分别×基期分割，单侧差异检验。当期为主，滞后作内部对照。
* Inputs:   data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta；
*           data/derived/unified_market_dyadic_20260923/dyad.dta（lndist）；
*           data/derived/advisor_send_20261008/企业短期机构持股当期.dta
* Outputs:  本 exploration 的 output/tables/ar65_oldtable8_current.csv
* Log:      explorations/advisor_revision_20261005/logs/ar65_oldtable8_current.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar65
log using "`EXP'/logs/ar65_oldtable8_current.log", name(ar65) replace text
which reghdfe

* 当期短期机构持股（企业×年）
use "data/derived/advisor_send_20261008/企业短期机构持股当期.dta", clear
keep stkcd year io_short
tempfile io
save `io'
* 距离对数（与主面板3 同键）
use "data/derived/unified_market_dyadic_20260923/dyad.dta", clear
keep stkcd year dest_id lndist L_io_short
tempfile dist
save `dist'

use "data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd year dest_id using `dist', keep(master match)
assert _merge == 3
drop _merge
merge m:1 stkcd year using `io', keep(master match) nogenerate
keep if year >= 2015
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
rename Patient P0
rename L_Patient P1
rename io_short S0
rename L_io_short S1
* 标准化在 year≥2015 样本上做（同 um04）
foreach v in P0 P1 S0 S1 {
    egen double z_`v' = std(`v')
}

tempfile res
postfile R str4 tm byte col str12 var double(b se p) long(N nc) using `res', replace
capture program drop rec
program define rec
    syntax, Tm(string) Col(integer) Var(string) Term(string)
    post R ("`tm'") (`col') ("`var'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(N_clust))
end

local FE fy fd dyr
foreach t in 0 1 {
    * （1）基准
    reghdfe entry c.P`t'#c.Seg0_z, absorb(`FE') vce(cluster firm)
    rec, tm(P`t') col(1) var(PxSeg) term(c.P`t'#c.Seg0_z)
    * （2）加距离对数交互
    reghdfe entry c.P`t'#c.Seg0_z c.P`t'#c.lndist, absorb(`FE') vce(cluster firm)
    rec, tm(P`t') col(2) var(PxSeg) term(c.P`t'#c.Seg0_z)
    rec, tm(P`t') col(2) var(PxDist) term(c.P`t'#c.lndist)
    * （3）企业与目的省双向聚类
    reghdfe entry c.P`t'#c.Seg0_z, absorb(`FE') vce(cluster firm dest_id)
    rec, tm(P`t') col(3) var(PxSeg) term(c.P`t'#c.Seg0_z)
    * （4）标准化 Patient 与短期机构持股
    reghdfe entry c.z_P`t'#c.Seg0_z c.z_S`t'#c.Seg0_z, absorb(`FE') vce(cluster firm)
    rec, tm(P`t') col(4) var(zPxSeg) term(c.z_P`t'#c.Seg0_z)
    rec, tm(P`t') col(4) var(zSxSeg) term(c.z_S`t'#c.Seg0_z)
    lincom _b[c.z_P`t'#c.Seg0_z] - _b[c.z_S`t'#c.Seg0_z]
    post R ("P`t'") (4) ("diff_1side") (r(estimate)) (r(se)) (ttail(r(df), r(estimate)/r(se))) (e(N)) (e(N_clust))
}
postclose R
use `res', clear
format b se p %12.8f
list, clean noobs sep(0)
export delimited using "`EXP'/output/tables/ar65_oldtable8_current.csv", replace
log close ar65
