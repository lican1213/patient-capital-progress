* 表8 新增子公司的去向（时变版，2026-10-12）
* 用法：16 号、20 号两个数据文件与本命令放在同一文件夹，整份运行；结果写入同目录的“表8命令_时变版.log”。
*   16_主面板3_企业目的省年份.dta：10 月 9 日已发（企业×目的省×年份）；
*   20_表8时变变量.dta：本次新增，按 stkcd、dest_id、year 并入 16 号。
* 设定同原表8：当期 Patient；2015 年起；企业×年份、企业×目的省、目的省×年份固定效应；按企业聚类；不加控制变量。
* 目的地特征都在新设当年之前测量：市场分割取前三年（t-3 至 t-1）均值，市场化、研发资源取上一年；东部不随时间变；期初生产率为 2014 年。
* 需要的外部命令：reghdfe、ftools（ssc install 即可）；Stata 15 及以上。

version 15
clear all
set more off
set varabbrev off
capture log close
log using "表8命令_时变版.log", replace text

use "16_主面板3_企业目的省年份.dta", clear
merge 1:1 stkcd dest_id year using "20_表8时变变量.dta", keep(master match) nogenerate
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

* 其余目的地特征：在估计样本内标准化
summarize lq if es, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
foreach v in mkt_l1 rd_l1 tfp0 lqw {
    quietly summarize `v' if es
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}

generate double PxSeg  = Patient * seg
generate double PxEast = Patient * east
generate double PxMkt  = Patient * z_mkt_l1
generate double PxRd   = Patient * z_rd_l1
generate double PxTfp  = Patient * z_tfp0
generate double PxLq   = Patient * z_lqw
generate double PxDist = Patient * lndist

* （1）（2）市场分割：全样本、剔除直辖市目的地（市场分割本身随企业×目的省×年份变化，不被固定效应吸收，一并放入）
reghdfe entry PxSeg seg if es, absorb(fy fd dyr) vce(cluster firm)
reghdfe entry PxSeg seg if es & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
* （3）—（7）东部、市场化、研发资源、期初生产率、同行业区位熵（水平项被目的省×年份固定效应吸收）
foreach x in PxEast PxMkt PxRd PxTfp PxLq {
    reghdfe entry `x' if es, absorb(fy fd dyr) vce(cluster firm)
}
* （8）市场分割、研发资源、地理距离（不加权）同时放入（距离水平项被企业×目的省固定效应吸收）
reghdfe entry PxSeg seg PxRd PxDist if es, absorb(fy fd dyr) vce(cluster firm)
log close
