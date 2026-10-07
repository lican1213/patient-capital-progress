"""ar35_standalone_tables_docx.py — 回复导师用的新表，独立成册（导师原规格）。

由 ar32 改写：作者要求不再引用初稿8，表1补齐原有变量，表2基准、表4稳健性、表5 Heckman、附表7安慰剂改用 ar34 重新估计的结果。
输入（只读）：本 exploration 的 output/tables/ 下
  ar26_mentor_spec.csv（企业层）；ar29_iv_dyad_mentor.csv（工具变量、双边）；
  ar31_skeleton_fill.csv（KP LM、第一阶段、机制两步、异质性交互、五项联合）；ar31_desc.csv（描述统计）
  ar34_standalone.csv（基准、稳健性、Heckman、安慰剂）；ar34_desc.csv（原有变量描述统计）
  ar44_fix.csv、ar44_desc.csv（第十三轮按 D-135 审计定点修正：Heckman 正负两支 IMR、表4第（2）列自然年滞后、
  表10与表9第（2）列改用 ar43 的新增事件与功能分类）；修正的格子一律取 ar44，旧值保留在原 CSV 作历史
  ar42_lmda.csv、ar42_desc.csv（自建 LMDA：表6第（1）列、附表2第（1）列、表1描述统计）
格式：master_supporting_docs/journal_benchmarks_20260924/表格格式裁决.md；排版函数见 ar22_fanwen_lib.py
输出：本 exploration 的 output/tables/回复导师_新表_第九轮_20261007.docx
运行：python3 explorations/advisor_revision_20261005/scripts/ar35_standalone_tables_docx.py（项目根目录）
"""
import sys
from pathlib import Path

import pandas as pd
from docx import Document
from docx.oxml.ns import qn
from docx.shared import Pt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ar22_fanwen_lib as L  # noqa: E402

T = HERE.parent / "output/tables"
OUT = T / "回复导师_新表_第九轮_20261007.docx"
L.VARS.update({"Inv", "Cashf", "Lservice", "Lerner", "WW", "ASY", "Seg", "RDres", "Srisk", "Resil", "Investnn",
               "Investnc", "Investnns", "LcomRDp", "LindRDs", "RDexp", "DuNum3", "DuRate3", "DuNum5", "DuRate5",
               "LMDA", "Pri_Number", "Pri_Hold", "Patients"})
m = pd.read_csv(T / "ar26_mentor_spec.csv", dtype={"col": str})
n = pd.read_csv(T / "ar29_iv_dyad_mentor.csv", dtype={"col": str})
f = pd.read_csv(T / "ar31_skeleton_fill.csv", dtype={"col": str})
ds = pd.read_csv(T / "ar31_desc.csv")
z = pd.read_csv(T / "ar34_standalone.csv", dtype={"col": str})
d0 = pd.read_csv(T / "ar34_desc.csv")
x = pd.read_csv(T / "ar44_fix.csv", dtype={"col": str})
dx = pd.read_csv(T / "ar44_desc.csv").set_index("var")
lm = pd.read_csv(T / "ar42_lmda.csv").rename(columns={"item": "tab", "stat": "r2a"})
lm["col"] = "1"
# 表1中功能类型与研发型新增的描述统计改用 ar44（新口径）
for v in dx.index:
    assert (ds["var"] == v).sum() == 1, v
    ds.loc[ds["var"] == v, ["N", "mean", "sd", "min", "p50", "max"]] = dx.loc[v, ["N", "mean", "sd", "min", "p50", "max"]].values


def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def get(d, tab, col, var):
    r = d[(d.tab == tab) & (d.col == str(col)) & (d["var"] == var)]
    assert len(r) == 1, (tab, col, var)
    return r.iloc[0]


def pair(r, k=1, dec=4):
    return f"{float(r.b) * k:.{dec}f}{stars(float(r.p))}", f"({float(r.se) * k:.{dec}f})"


def rows(label, rs, k=1):
    ps = [pair(r, k) for r in rs]
    return [[label] + [x[0] for x in ps], [""] + [x[1] for x in ps]]


def sparse(label, cells, k=1):
    """cells：每列为一行结果或 None（该列不含此变量）。"""
    ps = [pair(r, k) if r is not None else ("", "") for r in cells]
    return [[label] + [x[0] for x in ps], [""] + [x[1] for x in ps]]


