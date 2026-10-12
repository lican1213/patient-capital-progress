# 代码说明

这里是 2026-10-08 这一轮（含晚上补的附表 6 到附表 10，以及市场分割母公司城市统一取第一年）新表用到的 do 文件和 Python 脚本，供老师复核写法。数据不上传。文件内容与本地实际运行的版本一致，只把本机路径换成了相对路径，比如老师面板所在文件夹写成 `data/mentor_panel`，复核时改成自己电脑上的路径即可。上一轮（10 月 7 日）的代码放在 `旧版_20261007/`。

## 老师直接运行哪个

`新表命令_当期统一.do`。用老师的主面板1、主面板2 和另外发给老师的两份数据（主面板3、主面板1补充变量），改四个数据路径就能整份运行，复现新表全部回归（含附表 6 到附表 10）；写法按老师的“实证代码2”。需要 `reghdfe`、`ftools`、`psmatch2`、`ivreghdfe`、`ivreg2`、`ranktest`，需要 Stata 15 及以上。

## 哪张表来自哪个文件（本地出表用）

表号对应另外发给老师的新表。新表本身不放在仓库里。

| 表 | 文件 |
|---|---|
| 表 2 基准、表 3 第（1）—（3）列、表 4 稳健性、表 5 Heckman、表 6 机制、附表 2、附表 3，以及表 1 原有变量 | `dofiles/ar45_unify_mentor_do.do` |
| 表 3 存续（当期）、表 7 异质性（基期调节）、表 8、表 9、附表 4，附表 7 到附表 10（取上一期），以及用主面板2 核对“当年新设” | `dofiles/ar51_oct8_tables.do` |
| 附表 6 市场分割的稳健性与短期机构对照（旧表 8 三列，当期） | `dofiles/ar65_oldtable8_current.do` |
| 表 8 第（1）（2）列、附表 6、附表 9 第（1）（2）列与表 1 分割行（母公司城市取企业第一年，现行） | `dofiles/ar69_dyad_seg.do` |
| 母公司城市取当年总部与取第一年的对比、剔除换过总部企业的检验 | `dofiles/ar68_seg0_firstcity.do` |
| 表 7 第（1）列不依赖企业布局的基期市场分割：等权版 | `dofiles/ar63_hetero_eqweight.do` |
| 表 7 第（1）列不依赖企业布局的基期市场分割：GDP/距离加权、有 GDP 和坐标的外省城市版 | `dofiles/ar64_hetero_gdpdist.do` |
| 表 1 存续变量的描述统计 | `dofiles/ar51b_surv_desc.do` |
| 表 5 工具变量列、附表 1 | `dofiles/ar57_iv_current.do` |
| 表 10 功能类型、附表 5 安慰剂、表 1 双边与功能类型变量的描述统计 | `dofiles/ar59_sync.do` |
| 主面板1补充变量（同群工具、PRI、功能类型新增、自建管理者短视） | `dofiles/ar60_build_addon.do` |
| 表 7 第（1）列换成面板里的母公司异地市场分割的试算 | `dofiles/ar58_hetero_seg.do` |
| 表 8 市场分割换基期（2014 年、当年值）与耐心资本取当期、上一期的比较 | `dofiles/ar49_timing_base.do` |
| 不显著项的写法检查（百分位排序、缩尾、取对数等） | `dofiles/ar53_xianzhu_current.do` |

## 中间数据由哪些脚本生成

| 中间数据 | 脚本 | 来源 |
|---|---|---|
| 主面板3（企业×目的省×年份） | `scripts/ar51_export_panel3.py`，附表 6 用的三列由 `scripts/ar66_export_panel3_v2.py` 加入，三列市场分割由 `scripts/ar69_export_panel3_v3.py` 改为母公司城市取企业第一年（现发版本） | 子公司明细（与老师主面板2 同源）、目的省属性、区位熵、研发标签；距离对数、短期机构持股 |
| 市场分割母公司城市取第一年的对比数据 | `scripts/ar68_build_seg0_firstcity.py` | 城市对市场分割指数，先核对能复现原来按当年总部算的值 |
| 当期短期机构持股 | `scripts/ar65_build_io_short.py` | 机构持股明细，筛选与旧表 8 相同，不做年份平移 |
| 企业基期市场分割（等权） | `scripts/ar63_build_eqweight.py` | 城市对市场分割指数，母公司第一年所在城市 |
| 企业基期市场分割（GDP/距离加权） | `scripts/ar64_build_gdpdist.py` | 同上，加老师主面板2 的城市 2014 年 GDP 与城市经纬度 |
| 市场分割的不同基期 | `scripts/ar49_build_seg_base.py` | 城市对市场分割指数（基于价格指数） |
| 市场分割逐年相关 | `scripts/ar49c_seg_yearcorr.py` | 同上 |
| 新增认定与功能分类、研发型新增、东部企业到中西部新增 | `scripts/ar43_build_events.py` | 子公司明细 |
| 目的省市场化、研发资源，期初生产率，同行业区位熵 | `scripts/ar05_build_round3.py`、`scripts/ar09_build_m7.py` | 市场化指数、上市公司专利与 TFP、证监会行业代码 |

