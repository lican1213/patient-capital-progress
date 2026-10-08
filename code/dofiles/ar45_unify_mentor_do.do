*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar45_unify_mentor_do.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十五轮：按导师 10 月 8 日“实证代码2”统一命令）
* Purpose:  导师要求统一命令。新表所有企业层回归改按导师 10 月 8 日发来的 do 文件与新面板：
*           控制变量 11 个（INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份，
*           不含行业勒纳指数）；基准、新增、存续、稳健性、机制按导师逐行写法；
*           LMDA 用导师面板的 ln_myopia_words，自建 LMDA 另记一组（LS）；
*           母公司创新用 l母公司当年独立专利总和，子公司创新用 lcross_sub_indep；
*           存续用导师面板 cross_surv3/5_*，解释变量与控制变量取上一期（导师写法 L.()），
*           条件为跨省子公司数量>0 且 year<=2021（三年）、<=2019（五年）；
*           机制按导师 do 的七个变量，另保留 WW（作者裁决 2026-10-08）。
*           其他表（异质性、Heckman、工具变量、功能类型）规格同前，只把控制变量换成上述 11 个。
*           双边表（表8、表9、附表6）不含控制变量，沿用 ar29、ar31、ar44 的结果，不在此重跑。
*           导师面板的 id 为六位代码字符串，需要滞后时按 id 生成数值面板编号 nid 再 xtset。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta（导师 10 月 8 日面板）；
*           data/derived/advisor_revision_20261005/{lmda,firm_events_v2}.dta；data/derived/analysis_ready.dta；
*           data/derived/unified_market_dyadic_20260923/iv_set.dta；
*           explorations/iv_identification_20260921/data/iv_components.dta
* Outputs:  本 exploration 的 output/tables/ar45_unified.csv、ar45_desc.csv、ar45_placebo.csv
* Log:      explorations/advisor_revision_20261005/logs/ar45_unify_mentor_do.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261008

local EXP "explorations/advisor_revision_20261005"
local D "data/derived/advisor_revision_20261005"
local PANEL "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta"
* 安慰剂置换次数（同 ar34）
local NREP 1000
capture log close ar45
log using "`EXP'/logs/ar45_unify_mentor_do.log", name(ar45) replace text
which reghdfe
which ivreghdfe
which psmatch2

tempfile res dsc plc
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a stat statp) using `res', replace
postfile S str40 var long(N) double(mean sd min p50 max) using `dsc', replace
capture program drop pv
program define pv
    * 记录一列中若干系数（N 与调整后 R² 随每行重复记录）
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a)) (.) (.)
    }
end
capture program drop dsum
program define dsum
    * 描述统计：在当前估计样本上
    syntax varname, Label(string)
    quietly summarize `varlist' if e(sample), detail
    post S ("`label'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
