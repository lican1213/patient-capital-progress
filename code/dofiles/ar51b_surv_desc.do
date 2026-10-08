*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar51b_surv_desc.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十八轮）
* Purpose:  存续四个变量在当期写法估计样本上的描述性统计（新表表1 用）。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta
* Outputs:  本 exploration 的 output/tables/ar51b_surv_desc.csv
* Log:      explorations/advisor_revision_20261005/logs/ar51b_surv_desc.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
local EXP "explorations/advisor_revision_20261005"
capture log close ar51b
log using "`EXP'/logs/ar51b_surv_desc.log", name(ar51b) replace text
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
use "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta", clear
tempfile d
postfile Q str10 var long(N) double(mean sd min p50 max) using `d', replace
local k = 0
foreach v in cross_surv3_num cross_surv3_rate cross_surv5_num cross_surv5_rate {
    local ++k
    local lab : word `k' of DuNum3 DuRate3 DuNum5 DuRate5
    local yy = cond(strpos("`v'", "surv3"), 2021, 2019)
    quietly reghdfe `v' Patient `C' if 跨省子公司数量 > 0 & year <= `yy', absorb(id ind_year) vce(cluster id)
    quietly summarize `v' if e(sample), detail
    post Q ("`lab'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
}
postclose Q
use `d', clear
list, noobs
export delimited using "`EXP'/output/tables/ar51b_surv_desc.csv", replace
log close ar51b
