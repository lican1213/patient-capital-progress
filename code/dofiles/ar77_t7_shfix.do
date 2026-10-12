*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar77_t7_shfix.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十七轮：修正表7权重漏上海后复跑）
* Purpose:  ar75_build_prov_seg.py 原先在"省对字符串筛选"之后取目的城市集合，上海从权重中漏掉；
*           修正后另存 _shfix 文件（不覆盖原文件），复跑表7（1）：16 类、CPI 8 类，
*           当期、t−1、城市对当期，及剔除首年总部在北京 / 直辖市的企业。设定同 ar75、ar75b、ar76、ar76b。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           data/derived/prov_seg_20261010/表7_企业年份市场分割_shfix.dta、表7_企业年份市场分割_cpi8_shfix.dta
* Outputs:  本 exploration 的 output/tables/ar77_t7_shfix.csv
* Log:      explorations/advisor_revision_20261005/logs/ar77_t7_shfix.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar77
log using "`EXP'/logs/ar77_t7_shfix.log", name(ar77) replace text

tempfile res
postfile R str6 src str10 z str6 smp double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
foreach src in 16 cpi8 {
    local tag = cond("`src'" == "16", "_shfix", "_cpi8_shfix")
    use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
    merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割`tag'.dta", keep(master match) nogenerate
    egen long nid = group(id)
    xtset nid year
    egen long prov_year = group(母公司所在省份 year)
    * 首个样本年总部所在省（同 ar72）
    bysort nid (year): generate str30 hp0 = 母公司所在省份[1]
    generate byte bj0 = (hp0 == "北京市")
    generate byte muni0 = inlist(hp0, "北京市", "天津市", "上海市", "重庆市")
    local zl seg_pv seg_pv_l1
    if "`src'" == "16" local zl seg_city seg_pv seg_pv_l1
    foreach zv of local zl {
        foreach s in all nobj nomuni {
            if "`s'" != "all" & "`zv'" == "seg_city" continue
            local cond = cond("`s'" == "all", "1", cond("`s'" == "nobj", "bj0 == 0", "muni0 == 0"))
            capture drop ZZ
            generate double ZZ = `zv'
            reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if !missing(ZZ) & `cond', absorb(nid ind_year prov_year) vce(cluster nid)
            post R ("`src'") ("`zv'") ("`s'") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(e(df_r), abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (e(N)) (e(N_clust))
        }
    }
}
postclose R
use `res', clear
format b se p %12.7f
list, sepby(src z) noobs
export delimited using "`EXP'/output/tables/ar77_t7_shfix.csv", replace
log close ar77
