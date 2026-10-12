*------------------------------------------------------------------------------
* File:     explorations/advisor_revision_20261005/dofiles/ar91_t7_seg_tv.do
* Project:  耐心资本与企业跨省投资
* Author:   Claude（第四十八轮第二步：表7 逐年市场分割，分组与交互两种写法）
* Purpose:  规则见本 exploration README 第四十八轮第二步（运行前写定）。
*           市场分割按初稿8 正文公式：2014 年 GDP/距离固定权重 × 当年城市对指数（seg_city）。
* Inputs:   data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta
*           data/derived/prov_seg_20261010/表7_企业年份市场分割_shfix.dta
* Outputs:  本 exploration 的 output/tables/ar91_t7_seg_tv.csv
* Log:      explorations/advisor_revision_20261005/logs/ar91_t7_seg_tv.log
*------------------------------------------------------------------------------
version 15
clear all
set more off
set varabbrev off
set linesize 255

local EXP "explorations/advisor_revision_20261005"
capture log close ar91
log using "`EXP'/logs/ar91_t7_seg_tv.log", name(ar91) replace text

*--- 1. 数据 -------------------------------------------------------------------
use "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta", clear
merge m:1 stkcd year using "data/derived/prov_seg_20261010/表7_企业年份市场分割_shfix.dta", keep(master match) keepusing(seg_city) nogenerate
local C11 INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
local Y 跨省子公司数量占比
egen long nid = group(id)
egen long provn = group(所属省份代码)
egen long prov_year = group(所属省份代码 year)
* 首个样本年总部在北京（与第三十二轮北京检验同一口径）
bysort nid (year): generate str20 prov0 = 母公司所在省份[1]
generate byte bj0 = (prov0 == "北京市")
display "样本：主面板1 观测 " _N "；seg_city 非缺失 "
count if !missing(seg_city)
tabstat seg_city, by(year) statistics(n mean sd p50) format(%9.3f)

*--- 2. 分组：分年中位数（主）、全样本中位数（对照）----------------------------
bysort year: egen double md_y = median(seg_city)
generate byte hiY = (seg_city >= md_y) if !missing(seg_city)
quietly summarize seg_city, detail
generate byte hiA = (seg_city >= r(p50)) if !missing(seg_city)
tab year hiA
* 年内百分位（交互写法）
bysort year: egen double rk0 = rank(seg_city) if !missing(seg_city)
bysort year: egen double nk = count(seg_city)
generate double rk = (rk0 - 1) / (nk - 1)

tempfile res
postfile R str10 blk str8 term double(b se p) long N using `res', replace

*--- 3. 分组回归与组间差异 ----------------------------------------------------
* 写法：主 = absorb(id ind_year)；P = 加省份 FE；样本：全部、剔除北京首年总部
foreach h in hiY hiA {
    foreach f in M P {
        if "`f'" == "M" local FE nid ind_year
        if "`f'" == "P" local FE nid ind_year provn
        foreach s in all nobj {
            if "`s'" == "all"  local IF "1"
            if "`s'" == "nobj" local IF "bj0 == 0"
            local tag `h'_`f'_`s'
            quietly reghdfe `Y' Patient `C11' if `h' == 1 & `IF', absorb(`FE') vce(cluster id)
            post R ("`tag'") ("high") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
            quietly reghdfe `Y' Patient `C11' if `h' == 0 & `IF', absorb(`FE') vce(cluster id)
            post R ("`tag'") ("low") (_b[Patient]) (_se[Patient]) (2*ttail(e(df_r), abs(_b[Patient]/_se[Patient]))) (e(N))
            * 堆叠全交互：两组系数与分组回归相同，检验其差
            capture drop gg
            generate byte gg = `h' if `IF'
            local FEg
            foreach v of local FE {
                local FEg `FEg' `v'#gg
            }
            quietly reghdfe `Y' c.(Patient `C11')#i.gg if !missing(gg), absorb(`FEg') vce(cluster id)
            quietly test 1.gg#c.Patient = 0.gg#c.Patient
            post R ("`tag'") ("diff_stk") (_b[1.gg#c.Patient] - _b[0.gg#c.Patient]) (.) (r(p)) (e(N))
            * 导师模板：中心化 Patient × 低组
            capture drop cP lowg cPxL
            quietly summarize Patient if !missing(gg)
            generate double cP = Patient - r(mean)
            generate byte lowg = 1 - gg
            generate double cPxL = cP * lowg
            quietly reghdfe `Y' cP lowg cPxL `C11' if !missing(gg), absorb(`FE') vce(cluster id)
            post R ("`tag'") ("diff_tpl") (_b[cPxL]) (_se[cPxL]) (2*ttail(e(df_r), abs(_b[cPxL]/_se[cPxL]))) (e(N))
        }
    }
}

*--- 4. 交互写法：Patient × 年内百分位 --------------------------------------
foreach f in M Q {
    if "`f'" == "M" local FE nid ind_year
    if "`f'" == "Q" local FE nid ind_year prov_year
    foreach s in all nobj {
        if "`s'" == "all"  local IF "1"
        if "`s'" == "nobj" local IF "bj0 == 0"
        quietly reghdfe `Y' c.Patient##c.rk `C11' if !missing(rk) & `IF', absorb(`FE') vce(cluster id)
        local dfr = e(df_r)
        local NN = e(N)
        post R ("rk_`f'_`s'") ("PxRk") (_b[c.Patient#c.rk]) (_se[c.Patient#c.rk]) (2*ttail(`dfr', abs(_b[c.Patient#c.rk]/_se[c.Patient#c.rk]))) (`NN')
        foreach q in 25 50 75 {
            quietly lincom Patient + `q'/100*c.Patient#c.rk
            post R ("rk_`f'_`s'") ("me`q'") (r(estimate)) (r(se)) (2*ttail(`dfr', abs(r(estimate)/r(se)))) (`NN')
        }
    }
}

postclose R
use `res', clear
format b se %9.5f
format p %6.3f
list, sep(0) noobs
export delimited using "`EXP'/output/tables/ar91_t7_seg_tv.csv", replace
log close ar91
