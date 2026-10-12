*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar79_goods_subsets.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十九轮：按近年文献的商品类别重测，D-170）
* Purpose:  规则见本 exploration README 第三十九轮（运行前写定）。
*           口径 k15、k8h、k12l、k9w（文献依据）与 k13（作者设想，无文献依据，只作对照）；
*           表7（1）当期、t−1，全部与去北京总部；表8 当期、t−1，第（1）（2）列与去北京目的地。设定同 ar75。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/prov_seg_20261010/表7_企业年份市场分割_<口径>.dta、表8_企业目的省年份市场分割_<口径>.dta
* Outputs:  本 exploration 的 output/tables/ar79_goods_subsets.csv
* Log:      explorations/advisor_revision_20261005/logs/ar79_goods_subsets.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar79
log using "`EXP'/logs/ar79_goods_subsets.log", name(ar79) replace text

local KL k15 k8h k12l k9w k13
tempfile res
postfile R str3 tab str5 k str10 z str6 smp double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份

*--- 1. 表7（1）：企业×年份 ---------------------------------------------------
foreach k of local KL {
    use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
    merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割_`k'.dta", keep(master match) nogenerate
    egen long nid = group(id)
    xtset nid year
    egen long prov_year = group(母公司所在省份 year)
    * 首个样本年总部所在省（同 ar72）
    bysort nid (year): generate str30 hp0 = 母公司所在省份[1]
    generate byte bj0 = (hp0 == "北京市")
    foreach zv in seg_pv seg_pv_l1 {
        foreach s in all nobj {
            local cond = cond("`s'" == "all", "1", "bj0 == 0")
            capture drop ZZ
            generate double ZZ = `zv'
            reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if !missing(ZZ) & `cond', absorb(nid ind_year prov_year) vce(cluster nid)
            post R ("T7") ("`k'") ("`zv'") ("`s'") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(e(df_r), abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (e(N)) (e(N_clust))
        }
    }
}

*--- 2. 表8：企业×目的省×年份 -------------------------------------------------
foreach k of local KL {
    use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
    merge 1:1 stkcd year dest using "data/derived/prov_seg_20261010/表8_企业目的省年份市场分割_`k'.dta", keep(master match)
    assert _merge == 3
    drop _merge
    keep if year >= 2015
    generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
    generate byte d_bj = (dest == "北京市")
    egen long fy   = group(stkcd year)
    egen long fd   = group(stkcd dest_id)
    egen long dyr  = group(dest_id year)
    egen long firm = group(stkcd)
    foreach zv in pseg pseg_l1 {
        * 在估计样本内标准化（同表8写法）
        capture drop zS
        quietly summarize `zv' if !missing(entry, Patient)
        generate double zS = (`zv' - r(mean)) / r(sd)
        foreach s in c1 c2 nobjd {
            local cond = cond("`s'" == "c1", "1", cond("`s'" == "c2", "d_muni == 0", "d_bj == 0"))
            reghdfe entry c.Patient#c.zS zS if `cond', absorb(fy fd dyr) vce(cluster firm)
            post R ("T8") ("`k'") ("`zv'") ("`s'") (_b[c.Patient#c.zS]) (_se[c.Patient#c.zS]) (2*ttail(e(df_r), abs(_b[c.Patient#c.zS]/_se[c.Patient#c.zS]))) (e(N)) (e(N_clust))
        }
    }
}

postclose R
use `res', clear
format b se p %12.7f
list, sepby(tab k) noobs
export delimited using "`EXP'/output/tables/ar79_goods_subsets.csv", replace
log close ar79
