"""ar81_build_rd_year.py — 第四十一轮：目的省研发资源改为逐年值。

规则见本 exploration README 第四十一轮（运行前写定）。来源与算法同 skeleton_source_audit 的 ar05（rdres0）：
上市公司-研发投入与专利数据（2000-2024年）按“省份”“year”对“企业发明专利申请量”求和，再取 ln(1+x)；
rdres0 取 2010—2013 年均值，这里保留逐年值 rd_t，并给出上一年值 rd_l1。省份名与 16 号面板 dest 一致。
只读输入：data/raw/price_index/上市公司-研发投入与专利数据（2000-2024年）.dta；16 号主面板3（只读 dest 列核对）
输出（不入版控）：data/derived/advisor_send_20261008/目的省研发资源_逐年.dta（dest、year、rd_t、rd_l1）
运行：python3 explorations/advisor_revision_20261005/scripts/ar81_build_rd_year.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CY = Path("data/raw/price_index")
P3 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
OUT = ROOT / "data/derived/advisor_send_20261008/目的省研发资源_逐年.dta"

rd = pd.read_stata(CY / "上市公司-研发投入与专利数据（2000-2024年）.dta", columns=["year", "企业发明专利申请量", "省份"])
rd["year"] = rd.year.astype(int)
dests = sorted(pd.read_stata(P3, columns=["dest"]).dest.unique())
s = rd[rd.省份.isin(dests)].groupby(["省份", "year"])["企业发明专利申请量"].sum()
full = pd.MultiIndex.from_product([dests, range(2009, 2025)], names=["省份", "year"])
s = s.reindex(full)  # 某省某年无记录保留缺失，不补 0
d = s.rename("pat").reset_index().rename(columns={"省份": "dest"})
d["rd_t"] = np.log1p(d.pat)
d = d.sort_values(["dest", "year"])
d["rd_l1"] = d.groupby("dest").rd_t.shift(1)
d = d[d.year.between(2014, 2024)]
print("目的省数", d.dest.nunique(), "缺失 rd_t", int(d.rd_t.isna().sum()))

# 核对：2010—2013 均值复算须与 16 号面板 rdres0 一致
chk = rd[rd.省份.isin(dests) & rd.year.between(2010, 2013)].groupby(["省份", "year"])["企业发明专利申请量"].sum().groupby(level=0).mean()
p3 = pd.read_stata(P3, columns=["dest", "rdres0"]).drop_duplicates()
p3["chk"] = np.log1p(p3.dest.map(chk))
print("rdres0 复算最大差", float((p3.rdres0 - p3.chk).abs().max()))
assert (p3.rdres0 - p3.chk).abs().max() < 1e-6
print("rd_t 与 rd_l1 相关", round(d[["rd_t", "rd_l1"]].corr().iat[0, 1], 4))
print("各年跨省相关（rd_t 与 rdres0）")
m = d.merge(p3[["dest", "rdres0"]], on="dest")
print(m.groupby("year").apply(lambda g: round(g.rd_t.corr(g.rdres0), 3)).to_string())
d[["dest", "year", "rd_t", "rd_l1"]].to_stata(OUT, write_index=False, version=118,
    variable_labels={"rd_t": "目的省当年研发资源 ln(1+上市公司发明专利申请量合计)", "rd_l1": "目的省上一年研发资源"})
print(OUT)
