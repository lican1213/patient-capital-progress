* 新表命令（当期统一版，2026-10-08 晚，加附表6—10）
* 用法：把下面四个数据文件的路径改成您电脑上的位置，整份运行；结果写入同目录的“新表命令_当期统一.log”。
* 这份命令复现新表全部回归（表1 描述统计除外）；新增数据的变量来源见 17 号说明，主面板3 的构造代码需要时另发。
*   主面板1：您 10 月 8 日发来的主面板1（含区位熵_地理IV_创新指标），企业层各表；
*   主面板1补充变量：我这次发您的“18_主面板1补充变量.dta”，按 stkcd、year 并入主面板1，表5第（3）—（5）列、表10、附表1、附表3 用；
*   主面板3：我这次发您的“16_主面板3_企业目的省年份.dta”，表8、表9、附表4、附表6、附表9、附表10；
*   主面板2：您发来的主面板2（关联公司具体细节），文件最后用它重建“当年新设”，核对主面板3。
* 控制变量、固定效应、聚类按您的“实证代码2”：11 个控制变量，企业＋行业×年份固定效应，按企业聚类。
* 耐心资本一律取当期，与基准回归一致；表4第（2）列是您原有的滞后一期稳健性；
* 表7、表3存续、表8、表9 取上一期的写法放在附表7—10，作稳健性检验。
* 基期：异质性的调节变量取该企业首个可观察年份的值，回归只用基期之后的年份；
*       表8、表9 的目的省属性固定在样本期前（市场分割、市场化、研发资源、同行业区位熵取 2010—2013 年均值，期初生产率取 2014 年）。
* 需要的外部命令：reghdfe、ftools、psmatch2、ivreghdfe、ivreg2、ranktest（ssc install 即可）；中文变量名需要 Stata 14 及以上。

version 15
clear all
set more off
set varabbrev off
capture log close
log using "新表命令_当期统一.log", replace text

use "主面板1(含区位熵_地理IV_创新指标).dta", clear

global C INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE l第三产业增加值省份
* 面板里的 id 是六位代码（字符型），做滞后需要数值型面板编号
egen long nid = group(id)
xtset nid year

********** 表2 基准回归 **********
reghdfe 跨省子公司数量占比 Patient, absorb(id ind_year) vce(cluster id)
reghdfe 跨省子公司数量占比 Patient INV Dual Lev Cashflow Indep Top5 TobinQ ROA Growth SOE, absorb(id ind_year) vce(cluster id)
reghdfe 跨省子公司数量占比 Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe 同省异市数量占比 Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe 同城子公司数量占比 Patient $C, absorb(id ind_year) vce(cluster id)

********** 表3 新增与存续 **********
reghdfe l新增跨省子公司数量 Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe l新增跨省子公司注册资本 Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe l新增同省异市子公司数量 Patient $C, absorb(id ind_year) vce(cluster id)
* 存续：解释变量与控制变量取存续起算当年（当期）
reghdfe cross_surv3_num Patient $C if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv3_rate Patient $C if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv5_num Patient $C if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv5_rate Patient $C if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)
* 附表8：解释变量与控制变量取上一期（您原来的写法）
reghdfe cross_surv3_num L.(Patient $C) if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv3_rate L.(Patient $C) if 跨省子公司数量 > 0 & year <= 2021, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv5_num L.(Patient $C) if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)
reghdfe cross_surv5_rate L.(Patient $C) if 跨省子公司数量 > 0 & year <= 2019, absorb(id ind_year) vce(cluster id)

