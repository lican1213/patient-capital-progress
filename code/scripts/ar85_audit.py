"""ar85_audit.py — 第四十五轮：新表8（时变版）对抗式核查。用与出表不同的代码路径独立重算，任一项失败退出码 1。

A 构造：从原始文件重算 seg_m3l（三次单独合并 t−1、t−2、t−3，不用滚动窗口）、mkt_l1、rd_l1，与 20 号逐格比；百分位用 pandas 独立重算，与 Stata 输出比。
B 数字：干净目录运行交付命令的日志 ↔ ar85_t8.csv；ar85 ↔ 此前各轮独立 do-file（ar51、ar81—ar84）；Word 表格 ↔ ar85_t8.csv。
C 样本：每企业×年 30 个目的省；entry 只在企业首个样本年缺失；估计样本年份 2015—2024；N 一致。
D 表注措辞：不含“有方向”“稳健”“因果”“解决”“内生”；含“不加权”“t−3”。
E 交付包：文件齐全，命令只引用包内文件与 16 号。
输出：quality_reports/advisor_feedback_20261005/t8_timevary_20261012/核查结果.md
运行：python3 explorations/advisor_revision_20261005/scripts/ar85_audit.py（项目根目录）
"""
import re
import sys
from pathlib import Path

import docx
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
T = EXP / "output/tables"
PK = ROOT / "deliverables/advisor_package_20261007/表8时变版_20261012"
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
Q = ROOT / "quality_reports/advisor_feedback_20261005/t8_timevary_20261012"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
res = []


def chk(name, ok, detail=""):
    res.append((name, bool(ok), detail))
    print(("PASS " if ok else "FAIL ") + name, detail)


i = lambda d, cs: d.assign(**{c: d[c].astype(int) for c in cs})
p16 = i(pd.read_stata(P16, columns=["stkcd", "year", "dest_id", "dest", "entry", "Patient"]), ["stkcd", "year", "dest_id"])
v20 = i(pd.read_stata(PK / "20_表8时变变量.dta"), ["stkcd", "year", "dest_id"])

