*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar78_seg_variants.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十八轮：市场分割换做法续试，D-170）
* Purpose:  规则见本 exploration README 第三十八轮（运行前写定）。
*           四种口径 r3、r3l、nb、nbr3 × 两种价格数据 r16、c8；
*           表7（1）：全部、剔除首年总部在北京；表8：全部、剔除直辖市目的地、剔除北京目的地。设定同 ar75。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/prov_seg_20261010/表7_变体_ar78.dta、表8_变体_ar78.dta
* Outputs:  本 exploration 的 output/tables/ar78_seg_variants.csv
* Log:      explorations/advisor_revision_20261005/logs/ar78_seg_variants.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar78
log using "`EXP'/logs/ar78_seg_variants.log", name(ar78) replace text

local ZL r3_r16 r3l_r16 nb_r16 nbr3_r16 r3_c8 r3l_c8 nb_c8 nbr3_c8
tempfile res
postfile R str3 tab str10 z str6 smp double(b se p) long(N nclust) int(y0 y1) using `res', replace

*--- 1. 表7（1）：企业×年份 ---------------------------------------------------
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_变体_ar78.dta", keep(master match) nogenerate
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
* 首个样本年总部所在省（同 ar72）
bysort nid (year): generate str30 hp0 = 母公司所在省份[1]
generate byte bj0 = (hp0 == "北京市")
foreach zv of local ZL {
    foreach s in all nobj {
        local cond = cond("`s'" == "all", "1", "bj0 == 0")
        capture drop ZZ
        generate double ZZ = `zv'
        reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if !missing(ZZ) & `cond', absorb(nid ind_year prov_year) vce(cluster nid)
        quietly summarize year if e(sample)
        post R ("T7") ("`zv'") ("`s'") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(e(df_r), abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (e(N)) (e(N_clust)) (r(min)) (r(max))
    }
}

*--- 2. 表8：企业×目的省×年份 -------------------------------------------------
use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd year dest using "data/derived/prov_seg_20261010/表8_变体_ar78.dta", keep(master match)
assert _merge == 3
drop _merge
keep if year >= 2015
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
foreach zv of local ZL {
    * 在估计样本内标准化（同表8写法）；相邻法口径为目的省层面，水平项被目的省×年份固定效应吸收
    capture drop zS
    quietly summarize `zv' if !missing(entry, Patient)
    generate double zS = (`zv' - r(mean)) / r(sd)
    foreach s in c1 c2 nobjd {
        local cond = cond("`s'" == "c1", "1", cond("`s'" == "c2", "d_muni == 0", "d_bj == 0"))
        reghdfe entry c.Patient#c.zS zS if `cond', absorb(fy fd dyr) vce(cluster firm)
        quietly summarize year if e(sample)
        post R ("T8") ("`zv'") ("`s'") (_b[c.Patient#c.zS]) (_se[c.Patient#c.zS]) (2*ttail(e(df_r), abs(_b[c.Patient#c.zS]/_se[c.Patient#c.zS]))) (e(N)) (e(N_clust)) (r(min)) (r(max))
    }
}

postclose R
use `res', clear
format b se p %12.7f
list, sepby(tab z) noobs
export delimited using "`EXP'/output/tables/ar78_seg_variants.csv", replace
log close ar78
