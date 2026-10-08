*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar69_dyad_seg.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十轮：交付包改用首年总部口径）
* Purpose:  规则见本 exploration README 第三十轮（运行前写定）。在主面板3_v3 上重跑：
*           表8 第（1）（2）列（当期 D8_0、上一期 D8_1）；附表6 四列；表1 分割行（表8 第（1）列自身样本）；
*           基期对照（2014 年单年、当年值含水平项、百分位秩；全样本与剔除直辖市），只用于 08 说明文字。
* Inputs:   data/derived/advisor_send_20261008/主面板3_企业目的省年份_v3.dta（ar69_export_panel3_v3.py）
* Outputs:  本 exploration 的 output/tables/ar69_d8.csv、ar69_a6.csv、ar69_desc.csv、ar69_basechk.csv
* Log:      explorations/advisor_revision_20261005/logs/ar69_dyad_seg.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar69
log using "`EXP'/logs/ar69_dyad_seg.log", name(ar69) replace text
which reghdfe

use "data/derived/advisor_send_20261008/主面板3_企业目的省年份_v3.dta", clear
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr

* ---- 表8 第（1）（2）列：格式同 ar51_oct8.csv ----
tempfile d8 a6 ds bc
postfile D str6 tab byte col str4 var double(b se p) long N double r2a long nclust using `d8', replace
local k = 0
foreach X in Patient L_Patient {
    capture drop Px
    generate double Px = `X' * Seg0_z
    reghdfe entry Px if year >= 2015, absorb(`FE') vce(cluster firm)
    post D ("D8_`k'") (1) ("Px") (_b[Px]) (_se[Px]) (2*ttail(e(df_r), abs(_b[Px]/_se[Px]))) (e(N)) (e(r2_a)) (e(N_clust))
    if "`X'" == "Patient" {
        * 表1 分割行：表8 第（1）列自身估计样本
        summarize Seg0_z if e(sample), detail
        postfile S str8 var long N double(mean sd min p50 max) using `ds', replace
        post S ("Seg0_z") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
        postclose S
        correlate Seg0_z Seg14_z Segt_z if e(sample)
    }
    reghdfe entry Px if year >= 2015 & d_muni == 0, absorb(`FE') vce(cluster firm)
    post D ("D8_`k'") (2) ("Px") (_b[Px]) (_se[Px]) (2*ttail(e(df_r), abs(_b[Px]/_se[Px]))) (e(N)) (e(r2_a)) (e(N_clust))
    local ++k
}
postclose D

* ---- 附表6 四列：格式同 ar65_oldtable8_current.csv（当期）----
postfile A str4 tm byte col str12 var double(b se p) long(N nc) using `a6', replace
capture program drop rec6
program define rec6
    syntax, Col(integer) Var(string) Term(string)
    post A ("P0") (`col') ("`var'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) (e(N_clust))
end
egen double z_P = std(Patient) if year >= 2015
egen double z_S = std(io_short) if year >= 2015
reghdfe entry c.Patient#c.Seg0_z if year >= 2015, absorb(`FE') vce(cluster firm)
rec6, col(1) var(PxSeg) term(c.Patient#c.Seg0_z)
reghdfe entry c.Patient#c.Seg0_z c.Patient#c.lndist if year >= 2015, absorb(`FE') vce(cluster firm)
rec6, col(2) var(PxSeg) term(c.Patient#c.Seg0_z)
rec6, col(2) var(PxDist) term(c.Patient#c.lndist)
reghdfe entry c.Patient#c.Seg0_z if year >= 2015, absorb(`FE') vce(cluster firm dest_id)
rec6, col(3) var(PxSeg) term(c.Patient#c.Seg0_z)
reghdfe entry c.z_P#c.Seg0_z c.z_S#c.Seg0_z if year >= 2015, absorb(`FE') vce(cluster firm)
rec6, col(4) var(zPxSeg) term(c.z_P#c.Seg0_z)
rec6, col(4) var(zSxSeg) term(c.z_S#c.Seg0_z)
lincom _b[c.z_P#c.Seg0_z] - _b[c.z_S#c.Seg0_z]
post A ("P0") (4) ("diff_1side") (r(estimate)) (r(se)) (ttail(r(df), r(estimate)/r(se))) (e(N)) (e(N_clust))
postclose A

* ---- 基期对照（当期 Patient）：2014 年单年、当年值（含水平项）、百分位秩 ----
postfile B str8 spec byte col double(b se p) long N using `bc', replace
egen double rs = rank(Seg0_z) if year >= 2015 & !missing(Seg0_z, entry, Patient)
quietly count if !missing(rs)
generate double Seg_r = rs / r(N)
foreach s in Seg14_z Segt_z Seg_r {
    capture drop Px
    generate double Px = Patient * `s'
    local lev = cond("`s'" == "Segt_z", "Segt_z", "")
    reghdfe entry Px `lev' if year >= 2015, absorb(`FE') vce(cluster firm)
    post B ("`s'") (1) (_b[Px]) (_se[Px]) (2*ttail(e(df_r), abs(_b[Px]/_se[Px]))) (e(N))
    reghdfe entry Px `lev' if year >= 2015 & d_muni == 0, absorb(`FE') vce(cluster firm)
    post B ("`s'") (2) (_b[Px]) (_se[Px]) (2*ttail(e(df_r), abs(_b[Px]/_se[Px]))) (e(N))
}
postclose B

foreach f in d8 a6 ds bc {
    use ``f'', clear
    list, clean noobs
    local nm = cond("`f'" == "ds", "desc", cond("`f'" == "bc", "basechk", "`f'"))
    export delimited using "`EXP'/output/tables/ar69_`nm'.csv", replace
}
log close ar69