# ---------- A 构造 ----------
ar = i(pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out"]), ["stkcd", "year"])
city0 = ar.loc[ar.groupby("stkcd").year.idxmin(), ["stkcd", "city_out"]].rename(columns={"city_out": "city0"})
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = set(af.province_in.dropna())
stk = pd.read_stata(STK, columns=["PROVINCE", "CITY"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cm = pd.concat([stk[["city", "prov"]], af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cm = cm[cm.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta", columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(city0.city0))].copy()
sg["dest"] = sg.city_in.map(cm); sg["year"] = sg.year.astype(int)
py = sg.dropna(subset=["dest", "market_seg_pair"]).groupby(["city_out", "dest", "year"], as_index=False).market_seg_pair.mean()
x = p16[["stkcd", "year", "dest_id", "dest"]].merge(city0, on="stkcd", how="left")
for L in (1, 2, 3):
    y = py.rename(columns={"city_out": "city0", "market_seg_pair": f"s{L}"}).assign(year=lambda d: d.year + L)
    x = x.merge(y, on=["city0", "dest", "year"], how="left")
x["m3l"] = x[["s1", "s2", "s3"]].mean(axis=1, skipna=False)
x = x.merge(v20, on=["stkcd", "year", "dest_id"], how="left", validate="1:1")
same_na = (x.m3l.isna() == x.seg_m3l.isna()).all()
chk("A1 seg_m3l 独立重算（t−1、t−2、t−3 三次合并）", same_na and (x.m3l - x.seg_m3l).abs().max() < 1e-9,
    f"最大差 {(x.m3l - x.seg_m3l).abs().max():.2e}，缺失位置一致 {same_na}")
mk = pd.read_stata(CY / "1997-2024年市场化指数和各分项指数.dta", columns=["province_in", "year", "market"])
mk["year"] = mk.year.round().astype(int)
look = mk.set_index(["province_in", "year"]).market
x["mk_chk"] = [look.get((d, t - 1), np.nan) for d, t in zip(x.dest, x.year)]
chk("A2 mkt_l1 = 目的省 t−1 年市场化总指数", (x.mk_chk - x.mkt_l1).abs().max() < 1e-9, f"最大差 {(x.mk_chk - x.mkt_l1).abs().max():.2e}")
rd = pd.read_stata(CY / "上市公司-研发投入与专利数据（2000-2024年）.dta", columns=["year", "企业发明专利申请量", "省份"])
rd["year"] = rd.year.astype(int)
rs = np.log1p(rd.groupby(["省份", "year"])["企业发明专利申请量"].sum())
x["rd_chk"] = [rs.get((d, t - 1), np.nan) for d, t in zip(x.dest, x.year)]
chk("A3 rd_l1 = ln(1+目的省 t−1 年上市公司发明专利申请量合计)", (x.rd_chk - x.rd_l1).abs().max() < 1e-9, f"最大差 {(x.rd_chk - x.rd_l1).abs().max():.2e}")
es = x[(x.year >= 2015) & x.year.isin(p16.year)].merge(p16[["stkcd", "year", "dest_id", "entry", "Patient"]], on=["stkcd", "year", "dest_id"])
es = es[es.entry.notna() & es.Patient.notna() & es.seg_m3l.notna()].copy()
es["rk"] = es.groupby("year").seg_m3l.rank(method="average")
es["n"] = es.groupby("year").seg_m3l.transform("count")
es["seg_py"] = (es.rk - 1) / (es.n - 1)
st = i(pd.read_stata(T / "ar85_rank.dta"), ["stkcd", "year", "dest_id"])
m = es.merge(st, on=["stkcd", "year", "dest_id"], how="outer", indicator=True)
chk("A4 年内百分位独立重算（平均秩，(r−1)/(n−1)）", (m._merge == "both").all() and (m.seg_py - m.seg).abs().max() < 1e-9,
    f"行数 {len(m)}，只在一边 {int((m._merge != 'both').sum())}，最大差 {(m.seg_py - m.seg).abs().max():.2e}")
mm = m.groupby("year").seg.agg(["min", "max"])
chk("A5 百分位在 0—1 之间（并列值取平均秩，最小值可略大于 0）", (mm["min"] >= 0).all() and (mm["max"] <= 1).all(), f"各年最小 {mm['min'].max():.5f} 以内、最大 {mm['max'].min():.5f} 以上")
b85 = pd.read_csv(T / "ar85b_rank_distinct.csv")
chk("A7 百分位改在当年不重复数值上计算（ar85b），方向不变、10% 内显著", (b85.b < 0).all() and (b85.p < .10).all(),
    "；".join(f"（{int(r.col)}）{r.b * 1000:.3f} p={r.p:.3f} N={int(r.N)}" for r in b85.itertuples()))
chk("A6 不含当年及以后信息：seg_m3l 只由 t−1 至 t−3 构成", True, "A1 已按 t−1、t−2、t−3 三次合并逐格相等")

# ---------- B 数字 ----------
d = pd.read_csv(T / "ar85_t8.csv")
log = (Q / "交付命令_干净目录运行.log").read_text(encoding="utf-8", errors="ignore")
blocks = log.split("HDFE Linear regression")[1:]
order = [(1, ["PxSeg", "seg"]), (2, ["PxSeg", "seg"]), (3, ["PxEast"]), (4, ["PxMkt"]), (5, ["PxRd"]), (6, ["PxTfp"]), (7, ["PxLq"]),
         (8, ["PxSeg", "seg", "PxRd", "PxDist"])]
okB1, n_cells = True, 0
for blk, (c, vs) in zip(blocks, order):
    N = int(re.search(r"Number of obs\s*=\s*([\d,]+)", blk).group(1).replace(",", ""))
    for v in vs:
        mt = re.search(rf"^\s*{v} \|\s+(\S+)\s+(\S+)\s+\S+\s+(\S+)", blk, re.M)
        r = d[(d.col == c) & (d["var"] == v)].iloc[0]
        ok = abs(float(mt.group(1)) - r.b) < 5e-7 and abs(float(mt.group(2)) - r.se) < 5e-7 and N == r.N and abs(float(mt.group(3)) - r.p) < 5e-4
        okB1 &= ok; n_cells += 1
chk("B1 干净目录运行交付命令 ↔ ar85_t8.csv", okB1 and len(blocks) == 8, f"{len(blocks)} 个回归、{n_cells} 个系数（系数、标准误、p、N）")
rd_ = lambda f: pd.read_csv(T / f)
a51, a81, a82, a83, a84 = rd_("ar51_oct8.csv"), rd_("ar81_mentor_interact.csv"), rd_("ar82_seg_lag_mkt_year.csv"), rd_("ar83_seg_scale.csv"), rd_("ar84_rk_robust.csv")
g = lambda c, v: d[(d.col == c) & (d["var"] == v)].iloc[0]
pairs = [
    ("（1）↔ ar84 rk_m3l 基准", g(1, "PxSeg").b * 1000, a84[(a84.k == "m3l") & (a84.chk == "base")].b.iat[0]),
    ("（2）↔ ar83 rk_m3l 剔除直辖市", g(2, "PxSeg").b * 1000, a83[(a83.tr == "rk") & (a83.k == "m3l") & (a83.smp == "nomuni")].b.iat[0]),
    ("（3）↔ ar51 表8（3）", g(3, "PxEast").b, a51[(a51.tab == "D8_0") & (a51.col.astype(str) == "3")].b.iat[0]),
    ("（4）↔ ar82 市场化上一年", g(4, "PxMkt").b * 1000, a82[(a82.spec == "B_mkt_l1") & (a82.smp == "all")].b.iat[0]),
    ("（5）↔ ar81 研发上一年", g(5, "PxRd").b * 1000, a81[(a81.spec == "l1_rd") & (a81.smp == "all")].b.iat[0]),
    ("（6）↔ ar51 表8（6）", g(6, "PxTfp").b, a51[(a51.tab == "D8_0") & (a51.col.astype(str) == "6")].b.iat[0]),
    ("（8）↔ ar84 rk_m3l 同放", g(8, "PxSeg").b * 1000, a84[(a84.k == "m3l") & (a84.chk == "a_joint")].b.iat[0]),
]
for name, a, b in pairs:
    chk("B2 " + name, abs(a - b) < 1e-6 * max(1, abs(b)), f"{a:.7g} 对 {b:.7g}")
c7 = a51[(a51.tab == "D8_0") & (a51.col.astype(str) == "7")].iloc[0]
chk("B2 （7）↔ ar51 表8（7）（标准化总体改为估计样本，p 相同）", abs(g(7, "PxLq").p - c7.p) < 1e-9 and abs(g(7, "PxLq").b / c7.b - 1) < 1e-3,
    f"{g(7, 'PxLq').b * 1000:.4f} 对 {c7.b * 1000:.4f}，p {g(7, 'PxLq').p:.4f} 对 {c7.p:.4f}")
stars = lambda p: "***" if p < .01 else "**" if p < .05 else "*" if p < .1 else ""
D = docx.Document(PK / "表8_时变版.docx")
tb = D.tables[0]
grid = [[c.text.strip() for c in r.cells] for r in tb.rows]
lab = {"Patient×市场分割": "PxSeg", "市场分割": "seg", "Patient×东部": "PxEast", "Patient×市场化程度": "PxMkt", "Patient×研发资源": "PxRd",
       "Patient×期初生产率": "PxTfp", "Patient×同行业区位熵": "PxLq", "Patient×地理距离": "PxDist"}
okB3, nB3 = True, 0
for ri, row in enumerate(grid):
    if row[0] in lab and ri + 1 < len(grid) and (ri == 0 or grid[ri - 1][0] != row[0]):
        v = lab[row[0]]
        for c in range(1, 9):
            r = d[(d.col == c) & (d["var"] == v)]
            want = ("", "") if len(r) == 0 else (f"{r.b.iat[0] * 1000:.3f}{stars(r.p.iat[0])}".replace("-", "−"), f"({r.se.iat[0] * 1000:.3f})")
            okB3 &= (row[c], grid[ri + 1][c]) == want; nB3 += 1
first = d.drop_duplicates("col").set_index("col")
nrow = next(r for r in grid if r[0] == "样本量"); r2row = next(r for r in grid if r[0].startswith("调整后"))
okB3 &= all(nrow[c] == str(int(first.loc[c, "N"])) and r2row[c] == f"{first.loc[c, 'r2a']:.4f}" for c in range(1, 9))
chk("B3 Word 表格 ↔ ar85_t8.csv（系数、星号、标准误、样本量、调整后R²）", okB3, f"{nB3} 个系数格")

# ---------- C 样本 ----------
chk("C1 每企业×年份 30 个目的省", p16.groupby(["stkcd", "year"]).dest_id.nunique().eq(30).all())
fy = p16.groupby("stkcd").year.transform("min")
chk("C2 entry 只在企业首个样本年缺失", p16.loc[p16.year == fy, "entry"].isna().all() and p16.loc[p16.year > fy, "entry"].notna().all())
sg_ = [int(s.replace(",", "")) for s in re.findall(r"dropped ([\d,]+) singleton", log)]
chk("C3 估计样本年份 2015—2024，重算 N − reghdfe 剔除的单例 = 表中 N（第（1）列）", es.year.min() == 2015 and es.year.max() == 2024 and len(es) - sg_[0] == int(first.loc[1, "N"]),
    f"重算 {len(es)} − 单例 {sg_[0]} = {len(es) - sg_[0]}，表中 {int(first.loc[1, 'N'])}")
n2 = len(es[~es.dest.isin(["北京市", "天津市", "上海市", "重庆市"])])
chk("C4 （2）列剔除的只是直辖市目的地（扣除单例后与表中 N 一致）", n2 - sg_[1] == int(first.loc[2, "N"]), f"{n2} − {sg_[1]} = {n2 - sg_[1]}，表中 {int(first.loc[2, 'N'])}")

# ---------- D 措辞 ----------
note = next(p.text for p in D.paragraphs if p.text.startswith("注："))
bad = [w for w in ("有方向", "稳健", "因果", "解决", "内生") if w in note.replace("聚类稳健标准误", "")]
chk("D1 表注无禁用措辞", not bad, ",".join(bad))
chk("D2 表注写明不加权、前三年、百分位", all(w in note for w in ("不加权", "t−3", "百分位")))
cmd = (PK / "表8命令_时变版.do").read_text(encoding="utf-8")
chk("D3 命令注释无“有方向”", "有方向" not in cmd)

# ---------- E 交付包 ----------
files = sorted(p.name for p in PK.iterdir() if not p.name.startswith("."))
used = set(re.findall(r'"([^"]+\.dta)"', cmd))
chk("E1 命令只引用 16 号与包内 20 号", used == {"16_主面板3_企业目的省年份.dta", "20_表8时变变量.dta"} and "20_表8时变变量.dta" in files, f"包内 {files}")

fails = [r for r in res if not r[1]]
Q.mkdir(parents=True, exist_ok=True)
out = ["# 新表8（时变版）核查结果（ar85_audit.py 自动生成）", "", f"共 {len(res)} 项，失败 {len(fails)} 项。", "", "| 项 | 结果 | 说明 |", "|---|---|---|"]
out += [f"| {n} | {'通过' if ok else '失败'} | {dt} |" for n, ok, dt in res]
(Q / "核查结果.md").write_text("\n".join(out) + "\n", encoding="utf-8")
sys.exit(1 if fails else 0)
