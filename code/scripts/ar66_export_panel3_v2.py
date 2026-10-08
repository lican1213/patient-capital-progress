"""ar66_export_panel3_v2.py — 第二十八轮：主面板3 加附表6 用的三列（距离对数、当期与上一期短期机构持股）。

规则见本 exploration README 第二十八轮。原有各列逐格不变（assert），只在其后加列。
只读输入：data/derived/advisor_send_20261008/主面板3_企业目的省年份.dta（ar51 导出）；
  data/derived/unified_market_dyadic_20260923/dyad.dta（lndist、L_io_short）；
  data/derived/advisor_send_20261008/企业短期机构持股当期.dta（ar65）
输出（不入版控）：data/derived/advisor_send_20261008/主面板3_企业目的省年份_v2.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar66_export_panel3_v2.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
S = ROOT / "data/derived/advisor_send_20261008"
rd = pd.read_stata(S / "主面板3_企业目的省年份.dta", iterator=True)
labels = rd.variable_labels()
p0 = rd.read()
k = ["stkcd", "year", "dest_id"]
dy = pd.read_stata(ROOT / "data/derived/unified_market_dyadic_20260923/dyad.dta", columns=k + ["lndist", "L_io_short"])
io = pd.read_stata(S / "企业短期机构持股当期.dta", columns=["stkcd", "year", "io_short"])
for d in (p0, dy, io):
    d["stkcd"] = d.stkcd.astype(int); d["year"] = d.year.astype(int)
dy["dest_id"] = dy.dest_id.astype(int); p0dest = p0.dest_id.dtype
p = p0.assign(dest_id=p0.dest_id.astype(int)).merge(dy.assign(dest_id=dy.dest_id.astype(int)), on=k, how="left", validate="1:1")
p = p.merge(io, on=["stkcd", "year"], how="left", validate="m:1")
p["dest_id"] = p.dest_id.astype(p0dest)
assert len(p) == len(p0)
pd.testing.assert_frame_equal(p[p0.columns].reset_index(drop=True), p0.reset_index(drop=True))
cols = list(p0.columns) + ["lndist", "io_short", "L_io_short"]
labels.update({"lndist": "母公司城市到目的省的球面距离对数", "io_short": "当期短期（非长期）主动机构持股比例",
               "L_io_short": "上一自然年短期（非长期）主动机构持股比例"})
p[cols].to_stata(S / "主面板3_企业目的省年份_v2.dta", write_index=False, version=118, variable_labels=labels)
print(len(p), p[["lndist", "io_short", "L_io_short"]].notna().mean().round(4).to_dict())
