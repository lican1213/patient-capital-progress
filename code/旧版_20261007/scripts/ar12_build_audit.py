"""ar12_build_audit.py — 对抗审计 AU2：目的地 TFP 稳健口径（quality_reports/advisor_feedback_20261005/对抗审计_20261007.md）。

dest_attr_au.dta（dest_id）：tfp0_n10（2014 年样本企业<10 家的省份设缺失）、tfp01（2014—2015 均值）
运行：python3 explorations/advisor_revision_20261005/scripts/ar12_build_audit.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_revision_20261005"
MP = Path("data/mentor_panel/主面板_含区位熵_地理IV_创新指标.dta")
provs = sorted(pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                             columns=["province_in"]).province_in.dropna().unique())
da = pd.DataFrame({"dest": provs})
da["dest_id"] = da.dest.astype("category").cat.codes + 1
mp = pd.read_stata(MP, columns=["year", "TFP", "母公司所在省份"])
g14 = mp[mp.year == 2014].groupby("母公司所在省份").TFP.agg(["mean", "count"])
da["tfp0_n10"] = da.dest.map(g14["mean"].where(g14["count"] >= 10))
da["tfp01"] = da.dest.map(mp[mp.year.isin([2014, 2015])].groupby("母公司所在省份").TFP.mean())
print(da.isna().sum().to_dict())
da[["dest_id", "tfp0_n10", "tfp01"]].to_stata(OUT / "dest_attr_au.dta", write_index=False, version=118)
