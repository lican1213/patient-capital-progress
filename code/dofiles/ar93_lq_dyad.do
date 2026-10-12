*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar93_lq_dyad.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮第四步：区位熵“优优结合”的双边交互写法）
* Purpose:  规则见本 exploration README 第四十八轮第四步（运行前写定）。
*           母公司所在省与目的省的同行业区位熵均取样本期前（2010—2013）同一口径，
*           按母公司区位熵分组，检验耐心资本是否更偏向同行业集聚的目的省。
* Inputs:   16 号主面板3；21 号表8新版变量（本步不用其变量，仅保持样本一致）；
*           data/derived/advisor_revision_20261005/dyad_lq.dta；导师主面板1（首年母公司所在省份）
* Outputs:  本 exploration 的 output/tables/ar93_lq_dyad.csv
* Log:      explorations/advisor_revision_20261005/logs/ar93_lq_dyad.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
local P16 "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
capture log close ar93
log using "`EXP'/logs/ar93_lq_dyad.log", name(ar93) replace text

*--- 1. 母公司所在省的同行业区位熵（与目的省同一口径）------------------------
use dest dest_id using "`P16'", clear
duplicates drop
rename (dest dest_id) (home_prov home_id)
tempfile dmap
save `dmap'

use stkcd year 母公司所在省份 using "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
bysort stkcd (year): keep if _n == 1
rename 母公司所在省份 home_prov
merge m:1 home_prov using `dmap', keep(master match)
tab _merge
drop _merge
rename home_id dest_id
merge 1:1 stkcd dest_id using "data/derived/advisor_revision_20261005/dyad_lq.dta", keep(master match) keepusing(lq)
tab _merge
drop _merge
rename lq home_lq
keep stkcd home_lq
summarize home_lq, detail
local m0 = r(p50)
generate byte hH  = (home_lq >= `m0') if !missing(home_lq)
generate byte hG1 = (home_lq > 1) if !missing(home_lq)
tab hH hG1
tempfile hl
save `hl'

*--- 2. 双边面板与设定（同新表8）---------------------------------------------
use "`P16'", clear
merge m:1 stkcd using `hl', keep(master match) nogenerate
generate byte d_bj = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate byte es = year >= 2015 & !missing(entry, Patient)
quietly summarize lq if es, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
quietly summarize lqw if es
generate double z_lq = (lqw - r(mean)) / r(sd)
generate byte dG1 = (lq > 1) if !missing(lq)
generate double PxLq = Patient * z_lq
generate double PxD1 = Patient * dG1

tempfile res
postfile R str8 blk str8 term double(b se p) long(N nclust) using `res', replace
* (c) 全样本参照
quietly reghdfe entry PxLq if es, absorb(fy fd dyr) vce(cluster firm)
post R ("all") ("PxLq") (1000*_b[PxLq]) (1000*_se[PxLq]) (2*ttail(e(df_r), abs(_b[PxLq]/_se[PxLq]))) (e(N)) (e(N_clust))

* 主检验与 (b)(d)(e)：分组回归 + 堆叠差异
foreach t in main b d e {
    local G hH
    local X PxLq
    local IF "es"
    local VC "cluster firm"
    if "`t'" == "b" {
        local G hG1
        local X PxD1
    }
    if "`t'" == "d" local IF "es & d_bj == 0"
    if "`t'" == "e" local VC "cluster firm dest_id"
    foreach k in 1 0 {
        quietly reghdfe entry `X' if `IF' & `G' == `k', absorb(fy fd dyr) vce(`VC')
        post R ("`t'") ("grp`k'") (1000*_b[`X']) (1000*_se[`X']) (2*ttail(e(df_r), abs(_b[`X']/_se[`X']))) (e(N)) (e(N_clust))
    }
    capture drop gg
    generate byte gg = `G' if `IF'
    quietly reghdfe entry c.`X'#i.gg if !missing(gg), absorb(fy fd#gg dyr#gg) vce(`VC')
    quietly test 1.gg#c.`X' = 0.gg#c.`X'
    post R ("`t'") ("diff") (1000*(_b[1.gg#c.`X'] - _b[0.gg#c.`X'])) (.) (r(p)) (e(N)) (e(N_clust))
}
postclose R
use `res', clear
format b se %9.4f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar93_lq_dyad.csv", replace
log close ar93