def stats(rs, r2=True):
    out = [["样本量"] + [str(int(float(r.N))) for r in rs]]
    if r2:
        out.append(["调整后R²"] + [f"{float(r.r2a):.4f}" for r in rs])
    return out


def para(doc, text):
    p = doc.add_paragraph()
    L.exact_spacing(p, 18, before=12, after=0)
    L.set_fonts(p.add_run(text), 9, east="宋体")


doc = Document()
sec = doc.sections[0]
sec.page_width, sec.page_height = 7560310, 10692130
sec.top_margin = sec.bottom_margin = 914400
sec.left_margin = sec.right_margin = 1090295
st = doc.styles["Normal"]
st.font.name = "Times New Roman"
st.font.size = Pt(10.5)
st.element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
yes = L.yes
FE2 = lambda k: [["企业固定效应"] + yes(k), ["行业×年份固定效应"] + yes(k)]
FE1 = lambda k: [["企业固定效应"] + yes(k), ["年份固定效应"] + yes(k)]
FED = lambda k: [["企业×年份固定效应"] + yes(k), ["企业×目的省固定效应"] + yes(k), ["目的省×年份固定效应"] + yes(k)]
f4 = lambda x: L.fix_minus(f"{x:.4f}")

# 表1 主要变量描述性统计（原有变量取基准回归样本，新增变量取各自回归样本）
L.caption(doc, "表1 主要变量描述性统计", before=0)
CN = {"跨省子公司数量占比": "Investp", "同省异市数量占比": "Investc", "同城子公司数量占比": "Invests", "INV": "Inv",
      "Cashflow": "Cashf", "l第三产业增加值省份": "Lservice", "行业勒纳指数": "Lerner"}
lab = {"Investnns": "同省异市新增", "entry": "当年新设（双边）", "Seg0_z": "目的地市场分割（标准化）", "east": "东部",
       "mkt0": "市场化程度", "rdres0": "研发资源", "tfp0": "期初生产率", "lqw": "同行业区位熵"}
body = [[CN.get(r["var"], r["var"]), str(int(r.N)), f4(r["mean"]), f4(r.sd), f4(r["min"]), f4(r.p50), f4(r["max"])]
        for _, r in d0.iterrows()]
lmd = pd.read_csv(T / "ar42_desc.csv")
k = int(ds.index[ds["var"] == "WW"][0])
ds = pd.concat([ds.iloc[:k], lmd, ds.iloc[k:]], ignore_index=True)
body += [[lab.get(r["var"], r["var"]), str(int(r.N)), f4(r["mean"]), f4(r.sd), f4(r["min"]), f4(r.p50), f4(r["max"])]
         for _, r in ds.iterrows()]
L.build(doc, [["变量", "样本量", "均值", "标准差", "最小值", "中位数", "最大值"]], body, label_w=2400, keep=False)
L.note(doc, "注：Investp、Investc、Invests、Patient及控制变量取基准回归样本，其余变量取其所在回归的估计样本。Investp、Investc、Invests分别为跨省、"
       "同省异市、同城子公司数量占比；Investnns为新增同省异市子公司数量加1取对数；功能类型新增均为该类新增跨省子公司数量加1取对数，新增按子公司在完整子公司明细中首次披露认定；"
       "双边变量取企业、目的省、年份三维面板2015年以后的样本，研发型新增（双边）为当年是否在该省新设研发型子公司。")

# 表2 基准回归结果
L.caption(doc, "表2 基准回归结果")
FV = [("Inv", "INV"), ("Dual", "Dual"), ("Lev", "Lev"), ("Cashf", "Cashflow"), ("Indep", "Indep"), ("Top5", "Top5"),
      ("TobinQ", "TobinQ"), ("ROA", "ROA"), ("Growth", "Growth"), ("SOE", "SOE")]
RV = [("Lservice", "l第三产业增加值省份"), ("Lerner", "行业勒纳指数")]
cols = ["1", "2", "3", "4", "5"]
zz = lambda c, v: (lambda r: r.iloc[0] if len(r) else None)(z[(z.tab == "B") & (z.col == c) & (z["var"] == v)])
body = sparse("Patient", [zz(c, "Patient") for c in cols])
for labx, v in FV + RV:
    body += sparse(labx, [zz(c, v) for c in cols])
