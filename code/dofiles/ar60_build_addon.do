*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar60_build_addon.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十四轮：企业层补充变量）
* Purpose:  生成给导师的“主面板1补充变量”，按 stkcd、year 与主面板1 一对一合并。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta；
*           explorations/iv_identification_20260921/data/iv_components.dta；
*           data/derived/unified_market_dyadic_20260923/iv_set.dta；
*           data/derived/advisor_revision_20261005/{firm_events_v2,lmda}.dta
* Outputs:  data/derived/advisor_send_20261008/主面板1补充变量.dta
* Log:      explorations/advisor_revision_20261005/logs/ar60_build_addon.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
capture log close ar60
log using "explorations/advisor_revision_20261005/logs/ar60_build_addon.log", name(ar60) replace text

local D "data/derived/advisor_revision_20261005"
use stkcd year using "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta", clear
isid stkcd year
merge 1:1 stkcd year using "explorations/iv_identification_20260921/data/iv_components.dta", keepusing(IV_Hold2 IV_SizeGroup2) assert(match) nogenerate
merge 1:1 stkcd year using "data/derived/unified_market_dyadic_20260923/iv_set.dta", keepusing(Pri_Number Pri_Hold) keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/firm_events_v2.dta", keepusing(n_new n_rep n_comp new_x_rdfix new_ECW n_rdcomp home_east) assert(match) nogenerate
merge 1:1 stkcd year using "`D'/lmda.dta", keepusing(LMDA) keep(master match) nogenerate
label variable IV_Hold2 "同群工具：同年同机构持股分位组内其他企业 Patient 均值"
label variable IV_SizeGroup2 "同群工具：同年同资产规模分位组内其他企业 Patient 均值"
label variable Pri_Number "签署 PRI 的持股基金数加1取对数"
label variable Pri_Hold "签署 PRI 的基金持股比例"
label variable n_new "当年新设跨省子公司：进入新省份"
label variable n_rep "当年新设跨省子公司：同功能复制"
label variable n_comp "当年新设跨省子公司：功能互补"
label variable new_x_rdfix "当年新设跨省子公司：研发型"
label variable n_rdcomp "当年新设跨省子公司：研发互补"
label variable new_ECW "东部企业当年在中西部新设子公司数"
label variable home_east "母公司位于东部"
label variable LMDA "自建管理者短视（短视词占MD&A总词数×100，加1取对数）"
describe
misstable summarize
compress
save "data/derived/advisor_send_20261008/主面板1补充变量.dta", replace
log close ar60
