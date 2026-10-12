*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar92b_rd_link_robust.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮第三步补充：R2 分组的稳健性、表7 研发列同口径）
* Purpose:  规则见本 exploration README 第四十八轮“第三步补充”（运行前写定）。
* Inputs:   同 ar92_rd_link.do
* Outputs:  本 exploration 的 output/tables/ar92b_rd_link_robust.csv
* Log:      explorations/advisor_revision_20261005/logs/ar92b_rd_link_robust.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar92b
log using "`EXP'/logs/ar92b_rd_link_robust.log", name(ar92b) replace text

tempfile res
postfile R str8 tab str8 smp str8 term double(b se p) long(N nclust) using `res', replace

*--- 1. 表7 研发列：R2 分组（企业首个有数据年份的研发强度）------------------
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
local C11 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local Y 跨省子公司数量占比
egen long nid = group(id)
bysort nid (year): egen fy0 = min(cond(!missing(研发投入占营业收入比例), year, .))
bysort nid (year): egen double rd0 = max(cond(year == fy0, 研发投入占营业收入比例, .))
preserve
keep nid rd0
duplicates drop
quietly summarize rd0, detail
local m0 = r(p50)
restore
generate byte hiR2 = (rd0 >= `m0') if !missing(rd0)
bysort nid (year): generate str20 prov0 = 母公司所在省份[1]
generate byte bj0 = (prov0 == "北京市")
foreach k in 1 0 {
    quietly reghdfe `Y' Patient `C11' if hiR2 == `k', absorb(nid ind_year) vce(cluster id)
    post R ("T7") ("all") ("grp`k'") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N)) (e(N_clust))
}
generate byte gg = hiR2
quietly reghdfe `Y' c.(Patient `C11')#i.gg if !missing(gg), absorb(nid#gg ind_year#gg) vce(cluster id)
quietly test 1.gg#c.Patient = 0.gg#c.Patient
post R ("T7") ("all") ("diff_stk") (_b[1.gg#c.Patient] - _b[0.gg#c.Patient]) (.) (r(p)) (e(N)) (e(N_clust))
quietly summarize Patient if !missing(gg)
generate double cP = Patient - r(mean)
generate byte lowg = 1 - gg
generate double cPxL = cP * lowg
quietly reghdfe `Y' cP lowg cPxL `C11' if !missing(gg), absorb(nid ind_year) vce(cluster id)
post R ("T7") ("all") ("diff_tpl") (_b[cPxL]) (_se[cPxL]) (2*ttail(e(df_r), abs(_b[cPxL]/_se[cPxL]))) (e(N)) (e(N_clust))
* 供表8 使用的企业分组与北京首年总部
keep stkcd year hiR2 bj0
tempfile rdg
save `rdg'

*--- 2. 表8（5）R2 分组的稳健性 ---------------------------------------------
use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "deliverables/advisor_package_20261007/表8新版_20261012/21_表8新版变量.dta", keep(master match) nogenerate
merge m:1 stkcd year using `rdg', keep(master match) nogenerate
* 上一年耐心资本：企业×年份层面错开一年
preserve
keep stkcd year Patient
duplicates drop stkcd year, force
replace year = year + 1
rename Patient LPatient
tempfile lp
save `lp'
restore
merge m:1 stkcd year using `lp', keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj   = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate byte es = year >= 2015 & !missing(entry, Patient)
quietly summarize rd_t if es
generate double z_rd_t = (rd_t - r(mean)) / r(sd)
generate double PxRd  = Patient * z_rd_t
generate double LPxRd = LPatient * z_rd_t

foreach s in nobjd nomuni twoway lagP nobj0 {
    local X PxRd
    local IF "es"
    local VC "cluster firm"
    if "`s'" == "nobjd"  local IF "es & d_bj == 0"
    if "`s'" == "nomuni" local IF "es & d_muni == 0"
    if "`s'" == "twoway" local VC "cluster firm dest_id"
    if "`s'" == "lagP"   local X LPxRd
    if "`s'" == "nobj0"  local IF "es & bj0 == 0"
    foreach k in 1 0 {
        quietly reghdfe entry `X' if `IF' & hiR2 == `k', absorb(fy fd dyr) vce(`VC')
        post R ("T8") ("`s'") ("grp`k'") (1000*_b[`X']) (1000*_se[`X']) (2*ttail(e(df_r), abs(_b[`X']/_se[`X']))) (e(N)) (e(N_clust))
    }
    capture drop gg
    generate byte gg = hiR2 if `IF'
    quietly reghdfe entry c.`X'#i.gg if !missing(gg), absorb(fy fd#gg dyr#gg) vce(`VC')
    quietly test 1.gg#c.`X' = 0.gg#c.`X'
    post R ("T8") ("`s'") ("diff") (1000*(_b[1.gg#c.`X'] - _b[0.gg#c.`X'])) (.) (r(p)) (e(N)) (e(N_clust))
}

postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar92b_rd_link_robust.csv", replace
log close ar92b