body += FE2(5) + stats([zz(c, "Patient") for c in cols])
L.build(doc, [L.nums_head(5), ["", "Investp", "Investp", "Investp", "Investc", "Invests"]], body, label_w=2000, keep=False)
L.note(doc, "注：第（1）—（3）列逐步加入控制变量，第（3）列为完整控制下的基准结果；第（4）（5）列被解释变量分别为同省异市、同城子公司数量占比。" + L.STD)

# 表3 新增跨省投资与子公司存续
L.caption(doc, "表3 新增跨省投资与子公司存续")
a = [get(m, "T2", c, "Patient") for c in (1, 2, 3)]
s = [get(m, "T9", c, "xlag") for c in (1, 2, 3, 4)]
body = sparse("Patient", a + [None] * 4) + sparse("L.Patient", [None] * 3 + s)
body += [["控制变量"] + yes(7)] + FE2(7) + stats(a + s)
L.build(doc, [L.nums_head(7), ["", "新增", "新增", "新增", "存续", "存续", "存续", "存续"],
              ["", "Investnn", "Investnc", "Investnns", "DuNum3", "DuRate3", "DuNum5", "DuRate5"]], body, label_w=1900)
L.note(doc, "注：第（1）（2）列被解释变量为新增跨省子公司数量、注册资本加1取对数，第（3）列为新增同省异市子公司数量加1取对数；三者取原面板的现成字段，"
       "是当年相对上年的净变化，含负值，不同于新设子公司的毛数量，其生成与缩尾顺序待核。第（4）—（7）列以基期跨省子公司存量为基础，取第三、五年仍作为跨省子公司在年报中披露（持续披露）的数量与比例，"
       "要求企业在第三、五年仍在样本中，解释变量取上一期；与原表样本量8127相符的候选口径见附表5。" + L.STD)

# 表4 稳健性检验
L.caption(doc, "表4 稳健性检验")
gz = lambda tab, c, v: get(z, tab, c, v)
pt = [gz("R", 1, "Patient"), None, None, gz("R", 4, "Patient"), gz("R", 5, "Patient"), gz("R", 6, "Patient"), gz("R", 7, "Patient")]
lp2 = get(x, "R", 2, "Lp")   # 自然年滞后（ar44）
body = sparse("Patient", pt) + sparse("L.Patient", [None, lp2] + [None] * 5)
body += sparse("Patients", [None, None, gz("R", 3, "Patients")] + [None] * 4)
for labx, v in (("BeltRoad", "belt_and_road"), ("Yangtze", "yangtze_delta"), ("GreatBay", "greater_bay"), ("Chengyu", "chengyu")):
    body += sparse(labx, [None] * 4 + [gz("R", 5, v)] + [None] * 2)
allr = [gz("R", 1, "Patient"), lp2, gz("R", 3, "Patients")] + pt[3:]
body += [["控制变量"] + yes(7)] + FE2(7) + stats(allr)
L.VARS.update({"Investk", "BeltRoad", "Yangtze", "GreatBay", "Chengyu"})
L.build(doc, [L.nums_head(7), ["", "替换被\n解释变量", "解释变量\n滞后一期", "替换\n解释变量", "剔除超大\n特大城市", "控制区域\n战略", "PSM\n匹配样本",
                              "剔除\n直辖市\n总部"],
              ["", "Investk", "Investp", "Investp", "Investp", "Investp", "Investp", "Investp"]], body, label_w=1950, keep=False)
L.note(doc, "注：Investk为跨省子公司注册资本占比；第（2）列L.Patient为上一自然年的Patient，上一年不在样本中的观测不进入估计；Patients为稳定型机构投资者持股比例（相对流通A股）。第（4）列剔除母公司位于22个超大、特大城市的企业；"
       "第（5）列加入一带一路（BeltRoad）、长三角一体化（Yangtze）、粤港澳大湾区（GreatBay）、成渝双城经济圈（Chengyu）政策虚拟变量，按母公司所在省份和政策起始年份设定；"
       "第（6）列以是否有耐心资本为处理变量，按控制变量做1:1近邻倾向得分匹配（卡尺0.05，共同支撑），用匹配样本回归；第（7）列剔除总部位于北京、上海、天津、重庆的企业。"
       "安慰剂检验见附表7。" + L.STD)

