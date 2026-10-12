*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar83_seg_scale.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十三轮：导师城市对指数的分布与口径处理）
* Purpose:  规则见本 exploration README 第四十三轮（运行前写定）。
*           口径 t、l1、m3、m3l × 处理 pz（全面板标准化）、yz（分年标准化）、rk（年内百分位）、w5（5% 缩尾）、ln（取对数）；
*           样本：全部、剔除北京目的地、剔除直辖市目的地；诊断：yz 剔除 2015 年、剔除 2023—2024 年。设定同 ar81。
* Inputs:   deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta；
*           data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta（ar83_build_seg_raw.py）
* Outputs:  本 exploration 的 output/tables/ar83_seg_scale.csv
* Log:      explorations/advisor_revision_20261005/logs/ar83_seg_scale.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar83
log using "`EXP'/logs/ar83_seg_scale.log", name(ar83) replace text
which reghdfe

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj   = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr
generate byte es = year >= 2015 & !missing(entry, Patient)

* 构造各处理（均在估计样本 es 内计算）
foreach k in t l1 m3 m3l {
    local v seg_`k'
    * pz：全面板标准化
    quietly summarize `v' if es
    generate double pz_`k' = (`v' - r(mean)) / r(sd)
    * yz：分年标准化
    bysort year: egen double _m = mean(cond(es, `v', .))
    bysort year: egen double _s = sd(cond(es, `v', .))
    generate double yz_`k' = (`v' - _m) / _s
    drop _m _s
    * rk：年内百分位（0—1）
    bysort year: egen double _rk = rank(`v') if es & !missing(`v')
    bysort year: egen double _cnt = count(`v') if es & !missing(`v')
    generate double rk_`k' = (_rk - 1) / (_cnt - 1)
    drop _rk _cnt
    * w5：5%/95% 缩尾后全面板标准化
    quietly _pctile `v' if es, percentiles(5 95)
    local lo = r(r1)
    local hi = r(r2)
    generate double _w = min(max(`v', `lo'), `hi') if !missing(`v')
    quietly summarize _w if es
    generate double w5_`k' = (_w - r(mean)) / r(sd)
    drop _w
    * ln：取对数后全面板标准化
    generate double _l = ln(`v')
    quietly summarize _l if es
    generate double ln_`k' = (_l - r(mean)) / r(sd)
    drop _l
}
* 核对：pz_t 与 16 号 Segt_z 高度相关（只差标准化总体）
correlate pz_t Segt_z if es
* 分年标准差，说明口径突变
tabstat seg_t if es, by(year) statistics(mean sd p99 max) format(%9.5f)

tempfile res
postfile R str3 tr str3 k str6 smp str3 var double(b se p) long(N nclust) using `res', replace
foreach tr in pz yz rk w5 ln {
    foreach k in t l1 m3 m3l {
        capture drop X PxX
        generate double X   = `tr'_`k'
        generate double PxX = Patient * X
        foreach s in all nobj nomuni {
            local c ""
            if "`s'" == "nobj"   local c "& d_bj == 0"
            if "`s'" == "nomuni" local c "& d_muni == 0"
            quietly reghdfe entry PxX X if es `c', absorb(`FE') vce(cluster firm)
            post R ("`tr'") ("`k'") ("`s'") ("PxX") (1000*_b[PxX]) (1000*_se[PxX]) ///
                (2*ttail(e(df_r), abs(_b[PxX]/_se[PxX]))) (e(N)) (e(N_clust))
            display "`tr' `k' `s'  b=" %9.5f 1000*_b[PxX] "  p=" %6.3f 2*ttail(e(df_r), abs(_b[PxX]/_se[PxX])) "  N=" e(N)
        }
    }
}
* 诊断（不作候选）：分年标准化剔除 2015 年、剔除 2023—2024 年
foreach k in t l1 {
    capture drop X PxX
    generate double X   = yz_`k'
    generate double PxX = Patient * X
    quietly reghdfe entry PxX X if es & year != 2015, absorb(`FE') vce(cluster firm)
    post R ("yz") ("`k'") ("no2015") ("PxX") (1000*_b[PxX]) (1000*_se[PxX]) (2*ttail(e(df_r), abs(_b[PxX]/_se[PxX]))) (e(N)) (e(N_clust))
    quietly reghdfe entry PxX X if es & year < 2023, absorb(`FE') vce(cluster firm)
    post R ("yz") ("`k'") ("to2022") ("PxX") (1000*_b[PxX]) (1000*_se[PxX]) (2*ttail(e(df_r), abs(_b[PxX]/_se[PxX]))) (e(N)) (e(N_clust))
}
postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar83_seg_scale.csv", replace
log close ar83
