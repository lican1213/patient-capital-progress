*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar44_fix_audit.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十三轮：按 D-135 审计定点修正，导师原规格）
* Purpose:  只重估审计查实有误的格子，其余表格结果不动（ar26、ar29、ar31、ar34 原输出保留作历史）。
*           H  表5 Heckman：按导师 do 文件（实证代码.do 第 927—929 行）恢复逆米尔斯比率的正负两支——
*              有耐心资本用 φ/Φ，没有用 −φ/(1−Φ)；第二阶段固定效应用新表统一的企业＋行业×年份，
*              另跑导师原写法企业＋年份一版，与初稿8表3报告值对照
*           R2 表4第（2）列：L.Patient 改为 xtset 后的自然年滞后（导师面板旧 L_Patient 在年份不连续处取了上一条记录）
*           T5 表10 六列：改用 ar43 的新增事件与功能分类
*           T6 表9第（2）列：研发型新增（双边）改用 ar43 的首次披露口径
*           D  表1中上述变量的描述统计
* Inputs:   导师主面板；data/derived/analysis_ready.dta；data/derived/unified_market_dyadic_20260923/dyad.dta；
*           data/derived/advisor_revision_20261005/{firm_events_v2,dyad_rdfix_v2,dest_attr}.dta
* Outputs:  本 exploration 的 output/tables/ar44_fix.csv、ar44_desc.csv
* Log:      explorations/advisor_revision_20261005/logs/ar44_fix_audit.log
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
capture log close ar44
log using "`EXP'/logs/ar44_fix_audit.log", name(ar44) replace text
which reghdfe

tempfile res dsc
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a) using `res', replace
postfile S str40 var long(N) double(mean sd min p50 max) using `dsc', replace
capture program drop pv
program define pv
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a))
    }
end
capture program drop dsum
program define dsum
    * 描述统计：在当前估计样本上
    syntax varname, Label(string)
    quietly summarize `varlist' if e(sample), detail
    post S ("`label'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数

*=== 导师主面板：Heckman 与自然年滞后 ================================================
use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
foreach v in treated xb imr Lp {
    capture drop `v'
}
* 导师写法：是否有耐心资本按中位数分组（本数据中位数为 0，等同 Patient>0）
quietly summarize Patient, detail
assert r(p50) == 0
generate byte treated = (Patient > r(p50)) if !missing(Patient)
probit treated `C' 高新技术企业 i.year, vce(cluster id)
assert abs(_b[高新技术企业] - .2690175) < 1e-6
post R ("H1") ("1") ("高新技术企业") (_b[高新技术企业]) (_se[高新技术企业]) ///
    (2*normal(-abs(_b[高新技术企业]/_se[高新技术企业]))) (e(N)) (e(r2_p))
predict double xb if e(sample), xb
generate double imr = normalden(xb) / normal(xb) if treated == 1
replace imr = -normalden(xb) / (1 - normal(xb)) if treated == 0
* 新表统一固定效应：企业＋行业×年份
reghdfe 跨省子公司数量占比 Patient `C' imr, absorb(id ind_year) vce(cluster id)
pv, tab(H2) col(iy) vars(Patient imr)
* 导师原写法：企业＋年份，应与初稿8表3一致
reghdfe 跨省子公司数量占比 Patient `C' imr, absorb(id year) vce(cluster id)
assert abs(_b[Patient] - .0012265) < 1e-6 & abs(_b[imr] - .0053262) < 1e-6
pv, tab(H2) col(y) vars(Patient imr)

* 表4第（2）列：自然年滞后
xtset id year
generate double Lp = L.Patient
quietly count if !missing(L_Patient) & missing(Lp)
display "旧 L_Patient 有值但不是上一自然年的观测：" r(N)
reghdfe 跨省子公司数量占比 Lp `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(2) vars(Lp)

*=== analysis_ready：表10 功能类型 ===================================================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "`D'/firm_events_v2.dta", keep(master match) nogenerate
foreach v in n_new n_rep n_comp new_x_rdfix new_ECW n_rdcomp n_unkprev {
    generate double l_`v' = ln(1 + `v')
}
local k = 0
foreach v in n_new n_rep n_comp new_x_rdfix {
    local ++k
    reghdfe l_`v' Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
    pv, tab(T5) col(`k') vars(Patient)
    local lab : word `k' of 进入新省份新增 同功能复制新增 功能互补新增 研发型新增
    dsum l_`v', label(`lab')
}
reghdfe l_n_rdcomp Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(6) vars(Patient)
dsum l_n_rdcomp, label(研发互补新增)
reghdfe l_new_ECW Patient `C' if sample_main == 1 & home_east == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(5) vars(Patient)
dsum l_new_ECW, label(东部企业到中西部新增)
* 旧功能未知一类单独记录，不进表
reghdfe l_n_unkprev Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(u) vars(Patient)

*=== 双边：表9第（2）列 研发型新增 ===================================================
use "data/derived/unified_market_dyadic_20260923/dyad.dta", clear
merge m:1 dest_id using "`D'/dest_attr.dta", keep(master match) nogenerate
merge 1:1 stkcd year dest_id using "`D'/dyad_rdfix_v2.dta"
* 新口径的研发型新增格子应全部能并入双边面板（只有双边面板外的企业—年份才会落在 using 一侧）
quietly count if _merge == 2
display "未并入双边面板的研发型新增格子：" r(N)
drop if _merge == 2
drop _merge
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
bysort stkcd: egen int fy0 = min(year)
quietly summarize rdres0
generate double z_rdres0 = (rdres0 - r(mean)) / r(sd)
replace new_rdfix_any = 0 if missing(new_rdfix_any)
replace new_rdfix_any = . if year <= fy0
generate double PxRD = L_Patient * z_rdres0
reghdfe new_rdfix_any PxRD, absorb(fy fd dyr) vce(cluster firm)
pv, tab(T6) col(3) vars(PxRD)
dsum new_rdfix_any, label(研发型新增（双边）)

postclose R
postclose S
use `res', clear
format b se p r2a %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar44_fix.csv", replace
use `dsc', clear
list, noobs
export delimited using "`EXP'/output/tables/ar44_desc.csv", replace
log close ar44
