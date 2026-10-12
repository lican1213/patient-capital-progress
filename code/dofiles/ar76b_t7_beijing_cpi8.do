*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar76b_t7_beijing_cpi8.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十六轮：沿用 ar72 规则的北京、直辖市检验）
* Purpose:  表7（1）省级逐年市场分割（导师权重），剔除首年总部在北京 / 直辖市的企业。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta；
*           data/derived/prov_seg_20261010/表7_企业年份市场分割_cpi8.dta
* Outputs:  本 exploration 的 output/tables/ar76b_t7_beijing_cpi8.csv
* Log:      explorations/advisor_revision_20261005/logs/ar76b_t7_beijing_cpi8.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar76b
log using "`EXP'/logs/ar76b_t7_beijing_cpi8.log", name(ar76b) replace text

tempfile res
postfile R str10 z str6 smp double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割_cpi8.dta", keep(master match) nogenerate
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
* 首个样本年总部所在省（同 ar72）
bysort nid (year): generate str30 hp0 = 母公司所在省份[1]
generate byte bj0 = (hp0 == "北京市")
generate byte muni0 = inlist(hp0, "北京市", "天津市", "上海市", "重庆市")
foreach zv in seg_pv seg_pv_l1 {
    foreach s in nobj nomuni {
        local cond = cond("`s'" == "nobj", "bj0 == 0", "muni0 == 0")
        capture drop ZZ
        generate double ZZ = `zv'
        reghdfe 跨省子公司数量占比 c.Patient##c.ZZ `C' if !missing(ZZ) & `cond', absorb(nid ind_year prov_year) vce(cluster nid)
        post R ("`zv'") ("`s'") (_b[c.Patient#c.ZZ]) (_se[c.Patient#c.ZZ]) (2*ttail(e(df_r), abs(_b[c.Patient#c.ZZ]/_se[c.Patient#c.ZZ]))) (e(N)) (e(N_clust))
    }
}
postclose R
use `res', clear
format b se p %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar76b_t7_beijing_cpi8.csv", replace
log close ar76b
