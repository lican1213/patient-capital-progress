*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar42_lmda_mech.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十二轮：自建 LMDA 的验证与机制回归，导师原规格）
* Purpose:  验证规则预登记见本 exploration README 第十二轮。
*           V1 覆盖率（按年）；V2 2014—2018 短视指标均值、中位数；
*           V3 研发投入占营业收入比例对短视指标（年份＋行业固定效应，企业聚类，12 个控制变量）；
*           V4 Patient 对 LMDA、LMDA30（企业＋行业×年份固定效应，企业聚类，12 个控制变量）。
* Inputs:   导师主面板；data/derived/advisor_revision_20261005/lmda.dta（ar41）
* Outputs:  本 exploration 的 output/tables/ar42_lmda.csv、ar42_desc.csv（LMDA 在 V4 回归样本上的描述统计，供表1）
* Log:      explorations/advisor_revision_20261005/logs/ar42_lmda_mech.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261007

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
local P "data/mentor_panel"
capture log close ar42
log using "`EXP'/logs/ar42_lmda_mech.log", name(ar42) replace text
which reghdfe

tempfile res dsc
postfile S str40 var long(N) double(mean sd min p50 max) using `dsc', replace
postfile R str12 item str12 var double(b se p) long(N) double(stat) using `res', replace
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数

use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
capture drop _merge
merge 1:1 stkcd year using "`D'/lmda.dta", keep(master match)
* V1 覆盖率
generate byte has = (_merge == 3)
drop _merge
quietly count
local Nall = r(N)
quietly count if has
post R ("V1") ("all") (r(N) / `Nall') (.) (.) (`Nall') (.)
forvalues y = 2014/2024 {
    quietly count if year == `y'
    local ny = r(N)
    quietly count if year == `y' & has
    post R ("V1") ("y`y'") (r(N) / `ny') (.) (.) (`ny') (.)
}
* V2 量级（2014—2018）
quietly summarize myopia if year <= 2018, detail
post R ("V2") ("mean") (r(mean)) (r(sd)) (r(p50)) (r(N)) (.)
quietly summarize mda_words if year <= 2018, detail
post R ("V2") ("words") (r(mean)) (r(sd)) (r(p50)) (r(N)) (.)
* V3 构念效度：研发强度对短视指标（原文写法：年份、行业固定效应，企业聚类）
reghdfe 研发投入占营业收入比例 myopia `C', absorb(year ind) vce(cluster id)
post R ("V3") ("myopia") (_b[myopia]) (_se[myopia]) (2*ttail(e(df_r), abs(_b[myopia]/_se[myopia]))) (e(N)) (e(r2_a))
* V4 机制：Patient 对 LMDA（导师原规格）
foreach v in LMDA LMDA30 {
    reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    if "`v'" == "LMDA" {
        * 第一版文本的结果另存于 ar42_lmda_v1_未验收.csv，第十四轮抽取修正后重跑，系数不再与之一致
        quietly summarize LMDA if e(sample), detail
        post S ("LMDA") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
    }
    post R ("V4") ("`v'") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N)) (e(r2_a))
}
* 第二步（附表2口径）：跨省子公司数量占比对 Patient 与 LMDA
reghdfe 跨省子公司数量占比 Patient LMDA `C', absorb(id ind_year) vce(cluster id)
post R ("S2") ("Patient") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N)) (e(r2_a))
post R ("S2") ("LMDA") (_b[LMDA]) (_se[LMDA]) (2*ttail(e(df_r), abs(_b[LMDA]/_se[LMDA]))) (e(N)) (e(r2_a))
quietly summarize LMDA if !missing(Patient), detail
post R ("D") ("LMDA") (r(mean)) (r(sd)) (r(p50)) (r(N)) (r(max))

postclose R
postclose S
use `res', clear
format b se p stat %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar42_lmda.csv", replace
use `dsc', clear
export delimited using "`EXP'/output/tables/ar42_desc.csv", replace
log close ar42
