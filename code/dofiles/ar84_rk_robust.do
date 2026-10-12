*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar84_rk_robust.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十四轮：候选 rk_l1、rk_m3l 的稳健性）
* Purpose:  规则见本 exploration README 第四十四轮（运行前写定）。百分位构造与 ar83 相同。
* Inputs:   16 号主面板3；data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta（ar83）、目的省研发资源_逐年.dta（ar81）
* Outputs:  本 exploration 的 output/tables/ar84_rk_robust.csv
* Log:      explorations/advisor_revision_20261005/logs/ar84_rk_robust.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar84
log using "`EXP'/logs/ar84_rk_robust.log", name(ar84) replace text
which reghdfe

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta", keep(master match) nogenerate
merge m:1 dest year using "data/derived/advisor_send_20261008/目的省研发资源_逐年.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr
generate byte es = year >= 2015 & !missing(entry, Patient)

* 年内百分位（同 ar83）
foreach k in l1 m3l {
    bysort year: egen double _rk = rank(seg_`k') if es & !missing(seg_`k')
    bysort year: egen double _cnt = count(seg_`k') if es & !missing(seg_`k')
    generate double rk_`k' = (_rk - 1) / (_cnt - 1)
    generate byte q5_`k' = rk_`k' >= .8 if !missing(rk_`k')
    drop _rk _cnt
}
quietly summarize rd_l1 if es
generate double z_rd_l1 = (rd_l1 - r(mean)) / r(sd)
generate double PxR = Patient * z_rd_l1
generate double PxD = Patient * lndist

tempfile res
postfile R str5 k str10 chk str40 note double(b se p) long(N nclust) using `res', replace
capture program drop rec
program define rec
    syntax, K(string) Chk(string) [Note(string)]
    post R ("`k'") ("`chk'") ("`note'") (1000*_b[PxX]) (1000*_se[PxX]) ///
        (2*ttail(e(df_r), abs(_b[PxX]/_se[PxX]))) (e(N)) (e(N_clust))
    display "`k' `chk' `note'  b=" %9.5f 1000*_b[PxX] "  p=" %6.3f 2*ttail(e(df_r), abs(_b[PxX]/_se[PxX]))
end

foreach k in l1 m3l {
    capture drop X PxX
    generate double X = rk_`k'
    generate double PxX = Patient * X
    quietly reghdfe entry PxX X if es, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(base)
    * （a）同放研发、距离
    quietly reghdfe entry PxX X PxR PxD if es, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(a_joint)
    * （b）双向聚类
    quietly reghdfe entry PxX X if es, absorb(`FE') vce(cluster firm dest_id)
    rec, k(`k') chk(b_2way)
    * （c）年份
    quietly reghdfe entry PxX X if es & year != 2015, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(c_no2015)
    quietly reghdfe entry PxX X if es & year <= 2022, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(c_to2022)
    quietly reghdfe entry PxX X if es & year != 2015 & year < 2023, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(c_1622)
    * （d）逐省剔除目的省
    levelsof dest if es, local(DL)
    foreach d of local DL {
        quietly reghdfe entry PxX X if es & dest != "`d'", absorb(`FE') vce(cluster firm)
        rec, k(`k') chk(d_drop) note(`d')
    }
    * （e）上一年耐心资本
    capture drop LPxX
    generate double LPxX = L_Patient * X
    quietly reghdfe entry LPxX X if es & !missing(L_Patient), absorb(`FE') vce(cluster firm)
    post R ("`k'") ("e_LPatient") ("") (1000*_b[LPxX]) (1000*_se[LPxX]) (2*ttail(e(df_r), abs(_b[LPxX]/_se[LPxX]))) (e(N)) (e(N_clust))
    * （f）最高五分组虚拟变量
    capture drop X PxX
    generate double X = q5_`k'
    generate double PxX = Patient * X
    quietly reghdfe entry PxX X if es, absorb(`FE') vce(cluster firm)
    rec, k(`k') chk(f_top20)
}
postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar84_rk_robust.csv", replace
log close ar84
