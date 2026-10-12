*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar82_seg_lag_mkt_year.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十二轮：上一年市场分割的北京检验；市场化改逐年）
* Purpose:  规则见本 exploration README 第四十二轮（运行前写定）。设定同 ar81。
* Inputs:   deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/advisor_send_20261008/目的省研发资源_逐年.dta（ar81）；
*           data/raw/price_index/1997-2024年市场化指数和各分项指数.dta
* Outputs:  本 exploration 的 output/tables/ar82_seg_lag_mkt_year.csv
* Log:      explorations/advisor_revision_20261005/logs/ar82_seg_lag_mkt_year.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar82
log using "`EXP'/logs/ar82_seg_lag_mkt_year.log", name(ar82) replace text
which reghdfe

* 市场化逐年：省份×年份，当年值与上一年值
use province_in year market using "data/raw/price_index/1997-2024年市场化指数和各分项指数.dta", clear
rename province_in dest
replace year = round(year)
encode dest, generate(did)
xtset did year
generate double mkt_t  = market
generate double mkt_l1 = L.market
keep dest year mkt_t mkt_l1
tempfile mk
save `mk'

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge m:1 dest year using "data/derived/advisor_send_20261008/目的省研发资源_逐年.dta", keep(master match) nogenerate
merge m:1 dest year using `mk', keep(master match)
tabulate _merge if year >= 2015
drop _merge
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj   = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr

* 上一年市场分割（同 ar81）
xtset fd year
generate double Seg_l1 = L.Segt_z

* 在估计样本内标准化
foreach v in rd_l1 mkt_t mkt_l1 mkt0 {
    quietly summarize `v' if year >= 2015 & !missing(entry, Patient)
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
correlate mkt_t mkt_l1 mkt0 if year >= 2015 & !missing(entry, Patient)

generate double PxSl = Patient * Seg_l1
generate double PxRl = Patient * z_rd_l1
generate double PxD  = Patient * lndist
generate double PxM  = Patient * z_mkt_t
generate double PxMl = Patient * z_mkt_l1
generate double PxM0 = Patient * z_mkt0

tempfile res
postfile R str10 spec str6 smp str5 var double(b se p) long(N nclust) using `res', replace
capture program drop rec
program define rec
    syntax, Spec(string) Smp(string) Vars(string)
    foreach v of local vars {
        post R ("`spec'") ("`smp'") ("`v'") (1000*_b[`v']) (1000*_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(N_clust))
    }
end

local base year >= 2015

* ---- A 上一年市场分割 ----
foreach s in all nobj nomuni {
    local c ""
    if "`s'" == "nobj"   local c "& d_bj == 0"
    if "`s'" == "nomuni" local c "& d_muni == 0"
    reghdfe entry PxSl Seg_l1 if `base' `c', absorb(`FE') vce(cluster firm)
    rec, spec(A_segl1) smp(`s') vars(PxSl Seg_l1)
    reghdfe entry PxSl Seg_l1 PxRl PxD if `base' `c', absorb(`FE') vce(cluster firm)
    rec, spec(A_joint) smp(`s') vars(PxSl Seg_l1 PxRl PxD)
}

* ---- B 市场化逐年 ----
foreach s in all nobj nomuni to2019 {
    local c ""
    if "`s'" == "nobj"   local c "& d_bj == 0"
    if "`s'" == "nomuni" local c "& d_muni == 0"
    if "`s'" == "to2019" local c "& year <= 2019"
    reghdfe entry PxM if `base' `c', absorb(`FE') vce(cluster firm)
    rec, spec(B_mkt_t) smp(`s') vars(PxM)
    reghdfe entry PxMl if `base' `c', absorb(`FE') vce(cluster firm)
    rec, spec(B_mkt_l1) smp(`s') vars(PxMl)
    reghdfe entry PxM0 if `base' `c', absorb(`FE') vce(cluster firm)
    rec, spec(B_mkt0) smp(`s') vars(PxM0)
}

postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar82_seg_lag_mkt_year.csv", replace
log close ar82
