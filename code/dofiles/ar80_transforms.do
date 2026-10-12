*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar80_transforms.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十轮：调节变量常规变换，D-170）
* Purpose:  规则见本 exploration README 第四十轮（运行前写定）。
*           口径 r16、k15、k8h、k12l、k9w（当期）× 变换 w1、w5、ln、rk；
*           表7（1）全部、去北京总部；表8 第（1）（2）列、去北京目的地。其余设定同 ar75。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/prov_seg_20261010/表7_企业年份市场分割_<口径>.dta、表8_企业目的省年份市场分割_<口径>.dta
*           （r16 用第三十七轮修正版 _shfix；表8 r16 用未加后缀文件，与修正版内容相同）
* Outputs:  本 exploration 的 output/tables/ar80_transforms.csv
* Log:      explorations/advisor_revision_20261005/logs/ar80_transforms.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar80
log using "`EXP'/logs/ar80_transforms.log", name(ar80) replace text

local KL r16 k15 k8h k12l k9w
local TL w1 w5 ln rk
tempfile res
postfile R str3 tab str5 k str3 tr str6 smp double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份

* 变换：在给定样本（touse）内缩尾、取对数或年内百分位排序
capture program drop mkz
program define mkz
    args src tr touse
    capture drop ZZ
    if inlist("`tr'", "w1", "w5") {
        local lo = cond("`tr'" == "w1", 1, 5)
        local hi = 100 - `lo'
        _pctile `src' if `touse', percentiles(`lo' `hi')
        generate double ZZ = min(max(`src', r(r1)), r(r2)) if `touse' & !missing(`src')
    }
    if "`tr'" == "ln" generate double ZZ = ln(`src') if `touse'
    if "`tr'" == "rk" {
        tempvar rr nn
        bysort year: egen double `rr' = rank(`src') if `touse' & !missing(`src')
        bysort year: egen double `nn' = count(`rr')
        generate double ZZ = (`rr' - 1) / (`nn' - 1)
    }
end

*--- 1. 表7（1）：企业×年份 ---------------------------------------------------
foreach k of local KL {
    local f7 = cond("`k'" == "r16", "_shfix", "_`k'")
    use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
    merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割`f7'.dta", keep(master match) nogenerate
    egen long nid = group(id)
    xtset nid year
    egen long prov_year = group(母公司所在省份 year)
    * 首个样本年总部所在省（同 ar72）
    bysort nid (year): generate str30 hp0 = 母公司所在省份[1]
    generate byte bj0 = (hp0 == "北京市")
    foreach tr of local TL {
        foreach s in all nobj {
            capture drop touse
            generate byte touse = !missing(seg_pv, 跨省子公司数量占比, Patient) & (cond("`s'" == "all", 1, bj0 == 0))
            mkz seg_pv `tr' touse
            reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if touse, absorb(nid ind_year prov_year) vce(cluster nid)
            post R ("T7") ("`k'") ("`tr'") ("`s'") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(e(df_r), abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (e(N)) (e(N_clust))
        }
    }
}

*--- 2. 表8：企业×目的省×年份 -------------------------------------------------
foreach k of local KL {
    local f8 = cond("`k'" == "r16", "", "_`k'")
    use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
    merge 1:1 stkcd year dest using "data/derived/prov_seg_20261010/表8_企业目的省年份市场分割`f8'.dta", keep(master match)
    assert _merge == 3
    drop _merge
    keep if year >= 2015
    generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
    generate byte d_bj = (dest == "北京市")
    egen long fy   = group(stkcd year)
    egen long fd   = group(stkcd dest_id)
    egen long dyr  = group(dest_id year)
    egen long firm = group(stkcd)
    foreach tr of local TL {
        foreach s in c1 c2 nobjd {
            capture drop touse zS
            generate byte touse = !missing(pseg, entry, Patient) & (cond("`s'" == "c1", 1, cond("`s'" == "c2", d_muni == 0, d_bj == 0)))
            mkz pseg `tr' touse
            * 变换后在估计样本内标准化（同表8写法）
            quietly summarize ZZ if touse
            generate double zS = (ZZ - r(mean)) / r(sd)
            reghdfe entry c.Patient#c.zS zS if touse, absorb(fy fd dyr) vce(cluster firm)
            post R ("T8") ("`k'") ("`tr'") ("`s'") (_b[c.Patient#c.zS]) (_se[c.Patient#c.zS]) (2*ttail(e(df_r), abs(_b[c.Patient#c.zS]/_se[c.Patient#c.zS]))) (e(N)) (e(N_clust))
        }
    }
}

postclose R
use `res', clear
format b se p %12.7f
list, sepby(tab k) noobs
export delimited using "`EXP'/output/tables/ar80_transforms.csv", replace
log close ar80
