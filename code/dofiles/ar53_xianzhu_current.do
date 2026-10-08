*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar53_xianzhu_current.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第十九轮：当期统一后不显著项的 xianzhu 规格搜索）
* Purpose:  规则见本 exploration README 第十九轮（运行前写定）。x 锁定为当期 Patient，每个规格只改一处。
* Inputs:   data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta；
*           data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta
* Outputs:  本 exploration 的 output/tables/ar53_xianzhu.csv
* Log:      explorations/advisor_revision_20261005/logs/ar53_xianzhu_current.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar53
log using "`EXP'/logs/ar53_xianzhu_current.log", name(ar53) replace text
which reghdfe

tempfile res
postfile R str5 blk str6 spec str24 y str12 term double(b se p) long(N) str60 note using `res', replace
capture program drop rec
program define rec
    * 记录一个系数
    syntax, Blk(string) Spec(string) Yv(string) Term(string) [Lab(string) Note(string)]
    if "`lab'" == "" local lab "`term'"
    post R ("`blk'") ("`spec'") ("`yv'") ("`lab'") (_b[`term']) (_se[`term']) ///
        (2*ttail(e(df_r), abs(_b[`term']/_se[`term']))) (e(N)) ("`note'")
end
local C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local Y 跨省子公司数量占比

*=== 1. 表7 基期调节 ===============================================================
use "data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta", clear
egen long nid = group(id)
xtset nid year
egen long prov_year = group(母公司所在省份 year)
* 诊断：l母公司异地市场一体化 是否为水平值的对数
generate double ln_integ = ln(母公司异地市场一体化)
correlate l母公司异地市场一体化 ln_integ 母公司异地市场一体化
local M1 l母公司异地市场一体化
local N1 Integ
local M2 研发投入占营业收入比例
local N2 RD
local M3 供应链韧性
local N3 Resil
local M4 母公司异地市场一体化
local N4 IntegLv
forvalues m = 1/4 {
    local M `M`m''
    local nm `N`m''
    capture drop fy Z tg Zr Zw rk Z14
    bysort nid (year): egen fy = min(cond(!missing(`M'), year, .))
    bysort nid (year): egen Z = max(cond(year == fy, `M', .))
    * 企业层面的百分位秩与缩尾（每家企业只计一次）
    egen byte tg = tag(nid) if !missing(Z)
    egen double rk = rank(Z) if tg == 1
    quietly count if tg == 1
    generate double Zr = rk / r(N)
    bysort nid (Zr): replace Zr = Zr[1]
    _pctile Z if tg == 1, percentiles(1 99)
    generate double Zw = min(max(Z, r(r1)), r(r2)) if !missing(Z)
    bysort nid (year): egen Z14 = max(cond(year == 2014, `M', .))
    local specs = cond(`m' == 4, "H0", "H0 R W Y14 F1 F2")
    foreach s of local specs {
        local zz = cond("`s'" == "R", "Zr", cond("`s'" == "W", "Zw", cond("`s'" == "Y14", "Z14", "Z")))
        local fe = cond("`s'" == "F1", "nid ind_year", cond("`s'" == "F2", "nid year", "nid ind_year prov_year"))
        local cond = cond("`s'" == "Y14", "year > 2014 & !missing(Z14)", "year > fy & !missing(Z)")
        capture drop ZZ
        generate double ZZ = `zz'
        reghdfe `Y' c.Patient##c.ZZ `C' if `cond', absorb(`fe') vce(cluster nid)
        local sp = cond(`m' == 4, "Lv", "`s'")
        local mm = cond(`m' == 4, "Integ", "`nm'")
        rec, blk(H) spec(`sp') yv(`mm') term(c.Patient#c.ZZ) lab(XxZ)
        rec, blk(H) spec(`sp') yv(`mm') term(Patient) lab(X)
        quietly summarize ZZ if e(sample), detail
        local z25 = r(p25)
        local z75 = r(p75)
        local NN = e(N)
        local dfr = e(df_r)
        foreach q in 25 75 {
            quietly lincom Patient + `z`q''*c.Patient#c.ZZ
            post R ("H") ("`sp'") ("`mm'") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN') ("")
        }
    }
}

*=== 2. 表3 存续（当期写法）=======================================================
generate double lstock = ln(1 + 跨省子公司数量)
foreach v in cross_surv3_num cross_surv3_rate cross_surv5_num cross_surv5_rate {
    local yy = cond(strpos("`v'", "surv3"), 2021, 2019)
    local S "跨省子公司数量 > 0 & year <= `yy'"
    reghdfe `v' Patient `C' if `S', absorb(id ind_year) vce(cluster id)
    rec, blk(S) spec(C0) yv(`v') term(Patient)
    * C1 缩尾
    capture drop yw
    quietly _pctile `v' if `S', percentiles(1 99)
    generate double yw = min(max(`v', r(r1)), r(r2)) if !missing(`v')
    reghdfe yw Patient `C' if `S', absorb(id ind_year) vce(cluster id)
    rec, blk(S) spec(C1) yv(`v') term(Patient)
    * C2 连续存续口径
    local vc = subinstr(subinstr("`v'", "_num", "_cont_num", .), "_rate", "_cont_rate", .)
    capture confirm variable `vc'
    if !_rc {
        reghdfe `vc' Patient `C' if `S', absorb(id ind_year) vce(cluster id)
        rec, blk(S) spec(C2) yv(`v') term(Patient) note(`vc')
    }
    if strpos("`v'", "num") {
        * C3 ln(1+x)
        capture drop yl
        generate double yl = ln(1 + `v')
        reghdfe yl Patient `C' if `S', absorb(id ind_year) vce(cluster id)
        rec, blk(S) spec(C3) yv(`v') term(Patient)
        * C4 控制基期存量
        reghdfe `v' Patient lstock `C' if `S', absorb(id ind_year) vce(cluster id)
        rec, blk(S) spec(C4) yv(`v') term(Patient)
    }
}

*=== 3. 双边：市场分割秩、区位熵写法 ===============================================
use "data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta", clear
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
summarize lq, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
foreach v in mkt0 rdres0 tfp0 lqw {
    quietly summarize `v'
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
* D1 市场分割百分位秩（在 2015 年起的估计样本内）
egen double rs = rank(Seg0_z) if year >= 2015 & !missing(Seg0_z, entry, Patient)
quietly count if !missing(rs)
generate double Seg_r = rs / r(N)
foreach s in D0 D1 {
    local sv = cond("`s'" == "D0", "Seg0_z", "Seg_r")
    capture drop Px
    generate double Px = Patient * `sv'
    reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    rec, blk(D) spec(`s') yv(seg_all) term(Px)
    reghdfe entry Px if year >= 2015 & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
    rec, blk(D) spec(`s') yv(seg_nomuni) term(Px)
}
* 区位熵
generate double llq = ln(1 + lq)
quietly summarize llq
generate double z_llq = (llq - r(mean)) / r(sd)
egen double rq = rank(lq) if year >= 2015 & !missing(lq, entry, Patient)
quietly count if !missing(rq)
generate double lq_r = rq / r(N)
generate byte lq1 = (lq > 1) if !missing(lq)
foreach s in E0 E1 E2 E3 {
    local a = cond("`s'" == "E0", "z_lqw", cond("`s'" == "E1", "z_llq", cond("`s'" == "E2", "lq_r", "lq1")))
    capture drop Px
    generate double Px = Patient * `a'
    reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    rec, blk(E) spec(`s') yv(lq) term(Px)
}
summarize lq1 if year >= 2015 & !missing(entry)
* 表9 诊断：目的省层面属性相关
preserve
collapse (first) east mkt0 rdres0 tfp0, by(dest_id)
correlate east mkt0 rdres0 tfp0
restore

postclose R
use `res', clear
format b se p %12.6f
list, sepby(blk) noobs
export delimited using "`EXP'/output/tables/ar53_xianzhu.csv", replace
log close ar53
