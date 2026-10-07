*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar31_skeleton_fill.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第八轮：补齐新表所需输出，导师原规格）
* Purpose:  规格全部同 ar26、ar29，只补新表缺的输出（预登记见本 exploration README 第八轮）：
*           D  表1 新增变量描述统计（各变量所在回归的估计样本）
*           I  表5 的 Kleibergen–Paap rk LM 统计量；附表1 第一阶段
*           A2 附表2 机制两步（主 Y 对 Patient 与机制变量）
*           A3 附表3 异质性交互（Patient×高组）
*           J  表9 五项联合；附表6 期初 TFP 剔除样本少于 10 家省份
*           关键系数 assert 与 ar26、ar29、ar09、ar12 一致。
* Inputs:   导师主面板；data/derived/analysis_ready.dta；
*           data/derived/advisor_revision_20261005/{firm_complement,firm_rdfix,firm_r3,survival,
*           dest_attr,dest_attr_m7,dest_attr_au,dyad_lq,dyad_rdfix}.dta；
*           data/derived/unified_market_dyadic_20260923/{dyad,iv_set}.dta；
*           explorations/iv_identification_20260921/data/iv_components.dta
* Outputs:  本 exploration 的 output/tables/ar31_skeleton_fill.csv、ar31_desc.csv
* Log:      explorations/advisor_revision_20261005/logs/ar31_skeleton_fill.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261007

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
local P "data/mentor_panel"
capture log close ar31
log using "`EXP'/logs/ar31_skeleton_fill.log", name(ar31) replace text
which reghdfe
which ivreghdfe

tempfile res dsc
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a stat statp) using `res', replace
postfile S str40 var long(N) double(mean sd min p50 max) using `dsc', replace
capture program drop pv
program define pv
    * 记录一列中若干系数
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a)) (.) (.)
    }
end
capture program drop dsum
program define dsum
    * 描述统计：在当前估计样本上
    syntax varname, Label(string)
    quietly summarize `varlist' if e(sample), detail
    post S ("`label'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
end
* 双边新增从 2015 年起（同 ar29）；存续窗口不晚于样本末年 2024（导师写法）
local Y0 2015
local YEND 2024
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数

