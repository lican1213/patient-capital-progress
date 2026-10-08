*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar68_seg0_firstcity.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第二十九轮：表8 市场分割固定首年总部城市）
* Purpose:  规则见本 exploration README 第二十九轮（运行前写定）。
*           (A) Seg0f_z（首个样本年总部城市）替换 Seg0_z：表8 第（1）（2）列、附表6 四列、附表9 第（1）（2）列；
*           (B) 原 Seg0_z 剔除总部迁移企业：表8 第（1）列、附表6 第（1）列。
*           Seg0_z 同时重跑一遍，与现表逐格核对。
* Inputs:   data/derived/advisor_send_20261008/主面板3_企业目的省年份_v2.dta；
*           data/derived/advisor_send_20261008/企业目的省基期市场分割_首年总部.dta（ar68_build_seg0_firstcity.py）
* Outputs:  本 exploration 的 output/tables/ar68_seg0_firstcity.csv
* Log:      explorations/advisor_revision_20261005/logs/ar68_seg0_firstcity.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar68
log using "`EXP'/logs/ar68_seg0_firstcity.log", name(ar68) replace text
which reghdfe

use "data/derived/advisor_send_20261008/主面板3_企业目的省年份_v2.dta", clear
merge 1:1 stkcd year dest_id using "data/derived/advisor_send_20261008/企业目的省基期市场分割_首年总部.dta"
assert _merge == 3
drop _merge
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
* 标准化 Patient 与短期机构持股（在 2015 年起的样本上，同 15 号命令附表6 第（4）列）
egen double z_P = std(Patient) if year >= 2015
egen double z_S = std(io_short) if year >= 2015
* 总部迁移企业数
egen byte tag = tag(stkcd)
count if tag & mover == 1

tempfile res
postfile R str8 seg str12 tab byte col str12 var double(b se p) long(N nc) using `res', replace
capture program drop rec
program define rec
    syntax, Seg(string) Tab(string) Col(integer) Var(string) Term(string)
    post R ("`seg'") ("`tab'") (`col') ("`var'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(N_clust))
end

local FE fy fd dyr
foreach S in Seg0_z Seg0f_z {
    * 表8 第（1）列：全部目的省
    reghdfe entry c.Patient#c.`S' if year >= 2015, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(T8) col(1) var(PxSeg) term(c.Patient#c.`S')
    * 表8 第（2）列：剔除直辖市
    reghdfe entry c.Patient#c.`S' if year >= 2015 & d_muni == 0, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(T8) col(2) var(PxSeg) term(c.Patient#c.`S')
    * 附表6 第（2）列：加 Patient×距离对数
    reghdfe entry c.Patient#c.`S' c.Patient#c.lndist if year >= 2015, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(A6) col(2) var(PxSeg) term(c.Patient#c.`S')
    rec, seg(`S') tab(A6) col(2) var(PxDist) term(c.Patient#c.lndist)
    * 附表6 第（3）列：企业与目的省双向聚类
    reghdfe entry c.Patient#c.`S' if year >= 2015, absorb(`FE') vce(cluster firm dest_id)
    rec, seg(`S') tab(A6) col(3) var(PxSeg) term(c.Patient#c.`S')
    * 附表6 第（4）列：标准化耐心资本与短期机构持股
    reghdfe entry c.z_P#c.`S' c.z_S#c.`S' if year >= 2015, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(A6) col(4) var(zPxSeg) term(c.z_P#c.`S')
    rec, seg(`S') tab(A6) col(4) var(zSxSeg) term(c.z_S#c.`S')
    lincom _b[c.z_P#c.`S'] - _b[c.z_S#c.`S']
    post R ("`S'") ("A6") (4) ("diff_1side") (r(estimate)) (r(se)) (ttail(r(df), r(estimate)/r(se))) (e(N)) (e(N_clust))
    * 附表9 第（1）（2）列：上一期 Patient
    reghdfe entry c.L_Patient#c.`S' if year >= 2015, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(A9) col(1) var(LPxSeg) term(c.L_Patient#c.`S')
    reghdfe entry c.L_Patient#c.`S' if year >= 2015 & d_muni == 0, absorb(`FE') vce(cluster firm)
    rec, seg(`S') tab(A9) col(2) var(LPxSeg) term(c.L_Patient#c.`S')
}
* (B) 原 Seg0_z 剔除总部迁移企业
reghdfe entry c.Patient#c.Seg0_z if year >= 2015 & mover == 0, absorb(`FE') vce(cluster firm)
rec, seg(Seg0_nomv) tab(T8) col(1) var(PxSeg) term(c.Patient#c.Seg0_z)
reghdfe entry c.Patient#c.Seg0_z if year >= 2015 & mover == 0 & d_muni == 0, absorb(`FE') vce(cluster firm)
rec, seg(Seg0_nomv) tab(T8) col(2) var(PxSeg) term(c.Patient#c.Seg0_z)
postclose R
use `res', clear
format b se p %12.8f
list, clean noobs sep(0)
export delimited using "`EXP'/output/tables/ar68_seg0_firstcity.csv", replace
log close ar68
