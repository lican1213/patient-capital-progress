*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar75_prov_seg.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十五轮：省级逐年市场分割，朱凯等 2019 方法）
* Purpose:  规则见本 exploration README 第三十五轮（运行前写定）。
*           表7（1）：导师公式 Seg_it（2014 年 GDP/距离固定权重），省级当期为主、t−1 另报，城市对当期为对照；
*           表8（1）（2）：母公司首年所在省×目的省的省级分割，当期为主、t−1 另报，含水平项。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/prov_seg_20261010/表7_企业年份市场分割.dta、表8_企业目的省年份市场分割.dta
* Outputs:  本 exploration 的 output/tables/ar75_prov_seg.csv
* Log:      explorations/advisor_revision_20261005/logs/ar75_prov_seg.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar75
log using "`EXP'/logs/ar75_prov_seg.log", name(ar75) replace text
which reghdfe

tempfile res
postfile R str3 tab str10 z str4 col str6 var double(b se p) long(N nclust) using `res', replace

*--- 1. 表7（1）：企业×年份 ---------------------------------------------------
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割.dta", keep(master match) nogenerate
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
correlate seg_pv seg_pv_l1 seg_city
foreach zv in seg_city seg_pv seg_pv_l1 {
    capture drop ZZ
    generate double ZZ = `zv'
    reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if !missing(ZZ), absorb(nid ind_year prov_year) vce(cluster nid)
    local NN = e(N)
    local NC = e(N_clust)
    local dfr = e(df_r)
    post R ("T7") ("`zv'") ("1") ("X") (_b[Patient]) (_se[Patient]) (2*ttail(`dfr', abs(_b[Patient]/_se[Patient]))) (`NN') (`NC')
    post R ("T7") ("`zv'") ("1") ("XxZ") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(`dfr', abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (`NN') (`NC')
    post R ("T7") ("`zv'") ("1") ("Z") (_b[ZZ]) (_se[ZZ]) (2*ttail(`dfr', abs(_b[ZZ]/_se[ZZ]))) (`NN') (`NC')
    quietly summarize ZZ if e(sample), detail
    local z25 = r(p25)
    local z50 = r(p50)
    local z75 = r(p75)
    foreach q in 25 50 75 {
        quietly lincom Patient + `z`q''*c.Patient#c.ZZ
        post R ("T7") ("`zv'") ("1") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN') (`NC')
    }
}

*--- 2. 表8（1）（2）：企业×目的省×年份 ----------------------------------------
use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd year dest using "data/derived/prov_seg_20261010/表8_企业目的省年份市场分割.dta", keep(master match)
assert _merge == 3
drop _merge
keep if year >= 2015
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
foreach zv in pseg pseg_l1 {
    * 在各自估计样本内标准化（同表8写法）
    capture drop zS
    quietly summarize `zv' if !missing(entry, Patient)
    generate double zS = (`zv' - r(mean)) / r(sd)
    forvalues k = 1/2 {
        local cond = cond(`k' == 1, "1", "d_muni == 0")
        reghdfe entry c.Patient#c.zS zS if `cond', absorb(fy fd dyr) vce(cluster firm)
        post R ("T8") ("`zv'") ("`k'") ("PxSeg") (_b[c.Patient#c.zS]) (_se[c.Patient#c.zS]) (2*ttail(e(df_r), abs(_b[c.Patient#c.zS]/_se[c.Patient#c.zS]))) (e(N)) (e(N_clust))
        post R ("T8") ("`zv'") ("`k'") ("Seg") (_b[zS]) (_se[zS]) (2*ttail(e(df_r), abs(_b[zS]/_se[zS]))) (e(N)) (e(N_clust))
    }
}

postclose R
use `res', clear
format b se p %12.6f
list, sepby(tab z) noobs
export delimited using "`EXP'/output/tables/ar75_prov_seg.csv", replace
log close ar75
