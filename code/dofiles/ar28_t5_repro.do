*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar28_t5_repro.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第七轮：初稿8 表5 三个组间 p 值复现，供导师复核）
* Purpose:  与 ar19_t5_chow.do 第（一）部分相同，只保留导师原规格的复现：导师 Chow 写法
*           reghdfe Y g##(c.Patient c.控制), absorb(id year)，test 1.g#c.Patient，
*           分别取 vce(r) 与 vce(cluster id)，对照初稿8 表5 的 .039/.067/.074。
* Inputs:   导师主面板
* Outputs:  本 exploration 的 output/tables/ar28_t5_repro.csv
* Log:      explorations/advisor_revision_20261005/logs/ar28_t5_repro.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261007

local EXP "explorations/advisor_revision_20261005"
local P "data/mentor_panel"
capture log close ar28
log using "`EXP'/logs/ar28_t5_repro.log", name(ar28) replace text
which reghdfe

tempfile res
postfile R str10 grp str3 vce double(b F p) long(N) using `res', replace
use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
local Y 跨省子公司数量占比
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数
* 分组按导师原 do 的定义
generate byte g_seghi = (母公司异地市场分割 >= p50_母公司异地市场分割) if !missing(母公司异地市场分割) & !missing(p50_母公司异地市场分割)
generate byte g_sphsm = 球面距离小
generate byte g_reshi = (供应链韧性 >= p50_供应链韧性) if !missing(供应链韧性) & !missing(p50_供应链韧性)
local IC
foreach v of local C {
    local IC `IC' c.`v'
}
foreach g in seghi sphsm reshi {
    foreach vc in r cl {
        local VCE = cond("`vc'" == "r", "vce(r)", "vce(cluster id)")
        reghdfe `Y' g_`g'##(c.Patient `IC'), absorb(id year) `VCE'
        local Nn = e(N)
        local bb = _b[1.g_`g'#c.Patient]
        test 1.g_`g'#c.Patient
        post R ("`g'") ("`vc'") (`bb') (r(F)) (r(p)) (`Nn')
    }
}
postclose R
use `res', clear
format b F p %12.6f
list, noobs
export delimited using "`EXP'/output/tables/ar28_t5_repro.csv", replace
log close ar28
