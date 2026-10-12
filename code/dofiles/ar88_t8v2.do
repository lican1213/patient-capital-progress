*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar88_t8v2.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十七轮：新表8 导师清单版）
* Purpose:  规则见本 exploration README 第四十七轮。回归与交付命令“表8命令_新版.do”相同，另存结果供出表与核查。
* Inputs:   16 号主面板3；data/derived/advisor_send_20261008/21_表8新版变量.dta（ar88_export_t8v2.py）
* Outputs:  本 exploration 的 output/tables/ar88_t8v2.csv、ar88_rank.dta
* Log:      explorations/advisor_revision_20261005/logs/ar88_t8v2.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar88
log using "`EXP'/logs/ar88_t8v2.log", name(ar88) replace text

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "data/derived/advisor_send_20261008/21_表8新版变量.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate byte es = year >= 2015 & !missing(entry, Patient)
bysort year: egen double rk  = rank(seg_m3l) if es & !missing(seg_m3l)
bysort year: egen double cnt = count(seg_m3l) if es & !missing(seg_m3l)
generate double seg = (rk - 1) / (cnt - 1)
drop rk cnt
foreach v in mkt_t rd_t {
    quietly summarize `v' if es
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
generate double PxSeg  = Patient * seg
generate double PxEast = Patient * east
generate double PxCent = Patient * d_cent
generate double PxMkt  = Patient * z_mkt_t
generate double PxRd   = Patient * z_rd_t
generate double PxGdp  = Patient * lngdpr
generate double PxDist = Patient * lndist
preserve
keep if es & !missing(seg)
keep stkcd dest_id year seg
save "`EXP'/output/tables/ar88_rank.dta", replace
restore

tempfile res
postfile R byte col str6 var double(b se p) long N double r2a long nclust using `res', replace
capture program drop rec
program define rec
    syntax, Col(integer) Vars(string)
    foreach v of local vars {
        post R (`col') ("`v'") (_b[`v']) (_se[`v']) (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a)) (e(N_clust))
    }
end
reghdfe entry PxSeg seg if es, absorb(fy fd dyr) vce(cluster firm)
rec, col(1) vars(PxSeg seg)
reghdfe entry PxSeg seg if es & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
rec, col(2) vars(PxSeg seg)
reghdfe entry PxEast PxCent if es, absorb(fy fd dyr) vce(cluster firm)
rec, col(3) vars(PxEast PxCent)
local c = 4
foreach x in PxMkt PxRd PxGdp PxDist {
    reghdfe entry `x' if es, absorb(fy fd dyr) vce(cluster firm)
    rec, col(`c') vars(`x')
    local ++c
}
reghdfe entry PxSeg seg PxRd PxDist if es, absorb(fy fd dyr) vce(cluster firm)
rec, col(8) vars(PxSeg seg PxRd PxDist)
postclose R
use `res', clear
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar88_t8v2.csv", replace
log close ar88
