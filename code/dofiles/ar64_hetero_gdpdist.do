*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar64_hetero_gdpdist.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十六轮：表7 第（1）列改用 GDP/距离加权、全部外省城市、固定基期口径）
* Purpose:  规则见本 exploration README 第二十六轮（运行前写定）。权重＝目的城市2014年GDP÷距离，分配到全部外省城市。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta；
*           data/derived/advisor_send_20261008/企业基期市场分割GDP距离加权.dta
* Outputs:  本 exploration 的 output/tables/ar64_hetero_gdpdist.csv
* Log:      explorations/advisor_revision_20261005/logs/ar64_hetero_gdpdist.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar64
log using "`EXP'/logs/ar64_hetero_gdpdist.log", name(ar64) replace text
which reghdfe

tempfile res
postfile R str10 z str2 tm str6 var double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta", clear
merge m:1 stkcd using "data/derived/advisor_send_20261008/企业基期市场分割GDP距离加权.dta", keep(master match) nogenerate
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
generate double Lp = L.Patient
bysort nid: egen int fy0 = min(year)
* 与面板原变量的相关（企业首个样本年）
correlate linteg_gd0 seg_gd0 l母公司异地市场一体化 母公司异地市场分割 Seg_ext_2014 if year == fy0
foreach zv in seg_gd0 linteg_gd0 {
    * 2010—2013 基期在样本期前，用全部年份；首个样本年基期只用其后年份
    local cond = cond(strpos("`zv'", "fy"), "year > fy0", "1")
    foreach t in P0 P1 {
        local X = cond("`t'" == "P0", "Patient", "Lp")
        capture drop ZZ
        generate double ZZ = `zv'
        reghdfe 跨省子公司数量占比 c.`X'##c.ZZ `C' if `cond' & !missing(ZZ), absorb(nid ind_year prov_year) vce(cluster nid)
        local NN = e(N)
        local NC = e(N_clust)
        local dfr = e(df_r)
        post R ("`zv'") ("`t'") ("X") (_b[`X']) (_se[`X']) (2*ttail(`dfr', abs(_b[`X']/_se[`X']))) (`NN') (`NC')
        post R ("`zv'") ("`t'") ("XxZ") (_b[c.`X'#c.ZZ]) (_se[c.`X'#c.ZZ]) (2*ttail(`dfr', abs(_b[c.`X'#c.ZZ]/_se[c.`X'#c.ZZ]))) (`NN') (`NC')
        quietly summarize ZZ if e(sample), detail
        local z25 = r(p25)
        local z50 = r(p50)
        local z75 = r(p75)
        foreach q in 25 50 75 {
            quietly lincom `X' + `z`q''*c.`X'#c.ZZ
            post R ("`zv'") ("`t'") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN') (`NC')
        }
    }
}
postclose R
use `res', clear
format b se p %12.6f
list, sepby(z tm) noobs
export delimited using "`EXP'/output/tables/ar64_hetero_gdpdist.csv", replace
log close ar64