# 表5 内生性检验
L.caption(doc, "表5 内生性检验")
h1 = get(x, "H1", 1, "高新技术企业")   # 选择方程：是否有耐心资本（导师写法）
assert abs(float(h1.b) - 0.269) < 5e-4
h2p, h2m = get(x, "H2", "iy", "Patient"), get(x, "H2", "iy", "imr")   # 正负两支 IMR，企业＋行业×年份固定效应
iv = [get(n, "T7", 1, "Patient_lag1"), get(n, "T7", 2, "lp"), get(n, "T7", 3, "lp")]
kp = [get(f, "I", c, "kp") for c in (1, 2, 3)]
body = sparse("Hitech", [h1] + [None] * 4) + sparse("Patient", [None, h2p] + [None] * 3)
body += sparse("IMR", [None, h2m] + [None] * 3) + sparse("L.Patient", [None, None] + iv)
body += [["控制变量"] + yes(5), ["企业固定效应", "否", "是", "是", "是", "是"], ["行业×年份固定效应", "否", "是", "否", "否", "否"],
         ["年份固定效应", "是", "否", "是", "是", "是"],
         ["样本量"] + [str(int(float(r.N))) for r in [h1, h2p] + iv],
         ["伪R²／调整后R²", f"{float(h1.r2a):.4f}", f"{float(h2p.r2a):.4f}", "", "", ""],
         ["Kleibergen–Paap rk LM统计量", "", ""] + [f"{float(r.stat):.4f}" for r in kp],
         ["Kleibergen–Paap rk Wald F", "", ""] + [f"{float(r.kpf):.4f}" for r in iv]]
L.VARS.update({"Hitech", "IMR"})
L.build(doc, [L.nums_head(5), ["", "Heckman两阶段", "Heckman两阶段", "工具变量法", "工具变量法", "工具变量法"],
              ["", "第一阶段", "第二阶段", "同群工具", "PRI签署\n基金数", "PRI签署\n基金持股"],
              ["", "是否有\n耐心资本", "Investp", "Investp", "Investp", "Investp"]], body, label_w=2900, keep=False)
L.note(doc, "注：第（1）列为Probit选择方程，被解释变量为企业是否有耐心资本，Hitech为是否为高新技术企业，控制年份虚拟变量；第（2）列加入逆米尔斯比率（IMR），有耐心资本的企业取φ(xb)/Φ(xb)，没有的取−φ(xb)/[1−Φ(xb)]。"
       "第（3）—（5）列报告工具变量法第二阶段，内生变量为上一期Patient，第一阶段见附表1：第（3）列以滞后同群留一工具Hold(t−1)与SizeG(t−1)为工具，"
       "即同一年份、同一机构持股分位组或资产规模分位组内其他企业的耐心资本均值；第（4）（5）列以上一期签署联合国负责任投资原则（PRI）的基金数、持股比例为工具。"
       "第（3）列控制变量取当期值，第（4）（5）列控制变量取上一期值；PRI签署基金数取基金数加1的对数，基金以其管理人签署PRI认定。Kleibergen–Paap rk LM统计量的p值均小于0.01。" + L.STD)

# 表6 机制检验
L.caption(doc, "表6 机制检验")
rs = [get(lm, "V4", 1, "LMDA")] + [get(m, "T3", c, "Patient") for c in (1, 2, 3, 5, 6, 7)]
body = rows("Patient", rs) + [["控制变量"] + yes(7)] + FE2(7) + stats(rs)
L.build(doc, [L.nums_head(7), ["", "LMDA", "WW", "ASY", "Srisk", "LcomRDp", "LindRDs", "RDexp"]], body, label_w=2050)
L.note(doc, "注：LMDA为管理者短视，按胡楠、薛付婧和王昊楠（2021）的短期视域词表（43个，其中30个为原文明列，只用这30个词时结论相同），计算其在年报“管理层讨论与分析”中的词频占该部分总词数的比例（乘以100）后加1取对数，年报取自巨潮资讯网；WW为融资约束指数，ASY为信息不对称，Srisk为供应链风险，LcomRDp为母公司创新，LindRDs为子公司创新，RDexp为集团创新地理分散度。"
       "LcomRDp取母公司专利总数（独立与联合专利获得量之和）加1的对数，是对原表指标的候选替代，不等同于独立申请口径；LindRDs取子公司独立专利总和的对数。Resil见附表4，第二步见附表2。" + L.STD)

