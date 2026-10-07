*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar29_iv_dyad_mentor.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第七轮：回复导师用的内生性表与去向表，导师原规格）
* Purpose:  T7 内生性：导师滞后同群留一 IV（同 ar04 L0）与 PRI 工具（同 ar04 U1na、U1ha，企业＋年份 FE，
*              控制变量取上一期）；均不加企业规模，与 ar04 对应结果 assert 一致。
*           T6 去向：双边当年新增对 L.Patient×目的地市场分割（全样本、剔除直辖市目的地），研发型新增对
*              L.Patient×目的省研发资源（同 ar13、ar09）。
*           T8 去向属性：双边当年新增对 L.Patient×东部、市场化、研发资源、期初 TFP、同行业区位熵，逐项估计。
*           双边模型含企业×年份、企业×目的省、目的省×年份 FE，企业聚类。
* Inputs:   explorations/iv_identification_20260921/data/iv_components.dta；data/derived/analysis_ready.dta；
*           data/derived/unified_market_dyadic_20260923/{dyad,iv_set}.dta；
*           data/derived/advisor_revision_20261005/{dest_attr,dest_attr_m7,dyad_lq,dyad_rdfix}.dta
* Outputs:  本 exploration 的 output/tables/ar29_iv_dyad_mentor.csv
* Log:      explorations/advisor_revision_20261005/logs/ar29_iv_dyad_mentor.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261007

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
capture log close ar29
log using "`EXP'/logs/ar29_iv_dyad_mentor.log", name(ar29) replace text
which ivreghdfe

tempfile res
postfile R str3 tab str3 col str20 var double(b se p) long(N) double(r2a kpf) using `res', replace
capture program drop riv
program define riv
    * 记录 2SLS 主系数与 Kleibergen–Paap rk Wald F（正态近似 p，同 ar04）
    syntax, Col(string) X(name)
    post R ("T7") ("`col'") ("`x'") (_b[`x']) (_se[`x']) (2*normal(-abs(_b[`x']/_se[`x']))) ///
        (e(N)) (.) (e(widstat))
end
capture program drop pd
program define pd
    * 记录双边交互项
    syntax, Tab(string) Col(string) Term(name)
    post R ("`tab'") ("`col'") ("`term'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(r2_a)) (.)
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数

*=== T7a 导师滞后同群 IV ==============================================================
use "explorations/iv_identification_20260921/data/iv_components.dta", clear
keep if sample_iv_lagged == 1
ivreghdfe 跨省子公司数量占比 (Patient_lag1 = IV_Hold2_lag1 IV_SizeGroup2_lag1) `C', absorb(firm_id year) cluster(firm_id)
assert abs(_b[Patient_lag1] - .0077804439278905) < 1e-9
riv, col(1) x(Patient_lag1)

*=== T7b PRI 工具 ====================================================================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "data/derived/unified_market_dyadic_20260923/iv_set.dta"
drop if _merge == 2
drop _merge
xtset firm_id year
generate double lp = L.Patient
local LC
local k = 0
foreach v of local C {
    local ++k
    generate double lc`k' = L.`v'
    local LC `LC' lc`k'
}
generate double l_Pri_Number = L.Pri_Number
generate double l_Pri_Hold = L.Pri_Hold
ivreghdfe 跨省子公司数量占比 `LC' (lp = l_Pri_Number), absorb(firm_id year) cluster(firm_id)
assert abs(_b[lp] - .0209033883751268) < 1e-9
riv, col(2) x(lp)
ivreghdfe 跨省子公司数量占比 `LC' (lp = l_Pri_Hold), absorb(firm_id year) cluster(firm_id)
riv, col(3) x(lp)

*=== T6、T8 双边 ======================================================================
use "data/derived/unified_market_dyadic_20260923/dyad.dta", clear
merge m:1 dest_id using "`D'/dest_attr.dta", keep(master match) nogenerate
merge m:1 dest_id using "`D'/dest_attr_m7.dta", keep(master match) nogenerate
merge m:1 stkcd dest_id using "`D'/dyad_lq.dta", keep(master match) nogenerate
merge 1:1 stkcd year dest_id using "`D'/dyad_rdfix.dta", keep(master match) nogenerate
* 直辖市目的地编码（同 ar13）：上海 1、北京 4、天津 7、重庆 28
generate byte d_muni = inlist(dest_id, 1, 4, 7, 28)
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
bysort stkcd: egen int fy0 = min(year)
summarize lq, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
foreach v in mkt0 rdres0 tfp0 lqw {
    quietly summarize `v'
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
replace new_rdfix_any = 0 if missing(new_rdfix_any)
replace new_rdfix_any = . if year <= fy0
generate double PxSeg = L_Patient * Seg0_z
generate double PxRD = L_Patient * z_rdres0
reghdfe entry PxSeg if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[PxSeg] - .001083208326683) < 1e-9
pd, tab(T6) col(1) term(PxSeg)
reghdfe entry PxSeg if year >= 2015 & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
pd, tab(T6) col(2) term(PxSeg)
reghdfe new_rdfix_any PxRD, absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[PxRD] - .0002372647147246) < 1e-9
pd, tab(T6) col(3) term(PxRD)
local k = 0
foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
    local ++k
    generate double Px_`k' = L_Patient * `a'
    reghdfe entry Px_`k' if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    pd, tab(T8) col(`k') term(Px_`k')
}

postclose R
use `res', clear
format b se p r2a kpf %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar29_iv_dyad_mentor.csv", replace
log close ar29
