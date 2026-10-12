*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar90_t23_check.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮插入：作者问“我们和导师的表2、表3 是否基本一致”）
* Purpose:  用导师 10-08 发来的“实证代码2(1).do”中表2、表3 的命令原样在主面板1 上重跑，
*           与初稿8 表2、表3 逐格比对。只核对，不改设定。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta
* Outputs:  本 exploration 的 output/tables/ar90_t23_check.csv
* Log:      explorations/advisor_revision_20261005/logs/ar90_t23_check.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar90
log using "`EXP'/logs/ar90_t23_check.log", name(ar90) replace text

use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
local C10 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE
local C11 `C10' l第三产业增加值省份
egen long nid = group(id)
xtset nid year

tempfile res
postfile R str4 col str30 y double(b t r2a) long N using `res', replace
* 表2（1）—（5）：导师命令原样
quietly reghdfe 跨省子公司数量占比 Patient, absorb(id ind_year) vce(cluster id)
post R ("T2c1") ("Investp") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe 跨省子公司数量占比 Patient `C10', absorb(id ind_year) vce(cluster id)
post R ("T2c2") ("Investp") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe 跨省子公司数量占比 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T2c3") ("Investp") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe 同省异市数量占比 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T2c4") ("Investc") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe 同城子公司数量占比 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T2c5") ("Invests") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
* 表3（1）—（3）新增：导师命令原样
quietly reghdfe l新增跨省子公司数量 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T3c1") ("Investnn") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe l新增跨省子公司注册资本 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T3c2") ("Investnc") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
quietly reghdfe l新增同省异市子公司数量 Patient `C11', absorb(id ind_year) vce(cluster id)
post R ("T3c3") ("Investnns") (_b[Patient]) (_b[Patient]/_se[Patient]) (e(r2_a)) (e(N))
* 表3（4）—（6）存续：导师命令原样（解释变量与控制取上一年）
quietly reghdfe cross_surv3_rate L.(Patient `C11') if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
post R ("T3c4") ("surv3_rate") (_b[L.Patient]) (_b[L.Patient]/_se[L.Patient]) (e(r2_a)) (e(N))
quietly reghdfe cross_surv3_num L.(Patient `C11') if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
post R ("T3c5") ("surv3_num") (_b[L.Patient]) (_b[L.Patient]/_se[L.Patient]) (e(r2_a)) (e(N))
quietly reghdfe cross_surv5_rate L.(Patient `C11') if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)
post R ("T3x") ("surv5_rate") (_b[L.Patient]) (_b[L.Patient]/_se[L.Patient]) (e(r2_a)) (e(N))
quietly reghdfe cross_surv5_num L.(Patient `C11') if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)
post R ("T3c6") ("surv5_num") (_b[L.Patient]) (_b[L.Patient]/_se[L.Patient]) (e(r2_a)) (e(N))
postclose R
use `res', clear
format b %9.5f
format t r2a %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar90_t23_check.csv", replace
log close ar90
