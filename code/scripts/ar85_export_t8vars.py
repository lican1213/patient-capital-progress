"""ar85_export_t8vars.py — 第四十五轮：新表8（时变版）所需的目的地时变变量，供交付。

规则见本 exploration README 第四十五轮。只合并已有中间数据，不重新构造：
  seg_m3l：ar83_build_seg_raw.py（导师城市对指数，首年总部城市，省内等权，前三年 t−3 至 t−1 均值，三年都有才算）；
  rd_l1：ar81_build_rd_year.py（目的省上一年 ln(1+上市公司发明专利申请量合计)）；
  mkt_l1：市场化总指数上一年值（同 mkt0 来源）。
只读输入：data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta、目的省研发资源_逐年.dta；
  data/raw/price_index/1997-2024年市场化指数和各分项指数.dta；16 号主面板3（键）
输出（不入版控）：data/derived/advisor_send_20261008/20_表8时变变量.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar85_export_t8vars.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
D = ROOT / "data/derived/advisor_send_20261008"
P3 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"

k = pd.read_stata(P3, columns=["stkcd", "dest_id", "dest", "year"])
for c in ("stkcd", "dest_id", "year"):
    k[c] = k[c].astype(int)
sg = pd.read_stata(D / "城市对分割_逐年原始值.dta", columns=["stkcd", "dest_id", "year", "seg_m3l"])
for c in ("stkcd", "dest_id", "year"):
    sg[c] = sg[c].astype(int)
rd = pd.read_stata(D / "目的省研发资源_逐年.dta", columns=["dest", "year", "rd_l1"]); rd["year"] = rd.year.astype(int)
mk = pd.read_stata("data/raw/price_index/1997-2024年市场化指数和各分项指数.dta", columns=["province_in", "year", "market"])
mk["year"] = mk.year.round().astype(int) + 1   # 上一年值：t−1 年的指数对应到 t 年
mk = mk.rename(columns={"province_in": "dest", "market": "mkt_l1"})

out = k.merge(sg, on=["stkcd", "dest_id", "year"], how="left", validate="1:1")
out = out.merge(rd, on=["dest", "year"], how="left", validate="m:1").merge(mk, on=["dest", "year"], how="left", validate="m:1")
assert len(out) == len(k)
s = out[out.year >= 2015]
print("2015 年起缺失率", s[["seg_m3l", "mkt_l1", "rd_l1"]].isna().mean().round(4).to_dict())
out = out[["stkcd", "dest_id", "year", "seg_m3l", "mkt_l1", "rd_l1"]]
out.to_stata(D / "20_表8时变变量.dta", write_index=False, version=118, variable_labels={
    "seg_m3l": "市场分割前三年均值（导师城市对指数，首年总部城市，省内等权，t-3至t-1）",
    "mkt_l1": "目的省上一年市场化总指数",
    "rd_l1": "目的省上一年研发资源 ln(1+上市公司发明专利申请量合计)"})
print(len(out), D / "20_表8时变变量.dta")
