*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar49_timing_base.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十七轮：双边去向表的时点与基期统一）
* Purpose:  规则见本 exploration README 第十七轮（运行前写定）。
*           P1＝L.Patient（现行，assert 复现现表）；P0＝当期 Patient。
*           市场分割基期：B0＝2010—2013 年均值（现行）；B1＝2014 年；B2＝当年（另放水平项）。
*           表8 第（3）—（7）列、表9 两列、附表5 只换时点。
* Inputs:   data/derived/unified_market_dyadic_20260923/dyad.dta；
*           data/derived/advisor_revision_20261005/{dest_attr,dest_attr_m7,dest_attr_au,dyad_lq,dyad_rdfix_v2,dyad_timing}.dta
* Outputs:  本 exploration 的 output/tables/ar49_timing.csv
* Log:      explorations/advisor_revision_20261005/logs/ar49_timing_base.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
capture log close ar49
log using "`EXP'/logs/ar49_timing_base.log", name(ar49) replace text
which reghdfe

tempfile res
postfile R str4 tab str3 col str2 tm str3 base str40 term double(b se p) long(N) using `res', replace
capture program drop rec
program define rec
    * 记录一个交互项系数
    syntax, Tab(string) Col(string) Tm(string) Base(string) Term(string)
    post R ("`tab'") ("`col'") ("`tm'") ("`base'") ("`term'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N))
end

use "data/derived/unified_market_dyadic_20260923/dyad.dta", clear
merge m:1 dest_id using "`D'/dest_attr.dta", keep(master match) nogenerate
merge m:1 dest_id using "`D'/dest_attr_m7.dta", keep(master match) nogenerate
merge m:1 dest_id using "`D'/dest_attr_au.dta", keep(master match) nogenerate
merge m:1 stkcd dest_id using "`D'/dyad_lq.dta", keep(master match) nogenerate
merge 1:1 stkcd year dest_id using "`D'/dyad_rdfix_v2.dta"
drop if _merge == 2
drop _merge
merge 1:1 stkcd year dest_id using "`D'/dyad_timing.dta", assert(match) nogenerate
* 构造时已核对 Seg0_chk 与 Seg0_z 一致，这里再核一次
assert abs(Seg0_chk - Seg0_z) < 1e-6 if !missing(Seg0_z)
* 直辖市目的地编码（同 ar13）：上海 1、北京 4、天津 7、重庆 28
generate byte d_muni = inlist(dest_id, 1, 4, 7, 28)
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
rename Patient P0
rename L_Patient P1
* 两种时点下的样本差异
count if year >= 2015 & !missing(entry) & !missing(P1)
count if year >= 2015 & !missing(entry) & !missing(P0)
count if year >= 2015 & !missing(entry) & !missing(P0) & missing(P1)

*=== 表8 第（1）（2）列：市场分割，时点 × 基期 ====================================
foreach t in P1 P0 {
    foreach b in B0 B1 B2 {
        local sv = cond("`b'" == "B0", "Seg0_z", cond("`b'" == "B1", "Seg14_z", "Segt_z"))
        capture drop PxS
        generate double PxS = `t' * `sv'
        local lev = cond("`b'" == "B2", "`sv'", "")
        reghdfe entry PxS `lev' if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
        if "`t'`b'" == "P1B0" assert abs(_b[PxS] - .001083208326683) < 1e-9
        rec, tab(T8) col(1) tm(`t') base(`b') term(PxS)
        reghdfe entry PxS `lev' if year >= 2015 & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
        if "`t'`b'" == "P1B0" assert abs(_b[PxS] - .0015525535431442) < 1e-9
        rec, tab(T8) col(2) tm(`t') base(`b') term(PxS)
    }
}

*=== 表8 第（3）—（7）列：其他属性，只换时点 ======================================
foreach t in P1 P0 {
    local k = 2
    foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
        local ++k
        capture drop PxA
        generate double PxA = `t' * `a'
        reghdfe entry PxA if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
        if "`t'" == "P1" & `k' == 3 assert abs(_b[PxA] - .0011209227409808) < 1e-9
        rec, tab(T8) col(`k') tm(`t') base(B0) term(PxA)
    }
}

*=== 表9 第（1）列联合估计、附表5、表9 第（2）列研发型新增 ========================
foreach t in P1 P0 {
    local J c.`t'#c.east c.`t'#c.z_mkt0 c.`t'#c.z_rdres0
    reghdfe entry `J' c.`t'#c.z_tfp0 c.`t'#c.z_lqw if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    if "`t'" == "P1" assert abs(_b[c.P1#c.z_tfp0] - .0003210694554182) < 1e-9
    foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
        rec, tab(T9) col(1) tm(`t') base(B0) term(c.`t'#c.`a')
    }
    reghdfe entry `J' c.`t'#c.z_tfp0_n10 c.`t'#c.z_lqw if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    if "`t'" == "P1" assert abs(_b[c.P1#c.z_tfp0_n10] - .0003086057953341) < 1e-9
    foreach a in east z_mkt0 z_rdres0 z_tfp0_n10 z_lqw {
        rec, tab(A5) col(1) tm(`t') base(B0) term(c.`t'#c.`a')
    }
    capture drop PxRD
    generate double PxRD = `t' * z_rdres0
    reghdfe new_rdfix_any PxRD, absorb(fy fd dyr) vce(cluster firm)
    if "`t'" == "P1" assert abs(_b[PxRD] - .0002372647147246) < 1e-9
    rec, tab(T9) col(2) tm(`t') base(B0) term(PxRD)
}

*=== 诊断：市场分割各年之间的相关 ==================================================
correlate Seg0_z Seg14_z Segt_z if year >= 2015

postclose R
use `res', clear
format b se p %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar49_timing.csv", replace
log close ar49
