*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar89_t7_replicate.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮第一步：复现初稿8 表7 中位数分组六列）
* Purpose:  规则见本 exploration README 第四十八轮第一步。逐一试分组变量、中位数口径、
*           控制变量与固定效应写法，记录两组系数、t、N，找出与稿逐格一致的写法。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta
* Outputs:  本 exploration 的 output/tables/ar89_t7_replicate.csv
* Log:      explorations/advisor_revision_20261005/logs/ar89_t7_replicate.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar89
log using "`EXP'/logs/ar89_t7_replicate.log", name(ar89) replace text

use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
local C11 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local C12 `C11' 行业勒纳指数
capture drop prov_year
egen long prov_year = group(所属省份代码 year)
local F1 id ind_year
local F2 id ind_year 所属省份代码
local F3 id year
local F4 id ind_year prov_year

* 分组变量（短名便于记录）
generate double g_seg1 = 母公司异地市场分割
generate double g_seg2 = Seg_ext_2014
generate double g_seg3 = Seg_ext_tv
generate double g_seg4 = 母公司异地市场分割2
generate double g_seg5 = 公司市场分割指数
generate double g_res  = 供应链韧性
generate double g_rd   = 研发投入占营业收入比例
misstable summarize g_* Patient 跨省子公司数量占比

* 两种中位数：全样本、分年；高组 = 大于等于中位数（同导师代码）
foreach g in seg1 seg2 seg3 seg4 seg5 res rd {
    quietly summarize g_`g', detail
    generate byte hA_`g' = (g_`g' >= r(p50)) if !missing(g_`g')
    bysort year: egen double m_`g' = median(g_`g')
    generate byte hY_`g' = (g_`g' >= m_`g') if !missing(g_`g')
}

tempfile res
postfile R str6 g str2 med str3 ctl str2 fe double(bH tH bL tL) long(NH NL) using `res', replace
foreach g in seg1 seg2 seg3 seg4 seg5 res rd {
    foreach m in A Y {
        foreach c in C11 C12 {
            foreach f in F1 F2 F3 F4 {
                quietly reghdfe 跨省子公司数量占比 Patient ``c'' if h`m'_`g' == 1, absorb(``f'') vce(cluster id)
                local bH = _b[Patient]
                local tH = _b[Patient]/_se[Patient]
                local NH = e(N)
                quietly reghdfe 跨省子公司数量占比 Patient ``c'' if h`m'_`g' == 0, absorb(``f'') vce(cluster id)
                post R ("`g'") ("`m'") ("`c'") ("`f'") (`bH') (`tH') (_b[Patient]) (_b[Patient]/_se[Patient]) (`NH') (e(N))
            }
        }
    }
}
postclose R
use `res', clear
format bH bL %9.5f
format tH tL %6.3f
list, sep(16) noobs
export delimited using "`EXP'/output/tables/ar89_t7_replicate.csv", replace
log close ar89
