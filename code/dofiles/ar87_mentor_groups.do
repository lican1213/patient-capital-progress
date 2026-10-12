*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar87_mentor_groups.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十六轮 B 第一步：复现导师稿的区位熵四组、东到中西/中西到东分样本）
* Purpose:  规则见本 exploration README 第四十六轮 B。三种写法逐一试，记录系数、t、N，不做检验。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta（导师 10-08 主面板1）
* Outputs:  本 exploration 的 output/tables/ar87_mentor_groups.csv
* Log:      explorations/advisor_revision_20261005/logs/ar87_mentor_groups.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar87
log using "`EXP'/logs/ar87_mentor_groups.log", name(ar87) replace text

use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
local C12 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数
local C11 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local S1c `C12'
local S1a id year
local S2c `C12'
local S2a id year city_out
local S3c `C11'
local S3a id ind_year
local S4c `C11'
local S4a id year

tempfile res
postfile R str3 spec str10 grp double(b se t p) long N using `res', replace
foreach s in S1 S2 S3 S4 {
    forvalues k = 1/4 {
        quietly reghdfe 跨省子公司数量占比 Patient ``s'c' if LQ_type == `k' & reg_sample == 1, absorb(``s'a') vce(cluster id)
        post R ("`s'") ("LQ`k'") (_b[Patient]) (_se[Patient]) (_b[Patient]/_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
    }
    * 导师原写法：!=0（缺失也算非 0）
    quietly reghdfe 跨省子公司数量占比 Patient ``s'c' if 东到中西次数 != 0, absorb(``s'a') vce(cluster id)
    post R ("`s'") ("EW_ne0") (_b[Patient]) (_se[Patient]) (_b[Patient]/_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
    quietly reghdfe 跨省子公司数量占比 Patient ``s'c' if 中西到东次数 != 0, absorb(``s'a') vce(cluster id)
    post R ("`s'") ("WE_ne0") (_b[Patient]) (_se[Patient]) (_b[Patient]/_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
    * 只取次数 > 0（排除缺失）
    quietly reghdfe 跨省子公司数量占比 Patient ``s'c' if 东到中西次数 > 0 & !missing(东到中西次数), absorb(``s'a') vce(cluster id)
    post R ("`s'") ("EW_gt0") (_b[Patient]) (_se[Patient]) (_b[Patient]/_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
    quietly reghdfe 跨省子公司数量占比 Patient ``s'c' if 中西到东次数 > 0 & !missing(中西到东次数), absorb(``s'a') vce(cluster id)
    post R ("`s'") ("WE_gt0") (_b[Patient]) (_se[Patient]) (_b[Patient]/_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
}
postclose R
use `res', clear
format b se %9.5f
format t p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar87_mentor_groups.csv", replace
log close ar87