********** 表4 稳健性 **********
* （1）替换被解释变量
reghdfe 跨省子公司资本占比 Patient $C, absorb(id ind_year) vce(cluster id)
* （2）上一自然年的 Patient（面板原有的 L_Patient 在年份不连续处取的是上一条记录，这里用 xtset 后的 L.）
reghdfe 跨省子公司数量占比 L.Patient $C, absorb(id ind_year) vce(cluster id)
* （3）替换解释变量：稳定型机构投资者持股比例（相对流通A股）
reghdfe 跨省子公司数量占比 稳定型机构投资者持股比例_相对流通A股 $C, absorb(id ind_year) vce(cluster id)
* （4）剔除超大、特大城市
capture drop ty
generate byte ty = 1
replace ty = 0 if inlist(city_out, "上海市","北京市","深圳市","重庆市","广州市","成都市","天津市")
replace ty = 0 if inlist(city_out, "武汉市","东莞市","西安市","杭州市","佛山市","南京市")
replace ty = 0 if inlist(city_out, "沈阳市","青岛市","济南市","长沙市","哈尔滨市","郑州市")
replace ty = 0 if inlist(city_out, "昆明市","大连市","苏州市")
reghdfe 跨省子公司数量占比 Patient $C if ty == 1, absorb(id ind_year) vce(cluster id)
* （5）控制区域战略
capture drop belt_and_road yangtze_delta greater_bay chengyu
generate byte belt_and_road = inlist(母公司所在省份, "福建省","陕西省","甘肃省","新疆维吾尔自治区") & year >= 2013
generate byte yangtze_delta = inlist(母公司所在省份, "上海市","江苏省","浙江省","安徽省") & year >= 2018
generate byte greater_bay = (母公司所在省份 == "广东省") & year >= 2017
generate byte chengyu = inlist(母公司所在省份, "四川省","重庆市") & year >= 2020
reghdfe 跨省子公司数量占比 Patient belt_and_road yangtze_delta greater_bay chengyu $C, absorb(id ind_year) vce(cluster id)
* （7）剔除总部在直辖市的企业
generate byte h_muni = inlist(母公司所在省份, "北京市", "天津市", "上海市", "重庆市")
reghdfe 跨省子公司数量占比 Patient $C if h_muni == 0, absorb(id ind_year) vce(cluster id)

********** 表5 第（1）（2）列 Heckman **********
capture drop treated xb imr
generate byte treated = (Patient > 0) if !missing(Patient)
probit treated $C 高新技术企业 i.year, vce(cluster id)
predict double xb if e(sample), xb
* 有耐心资本取 φ/Φ，没有的取 −φ/(1−Φ)
generate double imr = normalden(xb) / normal(xb) if treated == 1
replace imr = -normalden(xb) / (1 - normal(xb)) if treated == 0
reghdfe 跨省子公司数量占比 Patient $C imr, absorb(id ind_year) vce(cluster id)

********** 表4 第（6）列 PSM **********
capture drop _weight _pscore _treated _support _id _n1 _nn _pdif
psmatch2 treated $C, outcome(跨省子公司数量占比) neighbor(1) common caliper(0.05) ties
reghdfe 跨省子公司数量占比 Patient $C if _weight != ., absorb(id ind_year) vce(cluster id)

********** 表6 机制第一步、附表2 第二步 **********
foreach m in ln_myopia_words WW指数 ASY SCDRisk2_100倍 供应链韧性 l母公司当年独立专利总和 lcross_sub_indep 集团创新地理分散度 {
    reghdfe `m' Patient $C, absorb(id ind_year) vce(cluster id)
    reghdfe 跨省子公司数量占比 Patient `m' $C, absorb(id ind_year) vce(cluster id)
}

