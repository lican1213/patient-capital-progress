*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar81_mentor_interact.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十一轮：导师 10-12 语音，表8 交互写法再做一稿）
* Purpose:  规则见本 exploration README 第四十一轮（运行前写定）。
*           （1）Patient×当年市场分割（2）Patient×当年研发资源（3）Patient×不加权距离（4）三项同放；
*           另报剔除北京、直辖市目的地，上一年值，基期分割对照。设定同三张表命令表8。
* Inputs:   deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/advisor_send_20261008/目的省研发资源_逐年.dta（ar81_build_rd_year.py）
* Outputs:  本 exploration 的 output/tables/ar81_mentor_interact.csv
* Log:      explorations/advisor_revision_20261005/logs/ar81_mentor_interact.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar81
log using "`EXP'/logs/ar81_mentor_interact.log", name(ar81) replace text
which reghdfe

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge m:1 dest year using "data/derived/advisor_send_20261008/目的省研发资源_逐年.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj   = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr

* 上一年市场分割：同一企业×目的省的上一自然年（首个样本年之前无值）
xtset fd year
generate double Seg_l1 = L.Segt_z

* 研发资源在估计样本（year>=2015，entry、Patient 非缺失）内标准化
foreach v in rd_t rd_l1 {
    quietly summarize `v' if year >= 2015 & !missing(entry, Patient)
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
summarize Segt_z Seg_l1 z_rd_t z_rd_l1 lndist Seg0_z if year >= 2015 & !missing(entry, Patient)
correlate Segt_z Seg_l1 Seg0_z if year >= 2015 & !missing(entry, Patient)

generate double PxS  = Patient * Segt_z
generate double PxSl = Patient * Seg_l1
generate double PxR  = Patient * z_rd_t
generate double PxRl = Patient * z_rd_l1
generate double PxD  = Patient * lndist
generate double PxS0 = Patient * Seg0_z

tempfile res
postfile R str10 spec str6 smp str5 var double(b se p) long(N nclust) using `res', replace
capture program drop rec
program define rec
    syntax, Spec(string) Smp(string) Vars(string)
    foreach v of local vars {
        post R ("`spec'") ("`smp'") ("`v'") (1000*_b[`v']) (1000*_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(N_clust))
    }
end

local base year >= 2015

* ---- 当年值 ----
* （1）市场分割当年值（含水平项）
reghdfe entry PxS Segt_z if `base', absorb(`FE') vce(cluster firm)
rec, spec(c1_seg) smp(all) vars(PxS Segt_z)
reghdfe entry PxS Segt_z if `base' & d_bj == 0, absorb(`FE') vce(cluster firm)
rec, spec(c1_seg) smp(nobj) vars(PxS Segt_z)
reghdfe entry PxS Segt_z if `base' & d_muni == 0, absorb(`FE') vce(cluster firm)
rec, spec(c1_seg) smp(nomuni) vars(PxS Segt_z)
* （2）研发资源当年值
reghdfe entry PxR if `base', absorb(`FE') vce(cluster firm)
rec, spec(c2_rd) smp(all) vars(PxR)
reghdfe entry PxR if `base' & d_bj == 0, absorb(`FE') vce(cluster firm)
rec, spec(c2_rd) smp(nobj) vars(PxR)
* （3）距离（不加权）
reghdfe entry PxD if `base', absorb(`FE') vce(cluster firm)
rec, spec(c3_dist) smp(all) vars(PxD)
* （4）三项同放
reghdfe entry PxS Segt_z PxR PxD if `base', absorb(`FE') vce(cluster firm)
rec, spec(c4_joint) smp(all) vars(PxS Segt_z PxR PxD)
reghdfe entry PxS Segt_z PxR PxD if `base' & d_bj == 0, absorb(`FE') vce(cluster firm)
rec, spec(c4_joint) smp(nobj) vars(PxS Segt_z PxR PxD)
reghdfe entry PxS Segt_z PxR PxD if `base' & d_muni == 0, absorb(`FE') vce(cluster firm)
rec, spec(c4_joint) smp(nomuni) vars(PxS Segt_z PxR PxD)

* ---- 上一年值（前定）----
reghdfe entry PxSl Seg_l1 if `base', absorb(`FE') vce(cluster firm)
rec, spec(l1_seg) smp(all) vars(PxSl Seg_l1)
reghdfe entry PxRl if `base', absorb(`FE') vce(cluster firm)
rec, spec(l1_rd) smp(all) vars(PxRl)
reghdfe entry PxSl Seg_l1 PxRl PxD if `base', absorb(`FE') vce(cluster firm)
rec, spec(l1_joint) smp(all) vars(PxSl Seg_l1 PxRl PxD)

* ---- 对照：基期分割，与（4）同样本 ----
reghdfe entry PxS Segt_z PxR PxD if `base', absorb(`FE') vce(cluster firm)
generate byte s4 = e(sample)
reghdfe entry PxS0 if s4, absorb(`FE') vce(cluster firm)
rec, spec(ref_seg0) smp(s4) vars(PxS0)
reghdfe entry PxS0 PxR PxD if s4, absorb(`FE') vce(cluster firm)
rec, spec(ref_seg0j) smp(s4) vars(PxS0 PxR PxD)

postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar81_mentor_interact.csv", replace
log close ar81
