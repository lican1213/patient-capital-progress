* 表8 新增子公司的去向（新版，2026-10-12）
* 用法：16 号、21 号两个数据文件与本命令放在同一文件夹，整份运行；结果写入同目录的“表8命令_新版.log”。
*   16_主面板3_企业目的省年份.dta：10 月 9 日已发（企业×目的省×年份）；
*   21_表8新版变量.dta：本次新增，按 stkcd、dest_id、year 并入 16 号。
* 设定同原表8：当期 Patient；2015 年起；企业×年份、企业×目的省、目的省×年份固定效应；按企业聚类；不加控制变量。
* 市场化、研发资源、GDP 之比用当年值；市场分割取前三年（t-3 至 t-1）均值，每年按高低换算为百分位（当年值不显著，见说明）。
* 需要的外部命令：reghdfe、ftools（ssc install 即可）；Stata 15 及以上。

version 15
clear all
set more off
set varabbrev off
capture log close
log using "表8命令_新版.log", replace text

use "16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "21_表8新版变量.dta", keep(master match) nogenerate
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)

* 估计样本：2015 年起，新设与耐心资本非缺失
generate byte es = year >= 2015 & !missing(entry, Patient)

* 市场分割：前三年均值在当年所有观测中的百分位（0 最低，1 最高）
bysort year: egen double rk  = rank(seg_m3l) if es & !missing(seg_m3l)
bysort year: egen double cnt = count(seg_m3l) if es & !missing(seg_m3l)
generate double seg = (rk - 1) / (cnt - 1)
drop rk cnt

* 市场化、研发资源：在估计样本内标准化
foreach v in mkt_t rd_t {
    quietly summarize `v' if es
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}

generate double PxSeg  = Patient * seg
generate double PxEast = Patient * east
generate double PxCent = Patient * d_cent
generate double PxMkt  = Patient * z_mkt_t
generate double PxRd   = Patient * z_rd_t
generate double PxGdp  = Patient * lngdpr
generate double PxDist = Patient * lndist

* （1）（2）市场分割：全样本、剔除直辖市目的地（市场分割本身随企业×目的省×年份变化，一并放入）
reghdfe entry PxSeg seg if es, absorb(fy fd dyr) vce(cluster firm)
reghdfe entry PxSeg seg if es & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
* （3）东部、中部（西部为对照）
reghdfe entry PxEast PxCent if es, absorb(fy fd dyr) vce(cluster firm)
* （4）—（7）市场化、研发资源、GDP 之比、地理距离（不加权）；本身被固定效应吸收，只放交互项
foreach x in PxMkt PxRd PxGdp PxDist {
    reghdfe entry `x' if es, absorb(fy fd dyr) vce(cluster firm)
}
* （8）市场分割、研发资源、地理距离同时放入
reghdfe entry PxSeg seg PxRd PxDist if es, absorb(fy fd dyr) vce(cluster firm)
log close