自建管理者短视的下载、抽取和计算脚本见 `旧版_20261007/scripts/ar39`—`ar41`，这一轮没有变。

## 运行环境

Stata 18 MP，do 文件开头固定 `version 15`。Python 3.12，需要 pandas、numpy。

说明：城市对市场分割数据的文件名带“有方向”，但 A→B 与 B→A 数值完全相同，是两个城市之间的指数。代码里的文件名照原样保留，说明文字统一写“城市对市场分割指数”。

## 10 月 9 日至 12 日新增的代码

做法的逐步说明见 [`../rounds/2026-10-12/处理过程与手法.md`](../rounds/2026-10-12/处理过程与手法.md)。统计年鉴原始表来自国家统计局网站，不上传。

| 内容 | 文件 |
|---|---|
| 表 8 市场分割逐省剔除（30 个目的省轮流去掉） | `dofiles/ar71_seg_leaveout.do` |
| 距离省内按 GDP 加权的试算 | `scripts/ar74_build_gdpdist_prov.py`、`dofiles/ar74_dist_gdpweight.do` |
| 统计年鉴分地区商品零售价格分类指数录入（16 类，2008—2022） | `scripts/ar75_build_price_panel.py`；图片识别工具 `scripts/ar75_ocr/` |
| 统计年鉴分地区居民消费价格分类指数录入（8 类，2008—2024） | `scripts/ar76_build_cpi_panel.py` |
| 省对市场分割指数（桂琦寒等 2006 价格法）、表 7 老师权重与表 8 省对值 | `scripts/ar75_build_prov_seg.py`（含上海修正，两类价格共用） |
| 年鉴口径表 7、表 8 回归及北京、直辖市检验 | `dofiles/ar75_prov_seg.do`、`dofiles/ar75b_t7_beijing.do`、`dofiles/ar76_prov_seg_cpi8.do`、`dofiles/ar76b_t7_beijing_cpi8.do` |
| 修正上海后复跑表 7 | `dofiles/ar77_t7_shfix.do` |
| 近三年、前三年均值与相邻省法 | `scripts/ar78_build_seg_variants.py`、`dofiles/ar78_seg_variants.do` |
| 按近年文献选商品类别 | `scripts/ar79_goods_subsets.py`、`dofiles/ar79_goods_subsets.do` |
| 缩尾、取对数、年内百分位 | `dofiles/ar80_transforms.do` |
| 10 月 12 日交互一稿：逐年市场分割、逐年研发资源、不加权距离 | `scripts/ar81_build_rd_year.py`、`dofiles/ar81_mentor_interact.do` |
| 上一年市场分割的北京、直辖市检验；市场化逐年 | `dofiles/ar82_seg_lag_mkt_year.do` |
| 老师城市对指数的逐年原始值、三年均值 | `scripts/ar83_build_seg_raw.py` |
| 4 种时点 × 5 种处理的市场分割写法 | `dofiles/ar83_seg_scale.do` |
| 前三年均值年内百分位的稳健性 | `dofiles/ar84_rk_robust.do` |
| 新表 8（时变版）：老师可直接运行的命令 | `表8命令_时变版.do`（需 16 号、20 号数据） |
| 20 号数据：市场分割前三年均值、市场化与研发上一年 | `scripts/ar85_export_t8vars.py` |
| 新表 8 本地出表、Word | `dofiles/ar85_t8_timevary.do`、`scripts/ar85_t8_docx.py` |
| 新表 8 独立核对（构造重算、命令复跑、表格比对） | `scripts/ar85_audit.py` |
| 百分位改在不重复数值上排序的检验 | `dofiles/ar85b_rank_distinct.do` |