********** 表7 异质性（基期调节）；附表7 同样写法取上一期 **********
* 基期：调节变量在该企业首个可观察年份的值（前定）；回归只用基期之后的年份；
* 基期值的水平项被企业固定效应吸收；固定效应为企业、行业×年份、母公司省份×年份。
capture drop prov_year Lp
egen long prov_year = group(母公司所在省份 year)
* 上一自然年的 Patient（附表7 用）
generate double Lp = L.Patient
foreach M in l母公司异地市场一体化 研发投入占营业收入比例 供应链韧性 {
    capture drop fy Z
    bysort nid (year): egen fy = min(cond(!missing(`M'), year, .))
    bysort nid (year): egen Z = max(cond(year == fy, `M', .))
    * 表7：当期 Patient；附表7：上一期 Patient（Lp）
    foreach X in Patient Lp {
        display _newline "==== 调节变量：`M'，解释变量：`X' ===="
        reghdfe 跨省子公司数量占比 c.`X'##c.Z $C if year > fy & !missing(Z), absorb(nid ind_year prov_year) vce(cluster nid)
        * 边际效应：基期调节变量取估计样本 25%、50%、75% 分位数
        quietly summarize Z if e(sample), detail
        local z25 = r(p25)
        local z50 = r(p50)
        local z75 = r(p75)
        lincom `X' + `z25'*c.`X'#c.Z
        lincom `X' + `z50'*c.`X'#c.Z
        lincom `X' + `z75'*c.`X'#c.Z
    }
}

********** 并入补充变量（表5第（3）—（5）列、表10、附表1、附表3 用）**********
capture drop _merge
merge 1:1 stkcd year using "18_主面板1补充变量.dta", nogenerate
* 合并后重新设定面板，滞后算子 L. 才能用
xtset nid year

********** 表5第（3）—（5）列：工具变量法（当期 Patient）；附表1：第一阶段 **********
* （3）同群工具：同年同机构持股分位组、同资产规模分位组内其他企业的 Patient 均值
ivreghdfe 跨省子公司数量占比 (Patient = IV_Hold2 IV_SizeGroup2) $C, absorb(nid year) cluster(nid)
reghdfe Patient IV_Hold2 IV_SizeGroup2 $C if e(sample), absorb(nid year) vce(cluster nid)
* （4）（5）上一期签署 PRI 的基金数、持股比例（先签署、后影响持股）
capture drop l_Pri_Number l_Pri_Hold
generate double l_Pri_Number = L.Pri_Number
generate double l_Pri_Hold = L.Pri_Hold
foreach z in l_Pri_Number l_Pri_Hold {
    ivreghdfe 跨省子公司数量占比 $C (Patient = `z'), absorb(nid year) cluster(nid)
    reghdfe Patient `z' $C if e(sample), absorb(nid year) vce(cluster nid)
}

********** 表10 新增跨省子公司的功能类型 **********
foreach v in n_new n_rep n_comp new_x_rdfix n_rdcomp new_ECW {
    capture drop l_`v'
    generate double l_`v' = ln(1 + `v')
}
* （1）进入新省份（2）同功能复制（3）功能互补（4）研发型（5）研发互补
foreach v in n_new n_rep n_comp new_x_rdfix n_rdcomp {
    reghdfe l_`v' Patient $C, absorb(id ind_year) vce(cluster id)
}
* （6）东部企业到中西部
reghdfe l_new_ECW Patient $C if home_east == 1, absorb(id ind_year) vce(cluster id)

********** 附表3 管理者短视的占比口径（自建 LMDA）**********
reghdfe LMDA Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe 跨省子公司数量占比 Patient LMDA $C, absorb(id ind_year) vce(cluster id)

********** 补充：给您参考的写法（未放进新表）**********
* LMDA 按胡楠等（2021）原定义用占比：面板里的 myopia＝短视词数/总词数×100
capture drop ln_myopia_ratio
generate double ln_myopia_ratio = ln(1 + myopia)
reghdfe ln_myopia_ratio Patient $C, absorb(id ind_year) vce(cluster id)
reghdfe 跨省子公司数量占比 Patient ln_myopia_ratio $C, absorb(id ind_year) vce(cluster id)

********** 附表5 安慰剂检验（较慢，约十几分钟）**********
preserve
reghdfe 跨省子公司数量占比 Patient $C, absorb(id ind_year) vce(cluster id)
local true_b = _b[Patient]
keep if e(sample)
keep 跨省子公司数量占比 Patient $C id year ind_year
* 先按企业、年份排序再设种子，抽样结果与表中数字逐格一致
sort id year
set seed 20261008
tempfile plc
postfile Q double(b p) using `plc', replace
forvalues i = 1/1000 {
    quietly {
        generate double placebo = Patient[runiformint(1, _N)]
        reghdfe 跨省子公司数量占比 placebo $C, absorb(id ind_year) vce(cluster id)
        post Q (_b[placebo]) (2*ttail(e(df_r), abs(_b[placebo]/_se[placebo])))
        drop placebo
    }
}
postclose Q
use `plc', clear
* 模拟系数不小于真实系数的比例、p<0.1 的比例、模拟系数均值与标准差
count if b >= `true_b'
count if p < .10
summarize b
restore

********** 表8、表9、附表4、附表6、附表9、附表10：企业×目的省×年份 **********
use "16_主面板3_企业目的省年份.dta", clear
* 被解释变量 entry：当年是否在该省新设跨省子公司；新设＝子公司第一次出现在子公司明细中；企业首个样本年无法判断，为缺失
generate byte d_muni = inlist(dest, "北京市", "天津市", "上海市", "重庆市")
egen long fy   = group(stkcd year)
egen long fd   = group(stkcd dest_id)
egen long dyr  = group(dest_id year)
egen long firm = group(stkcd)
bysort stkcd: egen int fy0 = min(year)
* 同行业区位熵在 99% 分位处截尾，各属性标准化
summarize lq, detail
generate double lqw = min(lq, r(p99)) if !missing(lq)
foreach v in mkt0 rdres0 tfp0 lqw tfp0_n10 {
    quietly summarize `v'
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}
replace new_rdfix_any = 0 if missing(new_rdfix_any)
replace new_rdfix_any = . if year <= fy0
* 当期 Patient：表8、表9、附表4；上一期 L_Patient：附表9（同表8）、附表10（同表9）
foreach X in Patient L_Patient {
    display _newline "==== 解释变量：`X' ===="
    * 表8 第（1）（2）列：基期市场分割
    capture drop Px
    generate double Px = `X' * Seg0_z
    reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    reghdfe entry Px if year >= 2015 & d_muni == 0, absorb(fy fd dyr) vce(cluster firm)
    * 表8 第（3）—（7）列：东部、市场化、研发资源、期初生产率、同行业区位熵
    foreach a in east z_mkt0 z_rdres0 z_tfp0 z_lqw {
        capture drop Px
        generate double Px = `X' * `a'
        reghdfe entry Px if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    }
    * 表9 第（1）列：五项属性联合估计
    reghdfe entry c.`X'#c.(east z_mkt0 z_rdres0 z_tfp0 z_lqw) if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    * 附表4（只取当期）：期初生产率剔除上市公司少于 10 家的省份
    if "`X'" == "Patient" {
        reghdfe entry c.`X'#c.(east z_mkt0 z_rdres0 z_tfp0_n10 z_lqw) if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
    }
    * 表9 第（2）列：研发型新增
    capture drop Px
    generate double Px = `X' * z_rdres0
    reghdfe new_rdfix_any Px, absorb(fy fd dyr) vce(cluster firm)
}

********** 附表6 市场分割的稳健性与短期机构对照（您原表8的写法，解释变量取当期）**********
* lndist：母公司城市到目的省的球面距离对数；io_short：当期短期（非长期）主动机构持股比例
* 把 Patient、io_short 换成 L_Patient、L_io_short，即逐格得到您原表8
* （1）基准（即表8第（1）列）
reghdfe entry c.Patient#c.Seg0_z if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
* （2）加入 Patient×距离对数
reghdfe entry c.Patient#c.Seg0_z c.Patient#c.lndist if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
* （3）按企业和目的省双向聚类
reghdfe entry c.Patient#c.Seg0_z if year >= 2015, absorb(fy fd dyr) vce(cluster firm dest_id)
* （4）标准化 Patient 与短期机构持股（在 2015 年起的样本上标准化）
capture drop z_P z_S
egen double z_P = std(Patient) if year >= 2015
egen double z_S = std(io_short) if year >= 2015
reghdfe entry c.z_P#c.Seg0_z c.z_S#c.Seg0_z if year >= 2015, absorb(fy fd dyr) vce(cluster firm)
* 差异检验：H1 为耐心资本的交互大于短期机构持股的交互，单侧 p 值
lincom _b[c.z_P#c.Seg0_z] - _b[c.z_S#c.Seg0_z]
display "单侧p值 = " ttail(r(df), r(estimate)/r(se))

********** 用主面板2 重建“当年新设”，核对主面板3 的 entry **********
preserve
use stkcd sub_name year province_in using "主面板2(关联公司具体细节).dta", clear
bysort stkcd sub_name: egen int first = min(year)
generate byte new = (year == first)
collapse (max) new, by(stkcd year province_in)
rename province_in dest
tempfile nw
save `nw'
restore
merge 1:1 stkcd year dest using `nw', keep(master match) nogenerate
replace new = 0 if missing(new)
* 应为 0：两者逐格相同（不为 0 时这里会报错停下）
count if !missing(entry) & new != entry
assert r(N) == 0
log close