end
* 导师 do 文件的控制变量
local F INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE
local C `F' l第三产业增加值省份

*=== 1. 导师面板：基准（导师 do 第 1—5 行）==========================================
use "`PANEL'", clear
isid id year
egen long nid = group(id)
xtset nid year
reghdfe 跨省子公司数量占比 Patient, absorb(id ind_year) vce(cluster id)
pv, tab(B) col(1) vars(Patient)
reghdfe 跨省子公司数量占比 Patient `F', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(2) vars(Patient `F')
reghdfe 跨省子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
* 与导师新面板上的试跑一致（2026-10-08 试跑：Patient .0016757，N 15181）
assert abs(_b[Patient] - .0016757) < 5e-7 & e(N) == 15181
pv, tab(B) col(3) vars(Patient `C')
foreach v in 跨省子公司数量占比 同省异市数量占比 同城子公司数量占比 Patient `C' {
    quietly summarize `v' if e(sample), detail
    post S ("`v'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
}
reghdfe 同省异市数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(4) vars(Patient `C')
reghdfe 同城子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(5) vars(Patient `C')

*=== 2. 新增与存续（导师 do 第 7—13 行）============================================
local k = 0
foreach v in l新增跨省子公司数量 l新增跨省子公司注册资本 l新增同省异市子公司数量 {
    local ++k
    reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    pv, tab(T2) col(`k') vars(Patient)
    local lab : word `k' of Investnn Investnc Investnns
    dsum `v', label(`lab')
}
* 存续：导师写法，解释变量与控制变量取上一期；列顺序按新表 DuNum3 DuRate3 DuNum5 DuRate5
local k = 0
foreach v in cross_surv3_num cross_surv3_rate cross_surv5_num cross_surv5_rate {
    local ++k
    local yy = cond(strpos("`v'", "surv3"), 2021, 2019)
    reghdfe `v' L.(Patient `C') if 跨省子公司数量 > 0 & year <= `yy', absorb(id ind_year) vce(cluster id)
    pv, tab(T9) col(`k') vars(L.Patient)
    local lab : word `k' of DuNum3 DuRate3 DuNum5 DuRate5
    dsum `v', label(`lab')
}

*=== 3. 稳健性（表4）==============================================================
reghdfe 跨省子公司资本占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(1) vars(Patient)
* 第（2）列：上一自然年的 Patient
generate double Lp = L.Patient
reghdfe 跨省子公司数量占比 Lp `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(2) vars(Lp)
* 第（3）列：导师 do 的稳定型机构投资者持股比例（相对流通A股）
generate double Patients = 稳定型机构投资者持股比例_相对流通A股
reghdfe 跨省子公司数量占比 Patients `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(3) vars(Patients)
* 面板里已有导师旧版同名变量，按导师 do 文件的写法重建
foreach v in ty belt_and_road yangtze_delta greater_bay chengyu h_muni treated xb imr _weight _pscore _treated _support _id _n1 _nn _pdif {
    capture drop `v'
}
* 超大、特大城市名单同导师 do 文件
generate byte ty = 1
replace ty = 0 if inlist(city_out, "上海市","北京市","深圳市","重庆市","广州市","成都市","天津市")
replace ty = 0 if inlist(city_out, "武汉市","东莞市","西安市","杭州市","佛山市","南京市")
replace ty = 0 if inlist(city_out, "沈阳市","青岛市","济南市","长沙市","哈尔滨市","郑州市")
replace ty = 0 if inlist(city_out, "昆明市","大连市","苏州市")
reghdfe 跨省子公司数量占比 Patient `C' if ty == 1, absorb(id ind_year) vce(cluster id)
pv, tab(R) col(4) vars(Patient)
* 国家区域战略虚拟变量同导师 do 文件
generate byte belt_and_road = inlist(母公司所在省份, "福建省","陕西省","甘肃省","新疆维吾尔自治区") & year >= 2013
generate byte yangtze_delta = inlist(母公司所在省份, "上海市","江苏省","浙江省","安徽省") & year >= 2018
generate byte greater_bay = (母公司所在省份 == "广东省") & year >= 2017
generate byte chengyu = inlist(母公司所在省份, "四川省","重庆市") & year >= 2020
reghdfe 跨省子公司数量占比 Patient belt_and_road yangtze_delta greater_bay chengyu `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(5) vars(Patient belt_and_road yangtze_delta greater_bay chengyu)
generate byte h_muni = inlist(母公司所在省份, "北京市", "天津市", "上海市", "重庆市")
reghdfe 跨省子公司数量占比 Patient `C' if h_muni == 0, absorb(id ind_year) vce(cluster id)
pv, tab(R) col(7) vars(Patient)

*=== 4. Heckman（同 ar44：是否有耐心资本，正负两支 IMR）============================
quietly summarize Patient, detail
assert r(p50) == 0
generate byte treated = (Patient > r(p50)) if !missing(Patient)
probit treated `C' 高新技术企业 i.year, vce(cluster id)
post R ("H1") ("1") ("高新技术企业") (_b[高新技术企业]) (_se[高新技术企业]) ///
    (2*normal(-abs(_b[高新技术企业]/_se[高新技术企业]))) (e(N)) (e(r2_p)) (.) (.)
predict double xb if e(sample), xb
generate double imr = normalden(xb) / normal(xb) if treated == 1
replace imr = -normalden(xb) / (1 - normal(xb)) if treated == 0
reghdfe 跨省子公司数量占比 Patient `C' imr, absorb(id ind_year) vce(cluster id)
pv, tab(H2) col(iy) vars(Patient imr)

*=== 5. PSM（同导师 do 文件：1:1 近邻，共同支撑，卡尺 0.05）=========================
psmatch2 treated `C', outcome(跨省子公司数量占比) neighbor(1) common caliper(0.05) ties
reghdfe 跨省子公司数量占比 Patient `C' if _weight != ., absorb(id ind_year) vce(cluster id)
pv, tab(R) col(6) vars(Patient)

*=== 6. 机制（导师 do 的七个变量＋WW）：第一步与第二步 ===============================
* 列顺序：LMDA WW ASY Srisk Resil LcomRDp LindRDs RDexp
local MV ln_myopia_words WW指数 ASY SCDRisk2_100倍 供应链韧性 l母公司当年独立专利总和 lcross_sub_indep 集团创新地理分散度
local ML LMDA WW ASY Srisk Resil LcomRDp LindRDs RDexp
local k = 0
foreach v of local MV {
    local ++k
    local lab : word `k' of `ML'
    reghdfe `v' Patient `C', absorb(id ind_year) vce(cluster id)
    pv, tab(T3) col(`k') vars(Patient)
    dsum `v', label(`lab')
    reghdfe 跨省子公司数量占比 Patient `v' `C', absorb(id ind_year) vce(cluster id)
    pv, tab(A2) col(`k') vars(Patient `v')
}
* 自建 LMDA（年报“管理层讨论与分析”短视词占比口径，ar41），作为对照
preserve
capture drop _merge
merge 1:1 stkcd year using "`D'/lmda.dta", keepusing(LMDA) keep(master match) nogenerate
reghdfe LMDA Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(LS) col(1) vars(Patient)
dsum LMDA, label(自建LMDA)
reghdfe 跨省子公司数量占比 Patient LMDA `C', absorb(id ind_year) vce(cluster id)
pv, tab(LS) col(2) vars(Patient LMDA)
correlate LMDA ln_myopia_words
post R ("LS") ("rho") ("LMDA_vs_ln_myopia_words") (r(rho)) (.) (.) (r(N)) (.) (.) (.)
restore

*=== 7. 异质性（企业＋年份 FE，分组同 ar26）与交互项 ================================
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
local j = 0
foreach dm in Seg Dist Resil RD {
    forvalues g = 1(-1)0 {
        local ++k
        reghdfe 跨省子公司数量占比 Patient `C' if g_`dm' == `g', absorb(id year) vce(cluster id)
        pv, tab(T4) col(`k') vars(Patient)
    }
    * 组间差异：导师写法（共用企业与年份 FE、斜率按组交互），企业聚类
    reghdfe 跨省子公司数量占比 g_`dm'##(c.Patient `IC'), absorb(id year) vce(cluster id)
    test 1.g_`dm'#c.Patient
    post R ("T4") ("`dm'") ("chow_p") (.) (.) (r(p)) (e(N)) (.) (.) (.)
    * 附表3 交互项：只让 Patient 按组变化
    local ++j
    generate double PxG = Patient * g_`dm'
    reghdfe 跨省子公司数量占比 Patient g_`dm' PxG `C', absorb(id year) vce(cluster id)
    post R ("A3") ("`j'") ("Patient") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N)) (e(r2_a)) (.) (.)
    post R ("A3") ("`j'") ("PxG") (_b[PxG]) (_se[PxG]) (2*ttail(e(df_r), abs(_b[PxG]/_se[PxG]))) (e(N)) (e(r2_a)) (.) (.)
    post R ("A3") ("`j'") ("G") (_b[g_`dm']) (_se[g_`dm']) (2*ttail(e(df_r), abs(_b[g_`dm']/_se[g_`dm']))) (e(N)) (e(r2_a)) (.) (.)
    drop PxG
}

*=== 8. 安慰剂：Patient 随机置换（同 ar34）=========================================
reghdfe 跨省子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
local true_b = _b[Patient]
keep if e(sample)
keep 跨省子公司数量占比 Patient `C' id ind_year
postfile Q double(b p) using `plc', replace
forvalues i = 1/`NREP' {
    quietly {
        generate double placebo = Patient[runiformint(1, _N)]
        reghdfe 跨省子公司数量占比 placebo `C', absorb(id ind_year) vce(cluster id)
        post Q (_b[placebo]) (2*ttail(e(df_r), abs(_b[placebo]/_se[placebo])))
        drop placebo
    }
}
postclose Q
preserve
use `plc', clear
quietly count if b >= `true_b'
local pe = r(N) / _N
quietly count if p < .10
local s10 = r(N) / _N
quietly summarize b
post R ("P") ("1") ("summary") (r(mean)) (r(sd)) (`pe') (_N) (`s10') (.) (.)
display "真实系数 = " `true_b' "，置换系数不小于真实系数的比例 = " `pe' "，p<0.1 的比例 = " `s10'
export delimited using "`EXP'/output/tables/ar45_placebo.csv", replace
restore

*=== 9. analysis_ready：功能类型（同 ar44，新增按首次披露）===========================
use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "`D'/firm_events_v2.dta", keep(master match) nogenerate
foreach v in n_new n_rep n_comp new_x_rdfix new_ECW n_rdcomp n_unkprev {
    generate double l_`v' = ln(1 + `v')
}
local k = 0
foreach v in n_new n_rep n_comp new_x_rdfix {
    local ++k
    reghdfe l_`v' Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
    pv, tab(T5) col(`k') vars(Patient)
    local lab : word `k' of 进入新省份新增 同功能复制新增 功能互补新增 研发型新增
    dsum l_`v', label(`lab')
}
reghdfe l_n_rdcomp Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(6) vars(Patient)
dsum l_n_rdcomp, label(研发互补新增)
reghdfe l_new_ECW Patient `C' if sample_main == 1 & home_east == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(5) vars(Patient)
dsum l_new_ECW, label(东部企业到中西部新增)
reghdfe l_n_unkprev Patient `C' if sample_main == 1, absorb(firm_id year_industry_id) vce(cluster firm_id)
pv, tab(T5) col(u) vars(Patient)

*=== 10. 工具变量（同 ar29、ar31）=================================================
use "explorations/iv_identification_20260921/data/iv_components.dta", clear
keep if sample_iv_lagged == 1
ivreghdfe 跨省子公司数量占比 (Patient_lag1 = IV_Hold2_lag1 IV_SizeGroup2_lag1) `C', absorb(firm_id year) cluster(firm_id)
post R ("T7") ("1") ("Patient_lag1") (_b[Patient_lag1]) (_se[Patient_lag1]) (2*normal(-abs(_b[Patient_lag1]/_se[Patient_lag1]))) ///
    (e(N)) (.) (e(widstat)) (.)
post R ("I") ("1") ("kp") (.) (.) (.) (e(N)) (.) (e(idstat)) (e(idp))
reghdfe Patient_lag1 IV_Hold2_lag1 IV_SizeGroup2_lag1 `C' if e(sample), absorb(firm_id year) vce(cluster firm_id)
pv, tab(F1) col(1) vars(IV_Hold2_lag1 IV_SizeGroup2_lag1)

use "data/derived/analysis_ready.dta", clear
merge 1:1 stkcd year using "data/derived/unified_market_dyadic_20260923/iv_set.dta"
drop if _merge == 2
drop _merge
xtset firm_id year
generate double lp = L.Patient
local LC
local k = 0
foreach v of local C {
    local ++k
    generate double lc`k' = L.`v'
    local LC `LC' lc`k'
}
generate double l_Pri_Number = L.Pri_Number
generate double l_Pri_Hold = L.Pri_Hold
local k = 1
foreach z in l_Pri_Number l_Pri_Hold {
    local ++k
    ivreghdfe 跨省子公司数量占比 `LC' (lp = `z'), absorb(firm_id year) cluster(firm_id)
    post R ("T7") ("`k'") ("lp") (_b[lp]) (_se[lp]) (2*normal(-abs(_b[lp]/_se[lp]))) (e(N)) (.) (e(widstat)) (.)
    post R ("I") ("`k'") ("kp") (.) (.) (.) (e(N)) (.) (e(idstat)) (e(idp))
    reghdfe lp `z' `LC' if e(sample), absorb(firm_id year) vce(cluster firm_id)
    pv, tab(F1) col(`k') vars(`z')
}

postclose R
postclose S
use `res', clear
format b se p r2a stat statp %12.6f
list if !inlist(tab, "B") | var == "Patient", sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar45_unified.csv", replace
use `dsc', clear
export delimited using "`EXP'/output/tables/ar45_desc.csv", replace
log close ar45