# 表7 异质性
L.caption(doc, "表7 异质性分析")
rs = [get(m, "T4", c, "Patient") for c in range(1, 9)]
pr = lambda g: f"{float(m[(m.tab == 'T4') & (m.col == g)].p.iloc[0]):.4f}"
body = rows("Patient", rs) + [["组间系数差异p值", "", pr("Seg"), "", pr("Dist"), "", pr("Resi"), "", pr("RD")],
                              ["控制变量"] + yes(8)] + FE1(8) + stats(rs)
head = [L.nums_head(8), ["", "市场分割", "市场分割", "地理距离", "地理距离", "供应链韧性", "供应链韧性", "研发投入强度", "研发投入强度"],
        ["", "高", "低", "远", "近", "高", "低", "高", "低"]]
L.build(doc, head, body, label_w=1640)
L.note(doc, "注：被解释变量为Investp。市场分割、供应链韧性按中位数分组，地理距离按球面距离分组，研发投入强度按当年中位数分组。"
       "组间系数差异p值采用两组共用企业与年份固定效应的写法，统一采用企业层面聚类；该检验中控制变量的系数也按组变化。交互项估计见附表3。" + L.STD)

# 表8 新增子公司的去向
L.caption(doc, "表8 新增子公司的去向")
rs = [get(n, "T6", 1, "PxSeg"), get(n, "T6", 2, "PxSeg")] + [get(n, "T8", c, f"Px_{c}") for c in range(1, 6)]
body = rows("L.Patient×目的省属性", rs, k=1000) + FED(7) + stats(rs)
L.build(doc, [L.nums_head(7), ["", "市场分割", "市场分割", "东部", "市场化\n程度", "研发资源", "期初\n生产率", "同行业\n区位熵"],
              ["", "全样本", "剔除\n直辖市", "全样本", "全样本", "全样本", "全样本", "全样本"]], body, label_w=2000)
L.note(doc, "注：企业、目的省、年份三维面板，被解释变量为当年是否在该省新设跨省子公司，每列放入一个目的省属性，第（2）列剔除直辖市目的地。市场分割为目的地市场分割；"
       "市场化程度、研发资源取2010—2013年均值，期初生产率为2014年该省上市公司TFP均值，同行业区位熵按2010—2013年该省本行业上市公司占比计算；"
       "除东部外均已标准化。系数与标准误均乘以1000。" + L.STD)

# 表9 去向属性的联合估计与研发型新增
L.caption(doc, "表9 去向属性的联合估计与研发型新增")
J = {a: get(f, "J", 1, f"c.L_Patient#c.{a}") for a in ("east", "z_mkt0", "z_rdres0", "z_tfp0", "z_lqw")}
rd = get(x, "T6", 3, "PxRD")   # 新增按完整明细首次披露（ar43/ar44）
body = []
for a, labx in (("east", "东部"), ("z_mkt0", "市场化程度"), ("z_rdres0", "研发资源"), ("z_tfp0", "期初生产率"), ("z_lqw", "同行业区位熵")):
    body += sparse(f"L.Patient×{labx}", [J[a], rd if a == "z_rdres0" else None], k=1000)
body += FED(2) + stats([J["east"], rd])
L.build(doc, [L.nums_head(2), ["", "当年新增", "研发型新增"]], body, label_w=3000)
L.note(doc, "注：第（1）列把表8第（3）—（7）列的五项目的省属性放入同一回归；第（2）列被解释变量为当年是否在该省新设研发型子公司，新设按子公司在完整子公司明细中首次披露认定，研发型按第三方标签"
       "剔除房地产子公司后认定。期初生产率换用剔除样本少于10家省份的算法后的结果见附表6。系数与标准误均乘以1000。" + L.STD)

