*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar85b_rank_distinct.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十五轮核查补充：百分位改在当年不重复数值上计算）
* Purpose:  规则见本 exploration README 第四十五轮末条。其余同 ar85_t8_timevary.do。
* Inputs:   16 号主面板3；data/derived/advisor_send_20261008/20_表8时变变量.dta、目的省研发资源_逐年.dta 已并入 20 号
* Outputs:  本 exploration 的 output/tables/ar85b_rank_distinct.csv
* Log:      explorations/advisor_revision_20261005/logs/ar85b_rank_distinct.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar85b
log using "`EXP'/logs/ar85b_rank_distinct.log", name(ar85b) replace text

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "data/derived/advisor_send_20261008/20_表8时变变量.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate byte es = year >= 2015 & !missing(entry, Patient)

* 当年不重复数值上的百分位
* 每个“年份×数值”只标一条估计样本内的观测（首次运行用 _n==1 会标到样本外观测，已改）
egen byte tag = tag(year seg_m3l) if es & !missing(seg_m3l)
bysort year: egen double rkd = rank(seg_m3l) if tag == 1
bysort year: egen double cnd = count(seg_m3l) if tag == 1
generate double segd0 = (rkd - 1) / (cnd - 1)
bysort year seg_m3l: egen double segd = max(segd0) if es & !missing(seg_m3l)
tabstat segd if es, by(year) statistics(min max n)

quietly summarize rd_l1 if es
generate double z_rd_l1 = (rd_l1 - r(mean)) / r(sd)
generate double PxSeg  = Patient * segd
generate double PxRd   = Patient * z_rd_l1
generate double PxDist = Patient * lndist

tempfile res
postfile R byte col str6 var double(b se p) long N using `res', replace
reghdfe entry PxSeg segd if es, absorb(fy fd dyr) vce(cluster firm)
post R (1) ("PxSeg") (_b[PxSeg]) (_se[PxSeg]) (2*ttail(e(df_r), abs(_b[PxSeg]/_se[PxSeg]))) (e(N))
reghdfe entry PxSeg segd if es & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
post R (2) ("PxSeg") (_b[PxSeg]) (_se[PxSeg]) (2*ttail(e(df_r), abs(_b[PxSeg]/_se[PxSeg]))) (e(N))
reghdfe entry PxSeg segd PxRd PxDist if es, absorb(fy fd dyr) vce(cluster firm)
post R (8) ("PxSeg") (_b[PxSeg]) (_se[PxSeg]) (2*ttail(e(df_r), abs(_b[PxSeg]/_se[PxSeg]))) (e(N))
postclose R
use `res', clear
list, noobs
export delimited using "`EXP'/output/tables/ar85b_rank_distinct.csv", replace
log close ar85b
