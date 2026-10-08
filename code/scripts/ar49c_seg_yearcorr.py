"""ar49c_seg_yearcorr.py — 第十七轮补充诊断：母公司城市→目的省市场分割在 2010—2014 年逐年之间的相关。

口径同 ar49_build_seg_base.py（母公司城市取 analysis_ready 中出现过的城市，目的省内各城市取均值）。
输出：本 exploration 的 output/tables/ar49c_seg_yearcorr.csv；运行：python3 本文件（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["city_out"])
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(ar.city_out))]
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest", "market_seg_pair"])
sgt = sg.groupby(["city_out", "dest", "year"]).market_seg_pair.mean().reset_index()
sgt["year"] = sgt.year.astype(int)
w = sgt[sgt.year.between(2008, 2016)].pivot_table(index=["city_out", "dest"], columns="year", values="market_seg_pair")
w["m1013"] = w[[2010, 2011, 2012, 2013]].mean(axis=1)
c = w.corr().round(3)
print(c.to_string())
c.to_csv(EXP / "output/tables/ar49c_seg_yearcorr.csv")