# 表10 新增跨省子公司的功能类型
L.caption(doc, "表10 新增跨省子公司的功能类型")
rs = [get(x, "T5", c, "Patient") for c in (1, 2, 3, 4, 6, 5)]   # ar43 新口径
body = rows("Patient", rs) + [["控制变量"] + yes(6)] + FE2(6) + stats(rs)
L.build(doc, [L.nums_head(6), ["", "进入新省份", "同功能复制", "功能互补", "研发型", "研发互补", "东部企业到中西部"]], body, label_w=1950)
L.note(doc, "注：被解释变量为该类新增跨省子公司数量加1取对数。新增按子公司在完整子公司明细中首次披露认定，分类要求企业上一年的子公司明细可观察，否则该年不进入估计。"
       "进入新省份指企业上一年在该省没有子公司；同功能复制指上一年在该省已有功能相同的子公司；"
       "功能互补指上一年在该省已有带功能标签的子公司，且功能都与新子公司不同，旧子公司都没有功能标签的单独归类，不计入功能互补；研发型按第三方标签剔除房地产子公司后认定；研发互补指研发型新子公司进入上一年已有生产或销售子公司、"
       "但没有研发子公司的省份；第（6）列样本为总部在东部的企业，被解释变量为其在中西部新设的子公司。各类子公司基数不同，系数不宜直接比较大小。" + L.STD)

# 附表1 第一阶段
L.caption(doc, "附表1 内生性检验第一阶段")
g = lambda c, v: get(f, "F1", c, v)
body = sparse("Hold(t−1)", [g(1, "IV_Hold2_lag1"), None, None]) + sparse("SizeG(t−1)", [g(1, "IV_SizeGroup2_lag1"), None, None])
body += sparse("L.Pri_Number", [None, g(2, "l_Pri_Number"), None]) + sparse("L.Pri_Hold", [None, None, g(3, "l_Pri_Hold")])
body += [["控制变量"] + yes(3), ["企业固定效应"] + yes(3), ["年份固定效应"] + yes(3)]
body += stats([g(1, "IV_Hold2_lag1"), g(2, "l_Pri_Number"), g(3, "l_Pri_Hold")])
L.build(doc, [L.nums_head(3), ["", "同群工具", "PRI签署基金数", "PRI签署基金持股"], ["", "L.Patient", "L.Patient", "L.Patient"]],
        body, label_w=3000)
L.note(doc, "注：对应表5第（3）—（5）列的第一阶段，样本相同。" + L.STD)

# 附表2 机制两步
L.caption(doc, "附表2 机制检验第二步")
mv = ["WW指数", "ASY", "SCDRisk2_100倍", "M_comA", "l子公司独立专利总和", "集团创新地理分散度"]
pp = [get(lm, "S2", 1, "Patient")] + [get(f, "A2", c, "Patient") for c in range(1, 7)]
mm = [get(lm, "S2", 1, "LMDA")] + [get(f, "A2", c, v) for c, v in zip(range(1, 7), mv)]
body = rows("Patient", pp) + rows("机制变量", mm) + [["控制变量"] + yes(7)] + FE2(7) + stats(pp)
L.build(doc, [L.nums_head(7), ["", "LMDA", "WW", "ASY", "Srisk", "LcomRDp", "LindRDs", "RDexp"],
              ["", "Investp", "Investp", "Investp", "Investp", "Investp", "Investp", "Investp"]], body, label_w=2050)
L.note(doc, "注：被解释变量为Investp，各列同时放入Patient和表头所列机制变量。" + L.STD)

# 附表3 异质性交互项
L.caption(doc, "附表3 异质性分析交互项估计")
cs = range(1, 5)
body = rows("Patient", [get(f, "A3", c, "Patient") for c in cs]) + rows("Patient×高组", [get(f, "A3", c, "PxG") for c in cs])
body += rows("高组", [get(f, "A3", c, "G") for c in cs]) + [["控制变量"] + yes(4)] + FE1(4) + stats([get(f, "A3", c, "PxG") for c in cs])
L.build(doc, [L.nums_head(4), ["", "市场分割高", "地理距离远", "供应链韧性高", "研发投入强度高"], ["", "Investp", "Investp", "Investp", "Investp"]],
        body, label_w=2200)
L.note(doc, "注：高组为虚拟变量，分组定义同表7。本表只让Patient按组变化，表7的组间差异检验同时让控制变量按组变化，两者显著性不完全相同。" + L.STD)

