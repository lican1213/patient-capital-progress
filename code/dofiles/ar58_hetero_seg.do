*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar58_hetero_seg.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十二轮：表7 第（1）列换成基期市场分割）
* Purpose:  规则见本 exploration README 第二十二轮（运行前写定）。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta
* Outputs:  本 exploration 的 output/tables/ar58_hetero_seg.csv
* Log:      explorations/advisor_revision_20261005/logs/ar58_hetero_seg.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar58
log using "`EXP'/logs/ar58_hetero_seg.log", name(ar58) replace text
which reghdfe

tempfile res
postfile R str3 spec str2 tm str6 var double(b se p) long(N nclust) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta", clear
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
generate double Lp = L.Patient
summarize 母公司异地市场分割 l母公司异地市场一体化, detail
correlate 母公司异地市场分割 l母公司异地市场一体化
bysort nid (year): egen fy = min(cond(!missing(母公司异地市场分割), year, .))
bysort nid (year): egen Z = max(cond(year == fy, 母公司异地市场分割, .))
* 企业层面百分位秩（每家企业只计一次）
egen byte tg = tag(nid) if !missing(Z)
egen double rk = rank(Z) if tg == 1
quietly count if tg == 1
generate double Zr = rk / r(N)
bysort nid (Zr): replace Zr = Zr[1]
foreach s in S1 S2 {
    capture drop ZZ
    generate double ZZ = cond("`s'" == "S1", Z, Zr)
    foreach t in P0 P1 {
        local X = cond("`t'" == "P0", "Patient", "Lp")
        reghdfe 跨省子公司数量占比 c.`X'##c.ZZ `C' if year > fy & !missing(ZZ), absorb(nid ind_year prov_year) vce(cluster nid)
        local NN = e(N)
        local NC = e(N_clust)
        local dfr = e(df_r)
        post R ("`s'") ("`t'") ("X") (_b[`X']) (_se[`X']) (2*ttail(`dfr', abs(_b[`X']/_se[`X']))) (`NN') (`NC')
        post R ("`s'") ("`t'") ("XxZ") (_b[c.`X'#c.ZZ]) (_se[c.`X'#c.ZZ]) (2*ttail(`dfr', abs(_b[c.`X'#c.ZZ]/_se[c.`X'#c.ZZ]))) (`NN') (`NC')
        quietly summarize ZZ if e(sample), detail
        local z25 = r(p25)
        local z50 = r(p50)
        local z75 = r(p75)
        foreach q in 25 50 75 {
            quietly lincom `X' + `z`q''*c.`X'#c.ZZ
            post R ("`s'") ("`t'") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN') (`NC')
        }
    }
}
postclose R
use `res', clear
format b se p %12.6f
list, sepby(spec tm) noobs
export delimited using "`EXP'/output/tables/ar58_hetero_seg.csv", replace
log close ar58
