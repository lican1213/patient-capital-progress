"""ar27_mentor_tables_docx.py — 按导师原规格（当期 Patient、导师控制变量、导师各表固定效应）排出回复导师用的 9 张表。

输入（只读）：本 exploration 的 output/tables/ 下
  ar26_mentor_spec.csv（表1—表5、表9）；ar29_iv_dyad_mentor.csv（表6—表8）
格式：master_supporting_docs/journal_benchmarks_20260924/表格格式裁决.md；排版函数见 ar22_fanwen_lib.py
输出：本 exploration 的 output/tables/回复导师_新表_20261007.docx
运行：python3 explorations/advisor_revision_20261005/scripts/ar27_mentor_tables_docx.py（项目根目录）
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
OUT = T / "回复导师_新表_20261007.docx"
L.VARS.update({"Inv", "Cashf", "Lservice", "Lerner", "WW", "ASY", "Seg", "RDres", "Srisk", "Resil",
               "LcomRDp", "LindRDs", "RDexp", "DuNum3", "DuRate3", "DuNum5", "DuRate5"})
m = pd.read_csv(T / "ar26_mentor_spec.csv", dtype={"col": str})
n = pd.read_csv(T / "ar29_iv_dyad_mentor.csv", dtype={"col": str})
e8 = n


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


def stats(rs, r2=True):
    out = [["样本量"] + [str(int(float(r.N))) for r in rs]]
    if r2:
        out.append(["调整后R²"] + [f"{float(r.r2a):.4f}" for r in rs])
    return out


doc = Document()
sec = doc.sections[0]
sec.page_width, sec.page_height = 7560310, 10692130
sec.top_margin = sec.bottom_margin = 914400
sec.left_margin = sec.right_margin = 1090295
st = doc.styles["Normal"]
st.font.name = "Times New Roman"
st.font.size = Pt(10.5)
st.element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
yes = lambda k, v="是": [v] * k
FE2 = lambda k: [["企业固定效应"] + yes(k), ["行业×年份固定效应"] + yes(k)]
FE1 = lambda k: [["企业固定效应"] + yes(k), ["年份固定效应"] + yes(k)]

# 表1 基准回归
L.caption(doc, "表1 基准回归结果", before=0)
ctrl = [("Inv", "INV"), ("Dual", "Dual"), ("Lev", "Lev"), ("Cashf", "Cashflow"), ("Indep", "Indep"), ("Top5", "Top5"),
        ("TobinQ", "TobinQ"), ("ROA", "ROA"), ("Growth", "Growth"), ("SOE", "SOE"), ("Lservice", "l第三产业增加值省份"),
        ("Lerner", "行业勒纳指数")]
body = rows("Patient", [get(m, "T1", c, "Patient") for c in (1, 2)])
for lab, v in ctrl:
    body += rows(lab, [get(m, "T1", c, v) for c in (1, 2)])
body += FE2(2) + stats([get(m, "T1", c, "Patient") for c in (1, 2)])
L.build(doc, [L.nums_head(2), ["", "全样本", "剔除直辖市总部企业"], ["", "跨省子公司数量占比", "跨省子公司数量占比"]],
        body, merge_last=True)
L.note(doc, "注：第（2）列剔除总部位于北京、上海、天津、重庆的企业。" + L.STD)

# 表2 新增跨省投资
L.caption(doc, "表2 耐心资本与新增跨省投资")
rs = [get(m, "T2", c, "Patient") for c in (1, 2, 3)]
body = rows("Patient", rs) + [["控制变量"] + yes(3)] + FE2(3) + stats(rs)
L.build(doc, [L.nums_head(3), ["", "Investnn", "Investnc", "同省异市新增数量"]], body)
L.note(doc, "注：对应初稿8表32第（1）—（3）列。Investnn为新增跨省子公司数量加1取对数，Investnc为新增跨省子公司注册资本加1取对数。" + L.STD)

# 表3 机制
L.caption(doc, "表3 机制检验")
rs = [get(m, "T3", c, "Patient") for c in range(1, 8)]
body = rows("Patient", rs) + [["控制变量"] + yes(7)] + FE2(7) + stats(rs)
L.build(doc, [L.nums_head(7), ["", "WW", "ASY", "Srisk", "Resil", "LcomRDp", "LindRDs", "RDexp"]], body, label_w=1500)
L.note(doc, "注：WW为融资约束指数，ASY为信息不对称，Srisk为供应链风险，Resil为供应链韧性，LcomRDp为母公司创新，"
       "LindRDs为子公司创新，RDexp为集团创新地理分散度。LcomRDp按初稿8定义重建，与原表口径可能略有差异；LMDA数据暂缺。" + L.STD)

# 表4 异质性
L.caption(doc, "表4 异质性分析")
rs = [get(m, "T4", c, "Patient") for c in range(1, 9)]
pr = lambda g: f"{float(m[(m.tab == 'T4') & (m.col == g)].p.iloc[0]):.3f}"
body = rows("Patient", rs) + [["组间系数差异p值", "", pr("Seg"), "", pr("Dist"), "", pr("Resi"), "", pr("RD")],
                              ["控制变量"] + yes(8)] + FE1(8) + stats(rs)
head = [L.nums_head(8), ["", "市场分割", "市场分割", "地理距离", "地理距离", "供应链韧性", "供应链韧性", "研发投入强度", "研发投入强度"],
        ["", "高", "低", "远", "近", "高", "低", "高", "低"]]
L.build(doc, head, body, label_w=1640)
L.note(doc, "注：被解释变量为跨省子公司数量占比。市场分割、供应链韧性按中位数分组，地理距离按球面距离分组，研发投入强度按当年中位数分组。"
       "组间系数差异p值按初稿8的检验写法（两组共用企业与年份固定效应），统一采用企业层面聚类。" + L.STD)

# 表5 新增类型与流向
L.caption(doc, "表5 新增跨省子公司的类型与流向")
rs = [get(m, "T5", c, "Patient") for c in (1, 2, 3, 4, 6, 5)]
body = rows("Patient", rs) + [["控制变量"] + yes(6)] + FE2(6) + stats(rs)
L.build(doc, [L.nums_head(6), ["", "进入新省份", "同功能复制", "功能互补", "研发型", "研发互补", "东部企业到中西部"]], body, label_w=1700)
L.note(doc, "注：被解释变量为该类新增跨省子公司数量加1取对数。进入新省份指企业上一年在该省没有子公司；同功能复制指上一年在该省已有"
       "功能相同的子公司；功能互补指上一年在该省已有子公司但功能都不同；研发型按第三方标签剔除房地产子公司后认定；研发互补指研发型新子公司进入上一年已有生产或销售子公司、但没有研发子公司的省份；"
       "第（6）列样本为总部在东部的企业，被解释变量为其在中西部新设的子公司。" + L.STD)

# 表6 新增去向：市场分割与研发资源
L.caption(doc, "表6 新增子公司的去向")
a, b, c = get(n, "T6", 1, "PxSeg"), get(n, "T6", 2, "PxSeg"), get(n, "T6", 3, "PxRD")
r1, r2 = rows("L.Patient×Seg", [a, b], k=1000), rows("L.Patient×RDres", [c], k=1000)
body = [r1[0] + [""], r1[1] + [""], [r2[0][0], "", ""] + r2[0][1:], ["", "", ""] + r2[1][1:]]
body += [["企业×年份固定效应"] + yes(3), ["企业×目的省固定效应"] + yes(3), ["目的省×年份固定效应"] + yes(3)] + stats([a, b, c])
L.build(doc, [L.nums_head(3), ["", "当年新增", "当年新增", "研发型新增"], ["", "全样本", "剔除直辖市目的地", "全样本"]],
        body, label_w=2600)
L.note(doc, "注：企业、目的省、年份三维面板，被解释变量为当年是否在该省新设（研发型）跨省子公司。Seg为目的地市场分割，"
       "RDres为目的省研发资源，均已标准化。系数与标准误均乘以1000。" + L.STD)

# 表7 工具变量
L.caption(doc, "表7 工具变量法估计结果")
iv = [get(n, "T7", 1, "Patient_lag1"), get(n, "T7", 2, "lp"), get(n, "T7", 3, "lp")]
body = rows("L.Patient", iv) + [["控制变量"] + yes(3), ["企业固定效应"] + yes(3), ["年份固定效应"] + yes(3),
                                ["样本量"] + [str(int(float(r.N))) for r in iv],
                                ["Kleibergen–Paap rk Wald F"] + [f"{float(r.kpf):.2f}" for r in iv]]
L.build(doc, [L.nums_head(3), ["", "同群工具", "PRI签署基金数", "PRI签署基金持股"]], body, label_w=2600)
L.note(doc, "注：被解释变量为跨省子公司数量占比，内生变量为上一期Patient。第（1）列为初稿8所用滞后同群留一工具（同组其他企业上一期"
       "机构持股与规模组）；第（2）（3）列以上一期签署联合国负责任投资原则（PRI）的基金数、持股比例为工具，控制变量取上一期值。" + L.STD)

# 表8 去向的地区属性
L.caption(doc, "表8 新增子公司去向的地区属性")
rs = [get(e8, "T8", c, f"Px_{c}") for c in range(1, 6)]
body = rows("L.Patient×目的省属性", rs, k=1000)
body += [["企业×年份固定效应"] + yes(5), ["企业×目的省固定效应"] + yes(5), ["目的省×年份固定效应"] + yes(5)] + stats(rs)
L.build(doc, [L.nums_head(5), ["", "东部", "市场化程度", "研发资源", "期初生产率", "同行业区位熵"]], body, label_w=2400)
L.note(doc, "注：被解释变量为当年是否在该省新设跨省子公司，各列分别放入一个目的省属性。市场化程度、研发资源取2010—2013年均值，"
       "期初生产率为2014年该省上市公司TFP均值，同行业区位熵按2010—2013年该省本行业上市公司占比计算，除东部外均已标准化。"
       "系数与标准误均乘以1000。" + L.STD)

# 表9 存续
L.caption(doc, "表9 耐心资本与跨省子公司存续")
rs = [get(m, "T9", c, "xlag") for c in range(1, 6)]
body = rows("L.Patient", rs) + [["控制变量"] + yes(5)] + FE2(5) + stats(rs)
L.build(doc, [L.nums_head(5), ["", "DuNum3", "DuRate3", "DuNum5", "DuRate5", "DuNum3"],
              ["", "仍披露样本", "仍披露样本", "仍披露样本", "仍披露样本", "原表样本口径"]], body, label_w=1800)
L.note(doc, "注：以基期跨省子公司存量为基础，第三、五年仍存续的数量与比例。第（1）—（4）列要求企业在第三、五年仍在样本中；"
       "第（5）列按原表样本量8127的口径，第三年已不在样本中的企业存续数记为0。" + L.STD)

doc.save(OUT)
print(OUT)
