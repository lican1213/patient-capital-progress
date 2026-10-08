*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar51_oct8_tables.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十八轮：导师 10-08 第二次反馈，出表用数字）
* Purpose:  与 ar49、ar50 同规格，补记调整后 R² 与企业数，供新表使用；断言与 ar49、ar50 一致。
*           1 主面板1：基期调节异质性（当期 H0、滞后 H1）、存续（当期 S0、滞后 S1）。
*           2 主面板3：表8、表9、附表5 的当期（_0）与滞后（_1）。
*           3 用主面板2 重建“当年新设”，与主面板3 的 entry 核对。
* Inputs:   data/mentor_panel/{主面板1_含区位熵_地理IV_创新指标,主面板2_关联公司具体细节}.dta；
*           data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta
* Outputs:  本 exploration 的 output/tables/ar51_oct8.csv
* Log:      explorations/advisor_revision_20261005/logs/ar51_oct8_tables.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
local R "data/mentor_panel"
local P3 "data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta"
capture log close ar51
log using "`EXP'/logs/ar51_oct8_tables.log", name(ar51) replace text
which reghdfe

tempfile res
postfile R str5 tab str2 col str24 var double(b se p) long(N) double(r2a) long(nclust) using `res', replace
capture program drop rec
program define rec
    * 记录一个系数
    syntax, Tab(string) Col(string) Term(string) [Lab(string)]
    if "`lab'" == "" local lab "`term'"
    post R ("`tab'") ("`col'") ("`lab'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(r2_a)) (e(N_clust))
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local Y 跨省子公司数量占比

*=== 1. 主面板1 =====================================================================
use "`R'/主面板1_含区位熵_地理IV_创新指标.dta", clear
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
generate double Lp = L.Patient
local M1 l母公司异地市场一体化
local M2 研发投入占营业收入比例
local M3 供应链韧性
forvalues m = 1/3 {
    capture drop fy Z
    bysort nid (year): egen fy = min(cond(!missing(`M`m''), year, .))
    bysort nid (year): egen Z = max(cond(year == fy, `M`m'', .))
    foreach t in 0 1 {
        local X = cond(`t' == 0, "Patient", "Lp")
        reghdfe `Y' c.`X'##c.Z `C' if year > fy & !missing(Z), absorb(nid ind_year prov_year) vce(cluster nid)
        rec, tab(H`t') col(`m') term(`X') lab(X)
        rec, tab(H`t') col(`m') term(c.`X'#c.Z) lab(XxZ)
        quietly summarize Z if e(sample), detail
        local z25 = r(p25)
        local z50 = r(p50)
        local z75 = r(p75)
        local NN = e(N)
        local NC = e(N_clust)
        local dfr = e(df_r)
        foreach q in 25 50 75 {
            lincom `X' + `z`q''*c.`X'#c.Z
            post R ("H`t'") ("`m'") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN') (.) (`NC')
        }
    }
}
local k = 0
foreach v in cross_surv3_num cross_surv3_rate cross_surv5_num cross_surv5_rate {
    local ++k
    local yy = cond(strpos("`v'", "surv3"), 2021, 2019)
    reghdfe `v' Patient `C' if 跨省子公司数量 > 0 & year <= `yy', absorb(id ind_year) vce(cluster id)
    rec, tab(S0) col(`k') term(Patient)
    reghdfe `v' L.(Patient `C') if 跨省子公司数量 > 0 & year <= `yy', absorb(id ind_year) vce(cluster id)
    rec, tab(S1) col(`k') term(L.Patient)
}

*=== 2. 主面板3 =====================================================================
use "`P3'", clear
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
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
foreach t in 0 1 {
    capture drop Px
    generate double Px = P`t' * Seg0_z
    reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    rec, tab(D8_`t') col(1) term(Px)
    reghdfe entry Px if year >= 2015 & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
    rec, tab(D8_`t') col(2) term(Px)
    local k = 2
    foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
        local ++k
        capture drop Px
        generate double Px = P`t' * `a'
        reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
        rec, tab(D8_`t') col(`k') term(Px)
    }
    reghdfe entry c.P`t'#c.(east z_mkt0 z_rdres0 z_tfp0 z_lqw) if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
        rec, tab(D9_`t') col(1) term(c.P`t'#c.`a') lab(`a')
    }
    reghdfe entry c.P`t'#c.(east z_mkt0 z_rdres0 z_tfp0_n10 z_lqw) if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    foreach a in east z_mkt0 z_rdres0 z_tfp0_n10 z_lqw {
        rec, tab(A5_`t') col(1) term(c.P`t'#c.`a') lab(`a')
    }
    capture drop Px
    generate double Px = P`t' * z_rdres0
    reghdfe new_rdfix_any Px, absorb(fy fd dyr) vce(cluster firm)
    rec, tab(D9_`t') col(2) term(Px)
}

*=== 3. 用主面板2 重建“当年新设”并核对 ============================================
preserve
use stkcd sub_name year province_in using "`R'/主面板2_关联公司具体细节.dta", clear
* 子公司首次出现在明细中的年份即新设年份
bysort stkcd sub_name: egen int first = min(year)
generate byte new = (year == first)
collapse (max) new, by(stkcd year province_in)
rename province_in dest
tempfile nw
save `nw'
restore
merge 1:1 stkcd year dest using `nw', keep(master match) nogenerate
replace new = 0 if missing(new)
count if !missing(entry) & new != entry
assert r(N) == 0

postclose R
use `res', clear
format b se p r2a %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar51_oct8.csv", replace
log close ar51
