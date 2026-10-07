*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar26_mentor_spec.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第七轮：按导师原规格回答 10 月 5 日的问题）
* Purpose:  作者要求只回复导师的疑问和要求的实证，因此全部按导师原规格：当期 Patient、
*           导师 12 个控制变量（不加企业规模）、导师各表所用固定效应——
*           基准、表32、机制、新增类型用企业＋行业×年份 FE（初稿8 表2、导师表32 与表4 的口径），
*           异质性用企业＋年份 FE（初稿8 表5 的口径），企业聚类。存续沿用导师写法 L.Patient。
*           T1 基准；T2 表32 新增；T3 机制；T4 异质性；T5 新增类型、研发互补与流向；T9 存续。
*           关键系数用 assert 与已复现结果核对。
* Inputs:   导师主面板；data/derived/analysis_ready.dta；
*           data/derived/advisor_revision_20261005/{firm_complement,firm_rdfix,firm_r3,survival}.dta
* Outputs:  本 exploration 的 output/tables/ar26_mentor_spec.csv
* Log:      explorations/advisor_revision_20261005/logs/ar26_mentor_spec.log
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
capture log close ar26
log using "`EXP'/logs/ar26_mentor_spec.log", name(ar26) replace text
which reghdfe

tempfile res
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a) using `res', replace
capture program drop pv
program define pv
    * 记录一列中若干变量的系数（N 与调整后 R² 随每行重复记录）
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a))
    }
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份 行业勒纳指数
* 存续窗口：t+3、t+5 不晚于样本末年 2024（导师写法）
local YEND 2024

*=== 导师主面板：T1—T4 ===============================================================
use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
generate byte h_muni = inlist(母公司所在省份, "北京市", "天津市", "上海市", "重庆市")
* T1 基准回归
reghdfe 跨省子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
assert abs(_b[Patient] - .00168) < 5e-6
pv, tab(T1) col(1) vars(Patient `C')
reghdfe 跨省子公司数量占比 Patient `C' if h_muni == 0, absorb(id ind_year) vce(cluster id)
pv, tab(T1) col(2) vars(Patient `C')
* T2 导师表32 列（1）—（3）
local k = 0
foreach v in l新增跨省子公司数量 l新增跨省子公司注册资本 l新增同省异市子公司数量 {
    local ++k
    reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    pv, tab(T2) col(`k') vars(Patient)
}
* T3 机制（导师表4 各列＋融资约束）
generate double M_comA = ln(1 + 母公司专利总数)
local k = 0
foreach v in WW指数 ASY SCDRisk2_100倍 供应链韧性 M_comA l子公司独立专利总和 集团创新地理分散度 {
    local ++k
    reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    pv, tab(T3) col(`k') vars(Patient)
}
* T4 异质性：导师分组定义（市场分割、球面距离、供应链韧性按导师 p50_ 变量），研发投入强度按当年中位数
generate byte g_Seg = (母公司异地市场分割 >= p50_母公司异地市场分割) if !missing(母公司异地市场分割) & !missing(p50_母公司异地市场分割)
generate byte g_Dist = (球面距离小 == 0) if !missing(球面距离小)
generate byte g_Resil = (供应链韧性 >= p50_供应链韧性) if !missing(供应链韧性) & !missing(p50_供应链韧性)
bysort year: egen double md_RD = median(研发投入占营业收入比例)
generate byte g_RD = (研发投入占营业收入比例 >= md_RD) if !missing(研发投入占营业收入比例)
local IC
foreach v of local C {
    local IC `IC' c.`v'
}
local k = 0
foreach dm in Seg Dist Resil RD {
    forvalues g = 1(-1)0 {
        local ++k
        reghdfe 跨省子公司数量占比 Patient `C' if g_`dm' == `g', absorb(id year) vce(cluster id)
        pv, tab(T4) col(`k') vars(Patient)
    }
    * 组间差异：导师 do 文件写法（共用企业与年份 FE、斜率按组交互），统一企业聚类
    reghdfe 跨省子公司数量占比 g_`dm'##(c.Patient `IC'), absorb(id year) vce(cluster id)
    test 1.g_`dm'#c.Patient
    post R ("T4") ("`dm'") ("chow_p") (.) (.) (r(p)) (e(N)) (.)
    if "`dm'" == "Seg" assert abs(r(p) - .0636060992469396) < 1e-9
}

*=== analysis_ready：T5 新增类型与流向、T9 存续 ======================================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "`D'/firm_complement.dta", keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/firm_rdfix.dta", keepusing(new_x_rdfix) keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/firm_r3.dta", keepusing(new_ECW home_east) keep(master match) nogenerate
merge 1:1 stkcd year using "`D'/survival.dta", keep(master match) nogenerate
xtset firm_id year
foreach v in n_new n_rep n_comp new_x_rdfix new_ECW n_rdcomp {
    generate double l_`v' = ln(1 + `v')
}
local k = 0
foreach v in n_new n_rep n_comp new_x_rdfix {
    local ++k
    reghdfe l_`v' Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
    pv, tab(T5) col(`k') vars(Patient)
}
reghdfe l_new_ECW Patient `C' if sample_main == 1 & home_east == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(5) vars(Patient)
* 研发互补：研发型新子公司进入上一年已有生产或销售子公司、但没有研发子公司的省份
reghdfe l_n_rdcomp Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(6) vars(Patient)
* T9 存续：导师写法 L.Patient、当期控制；基期存量>0；a 要求第 t+k 年仍披露，b 未披露记 0（导师样本量口径）
generate double xlag = L.Patient
foreach k in 3 5 {
    generate byte w`k' = (year + `k' <= `YEND') & obs`k' == 1 & stock0 > 0 & !missing(stock0)
}
reghdfe du3 xlag `C' if w3 == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
assert abs(_b[xlag] - .1355905505090652) < 1e-9
pv, tab(T9) col(1) vars(xlag)
reghdfe dr3 xlag `C' if w3 == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T9) col(2) vars(xlag)
reghdfe du5 xlag `C' if w5 == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T9) col(3) vars(xlag)
reghdfe dr5 xlag `C' if w5 == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T9) col(4) vars(xlag)
generate double du3_b = cond(obs3 == 1, du3, 0) if stock0 > 0 & !missing(stock0)
reghdfe du3_b xlag `C' if (year + 3 <= `YEND') & stock0 > 0 & !missing(stock0), absorb(firm_id year_industry_id) vce(cluster firm_id)
assert e(N) == 8127
pv, tab(T9) col(5) vars(xlag)

postclose R
use `res', clear
format b se p r2a %12.6f
list if inlist(var, "Patient", "xlag", "chow_p"), sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar26_mentor_spec.csv", replace
log close ar26
