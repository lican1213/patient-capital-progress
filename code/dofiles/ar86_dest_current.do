*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar86_dest_current.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十六轮 A：当年值、省内权重、东中西、GDP 高低、研发薄弱三重交互）
* Purpose:  规则见本 exploration README 第四十六轮。设定同表8。
* Inputs:   16 号主面板3；data/derived/advisor_send_20261008/目的省逐年变量_ar86.dta、目的省研发资源_逐年.dta
*           市场化当年值同 ar82（原文件读入）
* Outputs:  本 exploration 的 output/tables/ar86_dest_current.csv
* Log:      explorations/advisor_revision_20261005/logs/ar86_dest_current.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar86
log using "`EXP'/logs/ar86_dest_current.log", name(ar86) replace text

use province_in year market using "data/raw/price_index/1997-2024年市场化指数和各分项指数.dta", clear
rename (province_in market) (dest mkt_t)
replace year = round(year)
tempfile mk
save `mk'

use "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "data/derived/advisor_send_20261008/目的省逐年变量_ar86.dta", keep(master match) nogenerate
merge m:1 dest year using "data/derived/advisor_send_20261008/目的省研发资源_逐年.dta", keep(master match) nogenerate
merge m:1 dest year using `mk', keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
generate byte d_bj   = (dest == "北京市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
local FE fy fd dyr
generate byte es = year >= 2015 & !missing(entry, Patient)

* 市场分割当年值：三种省内权重 × 两种处理
foreach w in eq gdp gdw {
    quietly summarize seg_`w' if es
    generate double pz_`w' = (seg_`w' - r(mean)) / r(sd)
    bysort year: egen double _rk = rank(seg_`w') if es & !missing(seg_`w')
    bysort year: egen double _cnt = count(seg_`w') if es & !missing(seg_`w')
    generate double rk_`w' = (_rk - 1) / (_cnt - 1)
    drop _rk _cnt
}
foreach v in rd_t mkt_t {
    quietly summarize `v' if es
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
* 企业研发强度：当年中位数以下为薄弱；连续版标准化
bysort year: egen double _md = median(cond(es, rdint, .))
generate byte lowRD = rdint < _md if !missing(rdint)
drop _md
quietly summarize rdint if es
generate double z_rdint = (rdint - r(mean)) / r(sd)
tabulate lowRD if es, missing

tempfile res
postfile R str8 blk str6 w str3 tr str6 smp str8 var double(b se p) long(N nclust) using `res', replace
capture program drop rec
program define rec
    syntax, Blk(string) W(string) Tr(string) Smp(string) Vars(string)
    foreach v of local vars {
        post R ("`blk'") ("`w'") ("`tr'") ("`smp'") ("`v'") (1000*_b[`v']) (1000*_se[`v']) ///
            (2*ttail(e(df_r), abs(_b[`v']/_se[`v']))) (e(N)) (e(N_clust))
    }
    display "`blk' `w' `tr' `smp'  b=" %9.4f 1000*_b[`: word 1 of `vars''] "  p=" %6.3f 2*ttail(e(df_r), abs(_b[`: word 1 of `vars'']/_se[`: word 1 of `vars'']))
end

* A1 市场分割当年值
foreach w in eq gdp gdw {
    foreach tr in pz rk {
        capture drop X PxX
        generate double X = `tr'_`w'
        generate double PxX = Patient * X
        foreach s in all nobj nomuni {
            local c ""
            if "`s'" == "nobj"   local c "& d_bj == 0"
            if "`s'" == "nomuni" local c "& d_muni == 0"
            quietly reghdfe entry PxX X if es `c', absorb(`FE') vce(cluster firm)
            rec, blk(A1_seg) w(`w') tr(`tr') smp(`s') vars(PxX X)
        }
    }
}
* A2 研发、市场化当年值
foreach v in rd_t mkt_t {
    capture drop PxX
    generate double PxX = Patient * z_`v'
    foreach s in all nobj nomuni {
        local c ""
        if "`s'" == "nobj"   local c "& d_bj == 0"
        if "`s'" == "nomuni" local c "& d_muni == 0"
        quietly reghdfe entry PxX if es `c', absorb(`FE') vce(cluster firm)
        rec, blk(A2_`v') w(-) tr(z) smp(`s') vars(PxX)
    }
}
* A3 东中西（西部为对照）
generate double PxE = Patient * d_east
generate double PxC = Patient * d_cent
quietly reghdfe entry PxE PxC if es, absorb(`FE') vce(cluster firm)
rec, blk(A3_reg) w(-) tr(-) smp(all) vars(PxE PxC)
test PxE = PxC
post R ("A3_reg") ("-") ("-") ("all") ("E=C") (.) (.) (r(p)) (e(N)) (e(N_clust))
* A4 目的省 GDP 高于本省
generate double PxG = Patient * gdp_hi
quietly reghdfe entry PxG gdp_hi if es, absorb(`FE') vce(cluster firm)
rec, blk(A4_gdphi) w(-) tr(-) smp(all) vars(PxG gdp_hi)
quietly reghdfe entry PxG gdp_hi if es & d_bj == 0, absorb(`FE') vce(cluster firm)
rec, blk(A4_gdphi) w(-) tr(-) smp(nobj) vars(PxG gdp_hi)
generate double PxL = Patient * lngdpr
quietly reghdfe entry PxL lngdpr if es, absorb(`FE') vce(cluster firm)
rec, blk(A4_lnr) w(-) tr(-) smp(all) vars(PxL lngdpr)
* A5 研发薄弱三重交互
generate double PxR   = Patient * z_rd_t
generate double RxLow = z_rd_t * lowRD
generate double PxRxL = Patient * z_rd_t * lowRD
quietly reghdfe entry PxR RxLow PxRxL if es & !missing(lowRD), absorb(`FE') vce(cluster firm)
rec, blk(A5_low) w(-) tr(-) smp(all) vars(PxRxL PxR RxLow)
lincom PxR + PxRxL
post R ("A5_low") ("-") ("-") ("all") ("low_tot") (1000*r(estimate)) (1000*r(se)) (r(p)) (e(N)) (e(N_clust))
generate double RxZ   = z_rd_t * z_rdint
generate double PxRxZ = Patient * z_rd_t * z_rdint
quietly reghdfe entry PxR RxZ PxRxZ if es & !missing(z_rdint), absorb(`FE') vce(cluster firm)
rec, blk(A5_cont) w(-) tr(-) smp(all) vars(PxRxZ PxR RxZ)

postclose R
use `res', clear
format b se %9.4f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar86_dest_current.csv", replace
log close ar86
