*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar59_sync.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十三轮：交接同步）
* Purpose:  规则见本 exploration README 第二十三轮（运行前写定）：表10 改导师 ind_year；安慰剂改为可复现写法；
*           表1 双边与功能类型描述统计改在当期写法样本上计算。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta；data/derived/analysis_ready.dta；
*           data/derived/advisor_revision_20261005/firm_events_v2.dta；data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta
* Outputs:  本 exploration 的 output/tables/ar59_sync.csv、ar59_desc.csv
* Log:      explorations/advisor_revision_20261005/logs/ar59_sync.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
local P1 "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta"
capture log close ar59
log using "`EXP'/logs/ar59_sync.log", name(ar59) replace text
which reghdfe

tempfile res dsc plc
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a stat statp) using `res', replace
postfile DS str40 var long(N) double(mean sd min p50 max) using `dsc', replace
capture program drop pv
program define pv
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
    post DS ("`label'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份

*=== 1. 表10：导师 ind_year ========================================================
use stkcd year ind_year using "`P1'", clear
tempfile iy
save `iy'
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using `iy', keep(master match)
count if sample_main == 1 & _merge == 1
drop _merge
merge 1:1 stkcd year using "`D'/firm_events_v2.dta", keep(master match) nogenerate
foreach v in n_new n_rep n_comp new_x_rdfix new_ECW n_rdcomp {
    generate double l_`v' = ln(1 + `v')
}
local k = 0
foreach v in n_new n_rep n_comp new_x_rdfix {
    local ++k
    reghdfe l_`v' Patient `C' if sample_main == 1, absorb(firm_id ind_year) vce(cluster firm_id)
    pv, tab(T5) col(`k') vars(Patient)
    local lab : word `k' of 进入新省份新增 同功能复制新增 功能互补新增 研发型新增
    dsum l_`v', label(`lab')
}
reghdfe l_n_rdcomp Patient `C' if sample_main == 1, absorb(firm_id ind_year) vce(cluster firm_id)
pv, tab(T5) col(6) vars(Patient)
dsum l_n_rdcomp, label(研发互补新增)
reghdfe l_new_ECW Patient `C' if sample_main == 1 & home_east == 1, absorb(firm_id ind_year) vce(cluster firm_id)
pv, tab(T5) col(5) vars(Patient)
dsum l_new_ECW, label(东部企业到中西部新增)

*=== 2. 双边描述统计（当期写法样本）================================================
use "data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta", clear
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
reghdfe entry c.Patient#c.(east z_mkt0 z_rdres0 z_tfp0 z_lqw) if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
assert abs(_b[c.Patient#c.z_tfp0] - .0004475077878813) < 1e-9
foreach v in entry Seg0_z east mkt0 rdres0 tfp0 lqw {
    dsum `v', label(`v')
}
generate double Px = Patient * z_rdres0
reghdfe new_rdfix_any Px, absorb(fy fd dyr) vce(cluster firm)
dsum new_rdfix_any, label(研发型新增（双边）)

*=== 3. 安慰剂：排序后设种子，可复现 ===============================================
use "`P1'", clear
reghdfe 跨省子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
assert abs(_b[Patient] - .0016757) < 1e-6
local true_b = _b[Patient]
keep if e(sample)
keep 跨省子公司数量占比 Patient `C' id year ind_year
sort id year
set seed 20261008
postfile Q double(b p) using `plc', replace
forvalues i = 1/1000 {
    quietly {
        generate double placebo = Patient[runiformint(1, _N)]
        reghdfe 跨省子公司数量占比 placebo `C', absorb(id ind_year) vce(cluster id)
        post Q (_b[placebo]) (2*ttail(e(df_r), abs(_b[placebo]/_se[placebo])))
        drop placebo
    }
}
postclose Q
use `plc', clear
quietly count if b >= `true_b'
local pe = r(N) / _N
quietly count if p < .10
local s10 = r(N) / _N
quietly summarize b
post R ("P") ("1") ("summary") (r(mean)) (r(sd)) (`pe') (_N) (`s10') (.) (.)
display "置换系数均值 " r(mean) "，标准差 " r(sd) "，不小于真实系数的比例 " `pe' "，p<0.1 的比例 " `s10'

postclose R
postclose DS
use `res', clear
format b se p r2a %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar59_sync.csv", replace
use `dsc', clear
list, noobs
export delimited using "`EXP'/output/tables/ar59_desc.csv", replace
log close ar59