*=== 导师主面板：表3 列（1）—（3）描述、机制描述与两步、异质性交互 =====================
use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
local k = 0
foreach v in l新增跨省子公司数量 l新增跨省子公司注册资本 l新增同省异市子公司数量 {
    local ++k
    quietly reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    local lab : word `k' of Investnn Investnc Investnns
    dsum `v', label(`lab')
}
generate double M_comA = ln(1 + 母公司专利总数)
local k = 0
foreach v in WW指数 ASY SCDRisk2_100倍 供应链韧性 M_comA l子公司独立专利总和 集团创新地理分散度 {
    local ++k
    quietly reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    local lab : word `k' of WW ASY Srisk Resil LcomRDp LindRDs RDexp
    dsum `v', label(`lab')
    if "`lab'" == "WW" assert abs(_b[Patient] - (-.0010958403502601)) < 1e-9
}
* A2 机制两步：主 Y 对 Patient 与机制变量（不含 Resil，Resil 见附表4）
local k = 0
foreach v in WW指数 ASY SCDRisk2_100倍 M_comA l子公司独立专利总和 集团创新地理分散度 {
    local ++k
    reghdfe 跨省子公司数量占比 Patient `v' `C', absorb(id ind_year) vce(cluster id)
    pv, tab(A2) col(`k') vars(Patient `v')
}
* A3 异质性交互：分组定义同 ar26 T4
generate byte g_Seg = (母公司异地市场分割 >= p50_母公司异地市场分割) if !missing(母公司异地市场分割) & !missing(p50_母公司异地市场分割)
generate byte g_Dist = (球面距离小 == 0) if !missing(球面距离小)
generate byte g_Resil = (供应链韧性 >= p50_供应链韧性) if !missing(供应链韧性) & !missing(p50_供应链韧性)
bysort year: egen double md_RD = median(研发投入占营业收入比例)
generate byte g_RD = (研发投入占营业收入比例 >= md_RD) if !missing(研发投入占营业收入比例)
local k = 0
foreach dm in Seg Dist Resil RD {
    local ++k
    generate double PxG = Patient * g_`dm'
    reghdfe 跨省子公司数量占比 Patient g_`dm' PxG `C', absorb(id year) vce(cluster id)
    post R ("A3") ("`k'") ("Patient") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N)) (e(r2_a)) (.) (.)
    post R ("A3") ("`k'") ("PxG") (_b[PxG]) (_se[PxG]) (2*ttail(e(df_r), abs(_b[PxG]/_se[PxG]))) (e(N)) (e(r2_a)) (.) (.)
    post R ("A3") ("`k'") ("G") (_b[g_`dm']) (_se[g_`dm']) (2*ttail(e(df_r), abs(_b[g_`dm']/_se[g_`dm']))) (e(N)) (e(r2_a)) (.) (.)
    drop PxG
}

*=== analysis_ready：功能类型与存续描述 ================================================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "`D'/firm_complement.dta", keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/firm_rdfix.dta", keepusing(new_x_rdfix) keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/firm_r3.dta", keepusing(new_ECW home_east) keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/survival.dta", keep(master match) nogenerate
xtset firm_id year
local k = 0
foreach v in n_new n_rep n_comp new_x_rdfix n_rdcomp {
    local ++k
    generate double l_`v' = ln(1 + `v')
    quietly reghdfe l_`v' Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
    local lab : word `k' of 进入新省份新增 同功能复制新增 功能互补新增 研发型新增 研发互补新增
    dsum l_`v', label(`lab')
}
generate double l_new_ECW = ln(1 + new_ECW)
quietly reghdfe l_new_ECW Patient `C' if sample_main == 1 & home_east == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
dsum l_new_ECW, label(东部企业到中西部新增)
generate double xlag = L.Patient
foreach k in 3 5 {
    generate byte w`k' = (year + `k' <= `YEND') & obs`k' == 1 & stock0 > 0 & !missing(stock0)
}
foreach v in du3 dr3 du5 dr5 {
    local w = cond(inlist("`v'", "du3", "dr3"), "w3", "w5")
    quietly reghdfe `v' xlag `C' if `w' == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
    if "`v'" == "du3" assert abs(_b[xlag] - .1355905505090652) < 1e-9
    local lab = cond("`v'" == "du3", "DuNum3", cond("`v'" == "dr3", "DuRate3", cond("`v'" == "du5", "DuNum5", "DuRate5")))
    dsum `v', label(`lab')
}

*=== 工具变量：KP LM 与第一阶段 ========================================================
use "explorations/iv_identification_20260921/data/iv_components.dta", clear
keep if sample_iv_lagged == 1
ivreghdfe 跨省子公司数量占比 (Patient_lag1 = IV_Hold2_lag1 IV_SizeGroup2_lag1) `C', absorb(firm_id year) cluster(firm_id)
assert abs(_b[Patient_lag1] - .0077804439278905) < 1e-9
post R ("I") ("1") ("kp") (.) (.) (.) (e(N)) (.) (e(idstat)) (e(idp))
reghdfe Patient_lag1 IV_Hold2_lag1 IV_SizeGroup2_lag1 `C' if e(sample), absorb(firm_id year) vce(cluster firm_id)
pv, tab(F1) col(1) vars(IV_Hold2_lag1 IV_SizeGroup2_lag1)

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
local k = 1
foreach z in l_Pri_Number l_Pri_Hold {
    local ++k
    ivreghdfe 跨省子公司数量占比 `LC' (lp = `z'), absorb(firm_id year) cluster(firm_id)
    if `k' == 2 assert abs(_b[lp] - .0209033883751268) < 1e-9
    post R ("I") ("`k'") ("kp") (.) (.) (.) (e(N)) (.) (e(idstat)) (e(idp))
    reghdfe lp `z' `LC' if e(sample), absorb(firm_id year) vce(cluster firm_id)
    pv, tab(F1) col(`k') vars(`z')
}

*=== 双边：表8 描述、表9 五项联合、附表6 ==============================================
use "data/derived/unified_market_dyadic_20260923/dyad.dta", clear
merge m:1 dest_id using "`D'/dest_attr.dta", keep(master match) nogenerate
merge m:1 dest_id using "`D'/dest_attr_m7.dta", keep(master match) nogenerate
merge m:1 dest_id using "`D'/dest_attr_au.dta", keep(master match) nogenerate
merge m:1 stkcd dest_id using "`D'/dyad_lq.dta", keep(master match) nogenerate
merge 1:1 stkcd year dest_id using "`D'/dyad_rdfix.dta", keep(master match) nogenerate
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
bysort stkcd: egen int fy0 = min(year)
summarize lq, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
foreach v in mkt0 rdres0 tfp0 lqw tfp0_n10 {
    quietly summarize `v'
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
replace new_rdfix_any = 0 if missing(new_rdfix_any)
replace new_rdfix_any = . if year <= fy0
local J c.L_Patient#c.east c.L_Patient#c.z_mkt0 c.L_Patient#c.z_rdres0
reghdfe entry `J' c.L_Patient#c.z_tfp0 c.L_Patient#c.z_lqw if year >= `Y0', absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[c.L_Patient#c.z_tfp0] - .0003210694554182) < 1e-9
pv, tab(J) col(1) vars(c.L_Patient#c.east c.L_Patient#c.z_mkt0 c.L_Patient#c.z_rdres0 c.L_Patient#c.z_tfp0 c.L_Patient#c.z_lqw)
foreach v in entry Seg0_z east mkt0 rdres0 tfp0 lqw {
    dsum `v', label(`v')
}
reghdfe entry `J' c.L_Patient#c.z_tfp0_n10 c.L_Patient#c.z_lqw if year >= `Y0', absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[c.L_Patient#c.z_tfp0_n10] - .0003086057953341) < 1e-9
pv, tab(J) col(2) vars(c.L_Patient#c.east c.L_Patient#c.z_mkt0 c.L_Patient#c.z_rdres0 c.L_Patient#c.z_tfp0_n10 c.L_Patient#c.z_lqw)
generate double PxRD = L_Patient * z_rdres0
quietly reghdfe new_rdfix_any PxRD, absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[PxRD] - .0002372647147246) < 1e-9
dsum new_rdfix_any, label(研发型新增（双边）)

postclose R
postclose S
use `res', clear
format b se p r2a stat statp %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar31_skeleton_fill.csv", replace
use `dsc', clear
format mean sd min p50 max %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar31_desc.csv", replace
log close ar31
