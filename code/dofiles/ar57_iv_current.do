*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar57_iv_current.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十一轮：内生性替换为当期）
* Purpose:  表5 第（3）—（5）列与附表1 改为当期 Patient：同群工具取当期，PRI 工具取上一期；断言与 ar54 一致。
* Inputs:   explorations/iv_identification_20260921/data/iv_components.dta；data/derived/analysis_ready.dta；
*           data/derived/unified_market_dyadic_20260923/iv_set.dta
* Outputs:  本 exploration 的 output/tables/ar57_iv_current.csv
* Log:      explorations/advisor_revision_20261005/logs/ar57_iv_current.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar57
log using "`EXP'/logs/ar57_iv_current.log", name(ar57) replace text
which ivreghdfe

tempfile res
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a stat statp) using `res', replace
capture program drop pv
program define pv
    * 记录一列中若干系数（N 与调整后 R² 随每行重复记录）
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a)) (.) (.)
    }
end
capture program drop riv
program define riv
    * 记录 2SLS 主系数（正态近似 p，同 ar45）、KP Wald F 与 KP LM
    syntax, Col(string)
    post R ("T7") ("`col'") ("Patient") (_b[Patient]) (_se[Patient]) (2*normal(-abs(_b[Patient]/_se[Patient]))) ///
        (e(N)) (.) (e(widstat)) (.)
    post R ("I") ("`col'") ("kp") (.) (.) (.) (e(N)) (.) (e(idstat)) (e(idp))
    if e(jdf) > 0 post R ("J") ("`col'") ("hansen") (.) (.) (.) (e(N)) (.) (e(j)) (e(jp))
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local Y 跨省子公司数量占比

*=== 第（3）列：当期同群工具 =========================================================
use "explorations/iv_identification_20260921/data/iv_components.dta", clear
ivreghdfe `Y' (Patient = IV_Hold2 IV_SizeGroup2) `C', absorb(firm_id year) cluster(firm_id)
assert abs(_b[Patient] - .0068565283623943) < 1e-9
riv, col(1)
reghdfe Patient IV_Hold2 IV_SizeGroup2 `C' if e(sample), absorb(firm_id year) vce(cluster firm_id)
pv, tab(F1) col(1) vars(IV_Hold2 IV_SizeGroup2)

*=== 第（4）（5）列：上一期 PRI 工具 =================================================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "data/derived/unified_market_dyadic_20260923/iv_set.dta"
drop if _merge == 2
drop _merge
xtset firm_id year
generate double l_Pri_Number = L.Pri_Number
generate double l_Pri_Hold = L.Pri_Hold
local k = 1
foreach z in l_Pri_Number l_Pri_Hold {
    local ++k
    ivreghdfe `Y' `C' (Patient = `z'), absorb(firm_id year) cluster(firm_id)
    if `k' == 2 assert abs(_b[Patient] - .0157674958617944) < 1e-9
    if `k' == 3 assert abs(_b[Patient] - .0073660071333452) < 1e-9
    riv, col(`k')
    reghdfe Patient `z' `C' if e(sample), absorb(firm_id year) vce(cluster firm_id)
    pv, tab(F1) col(`k') vars(`z')
}

postclose R
use `res', clear
format b se p r2a stat statp %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar57_iv_current.csv", replace
log close ar57