# 附表4 供应链韧性机制
L.caption(doc, "附表4 供应链韧性机制")
r = [get(m, "T3", 4, "Patient")]
body = rows("Patient", r) + [["控制变量"] + yes(1)] + FE2(1) + stats(r)
L.build(doc, [L.nums_head(1), ["", "Resil"]], body, label_w=3000, full_w=5000)
L.note(doc, "注：规格同表6。" + L.STD)

# 附表5 存续的原表样本口径
L.caption(doc, "附表5 第三年持续披露数量的候选样本口径")
r = [get(m, "T9", 5, "xlag")]
body = rows("L.Patient", r) + [["控制变量"] + yes(1)] + FE2(1) + stats(r)
L.build(doc, [L.nums_head(1), ["", "DuNum3"]], body, label_w=3000, full_w=5000)
L.note(doc, "注：第三年已不在样本中的企业记为0，其余同表3第（4）列。该口径的样本量与初稿8表32的8127相同，但仅样本量相符，尚不能确认是原表的构造方法。" + L.STD)

# 附表6 期初生产率换算法
L.caption(doc, "附表6 去向属性联合估计的期初生产率换算法")
J2 = [get(f, "J", 2, f"c.L_Patient#c.{a}") for a in ("east", "z_mkt0", "z_rdres0", "z_tfp0_n10", "z_lqw")]
body = []
for r, labx in zip(J2, ("东部", "市场化程度", "研发资源", "期初生产率", "同行业区位熵")):
    body += rows(f"L.Patient×{labx}", [r], k=1000)
body += FED(1) + stats([J2[0]])
L.build(doc, [L.nums_head(1), ["", "当年新增"]], body, label_w=3000, full_w=5000)
L.note(doc, "注：同表9第（1）列，期初生产率改为剔除上市公司样本少于10家的省份后计算。系数与标准误均乘以1000。" + L.STD)

# 附表7 安慰剂检验
L.caption(doc, "附表7 安慰剂检验")
q = get(z, "P", 1, "summary")
b0 = get(z, "B", 3, "Patient")
body = [["真实估计系数", f4(float(b0.b))], ["模拟估计系数均值", f4(float(q.b))], ["模拟估计系数标准差", f4(float(q.se))],
        ["模拟系数不小于真实系数的比例", f4(float(q.p))], ["模拟回归中p值小于0.1的比例", f4(float(q.r2a))],
        ["模拟次数", str(int(float(q.N)))]]
L.build(doc, [["项目", "数值"]], body, label_w=3200, full_w=5000)
L.note(doc, "注：在基准回归样本内，为每个企业—年份观测有放回地随机抽取一个Patient值作为虚构解释变量，重新估计表2第（3）列，重复1000次。")

# 页脚页码（D-130：方便面谈定位）
from docx.oxml import OxmlElement  # noqa: E402
fp = sec.footer.paragraphs[0]
fp.alignment = 1
for kind, txt in (("begin", None), (None, " PAGE "), ("end", None)):
    r = fp.add_run()
    L.set_fonts(r, 9)
    if kind:
        e = OxmlElement("w:fldChar"); e.set(qn("w:fldCharType"), kind); r._element.append(e)
    else:
        e = OxmlElement("w:instrText"); e.set(qn("xml:space"), "preserve"); e.text = txt; r._element.append(e)
doc.save(OUT)
print(OUT)

# 只供本机导出 PDF 的副本：macOS 的 LibreOffice 不经 fontconfig，找不到“宋体/黑体”时会用 Arial Unicode 代替；
# 副本把东亚字体换成本机的宋体-简、黑体-简，Word 交付件仍写宋体、黑体（范文规定）。
import zipfile  # noqa: E402
PDFSRC = T / "回复导师_新表_第九轮_20261007_pdf用.docx"
with zipfile.ZipFile(OUT) as zi, zipfile.ZipFile(PDFSRC, "w", zipfile.ZIP_DEFLATED) as zo:
    for it in zi.infolist():
        data = zi.read(it.filename)
        if it.filename.endswith(".xml"):
            data = data.decode("utf-8").replace('"宋体"', '"Songti SC"').replace('"黑体"', '"Heiti SC"').encode("utf-8")
        zo.writestr(it, data)
print(PDFSRC)
