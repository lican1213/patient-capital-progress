*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar71_seg_leaveout.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第三十一轮：表8 市场分割逐省剔除）
* Purpose:  规则见本 exploration README 第三十一轮（运行前写定）。写法同表8 第（1）列：
*           (A) 逐个剔除目的省；(B) 只留直辖市目的地；(C) 剔除首年总部在直辖市的企业；(D) (C) 且剔除直辖市目的地。
* Inputs:   data/derived/advisor_send_20261008/主面板3_企业目的省年份_v3.dta；data/derived/analysis_ready.dta（首年总部省份）
* Outputs:  本 exploration 的 output/tables/ar71_seg_leaveout.csv
* Log:      explorations/advisor_revision_20261005/logs/ar71_seg_leaveout.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar71
log using "`EXP'/logs/ar71_seg_leaveout.log", name(ar71) replace text
which reghdfe

* 企业首个样本年的总部省份
use stkcd year 母公司所在省份 using "data/derived/analysis_ready.dta", clear
sort stkcd year
by stkcd: keep if _n == 1
generate byte hq_muni0 = inlist(母公司所在省份, "北京市", "天津市", "上海市", "重庆市")
keep stkcd hq_muni0
tempfile hq
save `hq'

use "data/derived/advisor_send_20261008/主面板3_企业目的省年份_v3.dta", clear
merge m:1 stkcd using `hq', keep(master match)
assert _merge == 3
drop _merge
keep if year >= 2015
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
generate double Px = Patient * Seg0_z
egen byte tagf = tag(stkcd)
count if tagf & hq_muni0 == 1

tempfile res
postfile R str12 spec str12 drop double(b se p) long(N nc) using `res', replace
capture program drop rec
program define rec
    syntax, Spec(string) Drop(string)
    post R ("`spec'") ("`drop'") (_b[Px]) (_se[Px]) (2*ttail(e(df_r), abs(_b[Px]/_se[Px]))) (e(N)) (e(N_clust))
end
local FE fy fd dyr
* 基准（应等于表8 第（1）列）
reghdfe entry Px, absorb(`FE') vce(cluster firm)
assert abs(_b[Px] - .0015551052563936) < 1e-9
rec, spec(base) drop(none)
* (A) 逐个剔除目的省
levelsof dest, local(D)
foreach d of local D {
    quietly reghdfe entry Px if dest != "`d'", absorb(`FE') vce(cluster firm)
    rec, spec(A_drop) drop(`d')
}
* (B) 只留直辖市目的地
reghdfe entry Px if d_muni == 1, absorb(`FE') vce(cluster firm)
rec, spec(B_munionly) drop(non_muni)
* (C) 剔除首年总部在直辖市的企业
reghdfe entry Px if hq_muni0 == 0, absorb(`FE') vce(cluster firm)
rec, spec(C_nomunihq) drop(muni_hq)
* (D) 再剔除直辖市目的地
reghdfe entry Px if hq_muni0 == 0 & d_muni == 0, absorb(`FE') vce(cluster firm)
rec, spec(D_both) drop(muni_hq_dest)
* 各目的省新设次数，便于解读
tabstat entry, by(dest) statistics(sum mean) nototal
postclose R
use `res', clear
format b se p %12.8f
sort spec p
list, clean noobs sep(0)
export delimited using "`EXP'/output/tables/ar71_seg_leaveout.csv", replace
log close ar71
