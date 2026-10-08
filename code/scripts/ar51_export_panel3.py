"""ar51_export_panel3.py — 第十八轮：导出给导师的主面板3（企业×目的省×年份）。

由现有双边面板与目的省属性合并而成，变量取原值（标准化、缩尾在命令里做），另附目的省名称，
以便导师用主面板2（关联公司具体细节）重建“当年新设”并核对。
只读输入：data/derived/unified_market_dyadic_20260923/dyad.dta；data/derived/advisor_revision_20261005/
  {dest_attr,dest_attr_m7,dest_attr_au,dyad_lq,dyad_rdfix_v2,dyad_timing}.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta
输出（不入版控）：data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar51_export_panel3.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
D = ROOT / "data/derived/advisor_revision_20261005"
OUT = ROOT / "data/derived/advisor_send_20261008"
OUT.mkdir(exist_ok=True)
i = lambda d, cs: d.astype({c: int for c in cs})
dy = i(pd.read_stata(ROOT / "data/derived/unified_market_dyadic_20260923/dyad.dta",
                     columns=["stkcd", "year", "dest_id", "L_Patient", "Seg0_z", "entry"]), ["stkcd", "year", "dest_id"])
tm = i(pd.read_stata(D / "dyad_timing.dta", columns=["stkcd", "year", "dest_id", "Patient", "Seg14_z", "Segt_z"]), ["stkcd", "year", "dest_id"])
a1 = i(pd.read_stata(D / "dest_attr.dta"), ["dest_id"])
a2 = i(pd.read_stata(D / "dest_attr_m7.dta"), ["dest_id"])
a3 = i(pd.read_stata(D / "dest_attr_au.dta", columns=["dest_id", "tfp0_n10"]), ["dest_id"])
lq = i(pd.read_stata(D / "dyad_lq.dta"), ["stkcd", "dest_id"])
rd = i(pd.read_stata(D / "dyad_rdfix_v2.dta"), ["stkcd", "year", "dest_id"])
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["province_in"])
provs = sorted(af.province_in.dropna().unique())
nm = pd.DataFrame({"dest_id": range(1, len(provs) + 1), "dest": provs})
p = dy.merge(tm, on=["stkcd", "year", "dest_id"], how="left", validate="1:1")
p = p.merge(nm, on="dest_id", how="left", validate="m:1")
for a in (a1, a2, a3):
    p = p.merge(a, on="dest_id", how="left", validate="m:1")
p = p.merge(lq, on=["stkcd", "dest_id"], how="left", validate="m:1")
p = p.merge(rd[["stkcd", "year", "dest_id", "new_rdfix_any"]], on=["stkcd", "year", "dest_id"], how="left", validate="1:1")
assert len(p) == len(dy) and p.dest.notna().all()
assert set(p.loc[p.dest_id.isin([1, 4, 7, 28]), "dest"]) == {"上海市", "北京市", "天津市", "重庆市"}
cols = ["stkcd", "year", "dest_id", "dest", "entry", "new_rdfix_any", "Patient", "L_Patient", "Seg0_z", "Seg14_z", "Segt_z",
        "east", "mkt0", "rdres0", "tfp0", "tfp0_n10", "lq"]
p = p[cols].sort_values(["stkcd", "year", "dest_id"])
p.to_stata(OUT / "主面板3_企业目的省年份.dta", write_index=False, version=118, variable_labels={
    "dest": "目的省", "entry": "当年是否在该省新设跨省子公司（企业首个样本年为缺失）", "new_rdfix_any": "当年是否在该省新设研发型子公司",
    "Patient": "当期耐心资本", "L_Patient": "上一自然年耐心资本", "Seg0_z": "基期市场分割（2010-2013均值，标准化）",
    "Seg14_z": "2014年市场分割（标准化）", "Segt_z": "当年市场分割（标准化）", "east": "目的省是否东部",
    "mkt0": "目的省市场化程度（2010-2013均值）", "rdres0": "目的省研发资源（2010-2013均值）",
    "tfp0": "目的省期初生产率（2014年上市公司TFP均值）", "tfp0_n10": "期初生产率（剔除上市公司少于10家省份）",
    "lq": "同行业区位熵（2010-2013）"})
print(len(p), p.stkcd.nunique(), p.columns.tolist())
