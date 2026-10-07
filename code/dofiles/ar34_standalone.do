*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar34_standalone.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第九轮：新表独立成册，导师原规格）
* Purpose:  作者要求新表不再引用初稿8，表2基准、初稿8表3稳健性、Heckman、PSM、安慰剂全部搬进新表。
*           写法取自导师 do 文件（实证代码.do、安慰剂检验命令.do）与初稿8正文，固定效应按初稿8表注
*           （企业＋行业×年份），企业聚类，不加企业规模（D-128）。
*           D  原有变量描述统计（基准回归样本）
*           B  表2 基准：（1）只放 Patient（2）加企业层 10 个控制（3）再加 Lservice、Lerner（4）Investc（5）Invests；
*              另跑（3）不含 Lerner 一版，与初稿8 t 值对照后选定
*           R  稳健性：替换 Y（跨省子公司资本占比）、L.Patient、替换 X（稳定型机构持股，相对流通A股）、
*              剔除超大特大城市、控制国家区域战略、PSM 匹配样本
*           H  Heckman：选择变量候选两种（是否跨省投资、是否有耐心资本），第二阶段 X 候选两种（Patient、L.Patient），
*              按初稿8报告值（Hitech 0.269、IMR 0.005、第二阶段 p=.058、N 15182）对照选定
*           P  安慰剂：Patient 全样本随机置换 1000 次
* Inputs:   导师主面板；导师文件夹 机构持股.dta
* Outputs:  本 exploration 的 output/tables/ar34_standalone.csv、ar34_desc.csv、ar34_placebo.csv
* Log:      explorations/advisor_revision_20261005/logs/ar34_standalone.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255
set seed 20261007

local EXP "explorations/advisor_revision_20261005"
local P "data/mentor_panel"
* 安慰剂置换次数（初稿8写 1000 次）
local NREP 1000
capture log close ar34
log using "`EXP'/logs/ar34_standalone.log", name(ar34) replace text
which reghdfe
which psmatch2

tempfile res dsc plc inst
postfile R str3 tab str4 col str60 var double(b se p) long(N) double(r2a) using `res', replace
postfile S str40 var long(N) double(mean sd min p50 max) using `dsc', replace
capture program drop pv
program define pv
    syntax, Tab(string) Col(string) Vars(string)
    foreach v of local vars {
        post R ("`tab'") ("`col'") ("`v'") (_b[`v']) (_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(r2_a))
    }
end
local F INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE
local C `F' l第三产业增加值省份 行业勒纳指数

*--- 机构持股（替换解释变量用）---------------------------------------------------
use "`P'/机构持股.dta", clear
isid stkcd year
keep stkcd year 稳定型机构投资者持股比例_相对流通A股
rename 稳定型机构投资者持股比例_相对流通A股 Patients
save `inst'

*--- 1. 基准与描述统计 ------------------------------------------------------------
use "`P'/主面板_含区位熵_地理IV_创新指标.dta", clear
merge 1:1 stkcd year using `inst', keep(master match) nogenerate
* 面板里已有导师旧版同名变量，按导师 do 文件的写法重建
foreach v in ty belt_and_road yangtze_delta greater_bay chengyu h_muni sel_inv sel_pat treated _weight _pscore _treated _support _id _n1 _nn _pdif {
    capture drop `v'
}
reghdfe 跨省子公司数量占比 Patient, absorb(id ind_year) vce(cluster id)
pv, tab(B) col(1) vars(Patient)
reghdfe 跨省子公司数量占比 Patient `F', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(2) vars(Patient `F')
reghdfe 跨省子公司数量占比 Patient `F' l第三产业增加值省份, absorb(id ind_year) vce(cluster id)
pv, tab(B) col(3a) vars(Patient `F' l第三产业增加值省份)
reghdfe 跨省子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
assert abs(_b[Patient] - .00168) < 5e-6
pv, tab(B) col(3) vars(Patient `C')
foreach v in 跨省子公司数量占比 同省异市数量占比 同城子公司数量占比 Patient `C' {
    quietly summarize `v' if e(sample), detail
    post S ("`v'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
}
reghdfe 同省异市数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(4) vars(Patient `C')
reghdfe 同城子公司数量占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(B) col(5) vars(Patient `C')

*--- 2. 稳健性 --------------------------------------------------------------------
reghdfe 跨省子公司资本占比 Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(1) vars(Patient)
reghdfe 跨省子公司数量占比 L_Patient `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(2) vars(L_Patient)
reghdfe 跨省子公司数量占比 Patients `C', absorb(id ind_year) vce(cluster id)
pv, tab(R) col(3) vars(Patients)
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
* 剔除直辖市总部企业（同 ar26 T1 列2）
generate byte h_muni = inlist(母公司所在省份, "北京市", "天津市", "上海市", "重庆市")
reghdfe 跨省子公司数量占比 Patient `C' if h_muni == 0, absorb(id ind_year) vce(cluster id)
pv, tab(R) col(7) vars(Patient)

*--- 3. Heckman 两阶段 -------------------------------------------------------------
generate byte sel_inv = (跨省子公司数量占比 > 0) if !missing(跨省子公司数量占比)
generate byte sel_pat = (Patient > 0) if !missing(Patient)
local k = 0
foreach s in sel_inv sel_pat {
    probit `s' 高新技术企业 `C' i.year, vce(cluster id)
    post R ("H1") ("`s'") ("高新技术企业") (_b[高新技术企业]) (_se[高新技术企业]) ///
        (2*normal(-abs(_b[高新技术企业]/_se[高新技术企业]))) (e(N)) (e(r2_p))
    predict double xb_`s' if e(sample), xb
    generate double imr_`s' = normalden(xb_`s') / normal(xb_`s')
    foreach x in Patient L_Patient {
        local ++k
        reghdfe 跨省子公司数量占比 `x' imr_`s' `C', absorb(id ind_year) vce(cluster id)
        pv, tab(H2) col(`k') vars(`x' imr_`s')
    }
}

*--- 4. PSM（同导师 do 文件：是否有耐心资本，1:1 近邻，共同支撑，卡尺 0.05）----------
generate byte treated = (Patient > 0) if !missing(Patient)
psmatch2 treated `C', outcome(跨省子公司数量占比) neighbor(1) common caliper(0.05) ties
reghdfe 跨省子公司数量占比 Patient `C' if _weight != ., absorb(id ind_year) vce(cluster id)
pv, tab(R) col(6) vars(Patient)

*--- 5. 安慰剂：Patient 随机置换 ----------------------------------------------------
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
use `plc', clear
quietly count if b >= `true_b'
local pe = r(N) / _N
quietly count if p < .10
local s10 = r(N) / _N
quietly summarize b
post R ("P") ("1") ("summary") (r(mean)) (r(sd)) (`pe') (_N) (`s10')
display "真实系数 = " `true_b' "，置换系数不小于真实系数的比例 = " `pe' "，p<0.1 的比例 = " `s10'
export delimited using "`EXP'/output/tables/ar34_placebo.csv", replace

postclose R
postclose S
use `res', clear
format b se p r2a %12.6f
list, sepby(tab) noobs
export delimited using "`EXP'/output/tables/ar34_standalone.csv", replace
use `dsc', clear
export delimited using "`EXP'/output/tables/ar34_desc.csv", replace
log close ar34
