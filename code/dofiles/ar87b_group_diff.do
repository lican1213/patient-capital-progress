*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar87b_group_diff.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十六轮 B 第二步：导师分组的组间差异检验）
* Purpose:  规则见本 exploration README 第四十六轮 B。导师原写法 S1（12 个控制、absorb(id year)、企业聚类）已逐格复现稿中数字（ar87）。
*           堆叠回归：各组样本各复制一份，固定效应与全部回归元按组交互，企业聚类（东到中西、中西到东两组有重叠，聚类可处理）。
*           先核对堆叠后的组内系数与分组回归一致，再检验 Patient 系数之差。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta
* Outputs:  本 exploration 的 output/tables/ar87b_group_diff.csv
* Log:      explorations/advisor_revision_20261005/logs/ar87b_group_diff.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar87b
log using "`EXP'/logs/ar87b_group_diff.log", name(ar87b) replace text

local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
keep id year Patient 跨省子公司数量占比 `C' LQ_type reg_sample 东到中西次数 中西到东次数
tempfile base
save `base'

tempfile res
postfile R str6 blk str12 test double(est se p) long N using `res', replace

* ---------- 区位熵四组（互不重叠）----------
use `base', clear
keep if reg_sample == 1 & inrange(LQ_type, 1, 4)
generate byte g = LQ_type
* 先跑分组回归记下系数
forvalues k = 1/4 {
    quietly reghdfe 跨省子公司数量占比 Patient `C' if g == `k', absorb(id year) vce(cluster id)
    local b`k' = _b[Patient]
}
egen long idg = group(id g)
egen long yg  = group(year g)
local GC ""
foreach v in Patient `C' {
    forvalues k = 1/4 {
        generate double `v'_`k' = `v' * (g == `k')
    }
}
local X ""
foreach v in Patient `C' {
    forvalues k = 1/4 {
        local X `X' `v'_`k'
    }
}
reghdfe 跨省子公司数量占比 `X', absorb(idg yg) vce(cluster id)
forvalues k = 1/4 {
    assert abs(_b[Patient_`k'] - `b`k'') < 1e-8
    post R ("LQ") ("b`k'") (_b[Patient_`k']) (_se[Patient_`k']) (2*ttail(e(df_r), abs(_b[Patient_`k']/_se[Patient_`k']))) (e(N))
}
foreach pr in "1 2" "1 3" "1 4" "2 3" "2 4" "3 4" {
    local a : word 1 of `pr'
    local c : word 2 of `pr'
    lincom Patient_`a' - Patient_`c'
    post R ("LQ") ("d`a'_`c'") (r(estimate)) (r(se)) (r(p)) (e(N))
}
test Patient_1 = Patient_2 = Patient_3 = Patient_4
post R ("LQ") ("joint4") (.) (.) (r(p)) (e(N))
* 两端（强化、低优势）对中间（扩张、获取）
lincom (Patient_1 + Patient_4)/2 - (Patient_2 + Patient_3)/2
post R ("LQ") ("ends_mid") (r(estimate)) (r(se)) (r(p)) (e(N))

* ---------- 东到中西 vs 中西到东（有重叠）----------
use `base', clear
quietly reghdfe 跨省子公司数量占比 Patient `C' if 东到中西次数 != 0, absorb(id year) vce(cluster id)
local bEW = _b[Patient]
quietly reghdfe 跨省子公司数量占比 Patient `C' if 中西到东次数 != 0, absorb(id year) vce(cluster id)
local bWE = _b[Patient]
preserve
keep if 东到中西次数 != 0
generate byte g = 1
tempfile ew
save `ew'
restore
keep if 中西到东次数 != 0
generate byte g = 2
append using `ew'
tabulate g
egen long idg = group(id g)
egen long yg  = group(year g)
local X ""
foreach v in Patient `C' {
    forvalues k = 1/2 {
        generate double `v'_`k' = `v' * (g == `k')
        local X `X' `v'_`k'
    }
}
reghdfe 跨省子公司数量占比 `X', absorb(idg yg) vce(cluster id)
assert abs(_b[Patient_1] - `bEW') < 1e-8 & abs(_b[Patient_2] - `bWE') < 1e-8
post R ("EW") ("b_EW") (_b[Patient_1]) (_se[Patient_1]) (2*ttail(e(df_r), abs(_b[Patient_1]/_se[Patient_1]))) (e(N))
post R ("EW") ("b_WE") (_b[Patient_2]) (_se[Patient_2]) (2*ttail(e(df_r), abs(_b[Patient_2]/_se[Patient_2]))) (e(N))
lincom Patient_2 - Patient_1
post R ("EW") ("dWE_EW") (r(estimate)) (r(se)) (r(p)) (e(N))
* 两组重叠的观测数
duplicates tag id year, generate(both)
count if both > 0 & g == 1
post R ("EW") ("overlap_obs") (r(N)) (.) (.) (e(N))

postclose R
use `res', clear
format est se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar87b_group_diff.csv", replace
log close ar87b
