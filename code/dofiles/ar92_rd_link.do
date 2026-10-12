*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar92_rd_link.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮第三步：研发与表8 连起来）
* Purpose:  规则见本 exploration README 第四十八轮第三步（运行前写定）。
*           新表8 第（5）列（Patient×目的省当年研发资源）按企业研发强弱分样本，检验两组差。
* Inputs:   deliverables/advisor_package_20261007/表8新版_20261012/（16 号见 稳健性异质性去向_20261009/）
*           data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta（企业研发强度）
* Outputs:  本 exploration 的 output/tables/ar92_rd_link.csv
* Log:      explorations/advisor_revision_20261005/logs/ar92_rd_link.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar92
log using "`EXP'/logs/ar92_rd_link.log", name(ar92) replace text

*--- 1. 企业研发分组（与表7 同一变量）---------------------------------------
use stkcd year 研发投入占营业收入比例 using "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
rename 研发投入占营业收入比例 rdint
duplicates report stkcd year
* R1：分年中位数，≥ 为高组（同表7）
bysort year: egen double md = median(rdint)
generate byte hiR1 = (rdint >= md) if !missing(rdint)
* R2：企业首个有数据年份的研发强度（固定），企业间中位数分组
bysort stkcd (year): egen fy0 = min(cond(!missing(rdint), year, .))
bysort stkcd (year): egen double rd0 = max(cond(year == fy0, rdint, .))
preserve
keep stkcd rd0
duplicates drop
quietly summarize rd0, detail
local m0 = r(p50)
restore
generate byte hiR2 = (rd0 >= `m0') if !missing(rd0)
keep stkcd year hiR1 hiR2
tempfile rdg
save `rdg'

*--- 2. 表8 数据与设定（同表8命令_新版）-------------------------------------
use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "deliverables/advisor_package_20261007/表8新版_20261012/21_表8新版变量.dta", keep(master match) nogenerate
merge m:1 stkcd year using `rdg', keep(master match) nogenerate
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate byte es = year >= 2015 & !missing(entry, Patient)
quietly summarize rd_t if es
generate double z_rd_t = (rd_t - r(mean)) / r(sd)
generate double PxRd = Patient * z_rd_t

tempfile res
postfile R str6 g str8 term double(b se p) long(N nclust) using `res', replace
* 全样本参照（应与新表8 第（5）列一致）
quietly reghdfe entry PxRd if es, absorb(fy fd dyr) vce(cluster firm)
post R ("all") ("PxRd") (1000*_b[PxRd]) (1000*_se[PxRd]) (2*ttail(e(df_r), abs(_b[PxRd]/_se[PxRd]))) (e(N)) (e(N_clust))
foreach h in hiR1 hiR2 {
    tab `h' if es, missing
    foreach k in 1 0 {
        quietly reghdfe entry PxRd if es & `h' == `k', absorb(fy fd dyr) vce(cluster firm)
        post R ("`h'") ("grp`k'") (1000*_b[PxRd]) (1000*_se[PxRd]) (2*ttail(e(df_r), abs(_b[PxRd]/_se[PxRd]))) (e(N)) (e(N_clust))
    }
    * 堆叠全交互，检验高、低两组之差
    capture drop gg
    generate byte gg = `h' if es
    quietly reghdfe entry c.PxRd#i.gg if !missing(gg), absorb(fy fd#gg dyr#gg) vce(cluster firm)
    quietly test 1.gg#c.PxRd = 0.gg#c.PxRd
    post R ("`h'") ("diff") (1000*(_b[1.gg#c.PxRd] - _b[0.gg#c.PxRd])) (.) (r(p)) (e(N)) (e(N_clust))
}
postclose R
use `res', clear
format b se %9.4f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar92_rd_link.csv", replace
log close ar92
