# 代码说明

这里是 2026-10-07 这一轮新表用到的 do 文件和 Python 脚本，供老师复核写法。数据不上传。文件内容与本地实际运行的版本一致，只把本机路径换成了相对路径，比如老师面板所在文件夹写成 `data/mentor_panel`，复核时改成自己电脑上的路径即可。

## 哪张表来自哪个文件

表号对应另外发给老师的新表。新表本身不放在仓库里。

| 表 | 文件 |
|---|---|
| 表 3 新增与存续、表 4 稳健性、表 6 机制、表 7 异质性、表 10 功能类型、附表 4、附表 5 | `dofiles/ar26_mentor_spec.do` |
| 表 5 内生性第二阶段、表 8 去向、表 9 第（2）列 | `dofiles/ar29_iv_dyad_mentor.do` |
| 表 1 描述统计、表 5 的 KP LM 统计量、表 9 第（1）列、附表 1、附表 2、附表 3、附表 6 | `dofiles/ar31_skeleton_fill.do` |
| 初稿 8 表 5 三个组间 p 值的复现 | `dofiles/ar28_t5_repro.do` |
| 表 1 原有变量描述统计、表 2 基准、表 4 稳健性、表 5 Heckman、附表 7 安慰剂 | `dofiles/ar34_standalone.do` |
| 排版成 Word | `scripts/ar35_standalone_tables_docx.py`、`scripts/ar32_skeleton_tables_docx.py`、`scripts/ar22_fanwen_lib.py`（`scripts/ar27_mentor_tables_docx.py` 是重排前的版本） |

## 中间数据由哪些脚本生成

| 中间数据 | 脚本 | 来源 |
|---|---|---|
| 复制、互补、新进入、研发互补的分类 | `scripts/ar19_build_complement.py` | 子公司明细 |
| 修正后的研发标签 | `scripts/ar10_build_rdfix.py` | 子公司明细，剔除名称或经营范围含房地产的子公司 |
| 存续变量 | `scripts/ar06_build_survival.py` | 子公司明细 |
| 目的省属性、同行业区位熵、东部企业到中西部的新增 | `scripts/ar05_build_round3.py`、`scripts/ar09_build_m7.py` | 市场化指数、上市公司专利与 TFP、证监会行业代码、子公司明细 |
| 附表 6 的期初生产率换算法 | `scripts/ar12_build_audit.py` | 老师面板 2014 年 TFP，样本少于 10 家的省份设为缺失 |

企业、目的省、年份三维面板 `dyad.dta` 和工具变量数据由本地另一组脚本生成，没有放进来。

## 老师只用自己的面板能复核哪些

表 4、表 6、表 7、附表 2、附表 3、附表 4，以及表 3 第（1）至（3）列和初稿 8 表 5 组间 p 值的复现，只需要老师面板，按 `ar26_mentor_spec.do`、`ar31_skeleton_fill.do` 里“导师主面板”那一段和 `ar28_t5_repro.do` 运行即可。其余各表需要子公司明细、双边面板和工具变量数据，只能看写法。

## 运行环境

Stata 18 MP，do 文件开头固定 `version 15`。需要 `reghdfe`、`ftools`、`ivreghdfe`、`ivreg2`、`ranktest`。Python 3.12，需要 pandas、numpy、python-docx。
