"""ar63_build_eqweight.py — 第二十五轮：企业层面的等权基期市场一体化与分割（不依赖企业自身布局）。

规则见本 exploration README 第二十五轮（运行前写定）。
母公司城市取企业首个样本年的 city_out；外省＝母公司所在省以外、子公司明细中出现过的省份。
城市→外省：该城市到省内各城市的有方向指数等权平均；外省→企业：各外省等权平均；年份：2010—2013 等权平均（另算首个样本年当年值）。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta
输出（不入版控）：data/derived/advisor_send_20261008/企业基期市场分割等权.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar63_build_eqweight.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_send_20261008"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
first = ar.sort_values(["stkcd", "year"]).groupby("stkcd").first().reset_index()   # 首个样本年的母公司城市与省份
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
# 城市→省份映射（同 um01）
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair", "market_integ_pair"])
sg = sg[sg.city_out.isin(set(first.home_city))]
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest"])
sg["year"] = sg.year.astype(int)
# 城市→省：省内各城市等权
cp = sg.groupby(["city_out", "dest", "year"])[["market_seg_pair", "market_integ_pair"]].mean().reset_index()
res = []
for _, f in first.iterrows():
    d = cp[(cp.city_out == f.home_city) & (cp.dest != f.home_prov)]
    # 外省等权：先按年对外省平均，再取 2010—2013 年平均；另取首个样本年当年值
    yr = d.groupby("year")[["market_seg_pair", "market_integ_pair"]].mean()
    base = yr.loc[yr.index.isin(range(2010, 2014))].mean()
    fy = yr.loc[f.year] if f.year in yr.index else pd.Series({"market_seg_pair": np.nan, "market_integ_pair": np.nan})
    res.append({"stkcd": f.stkcd, "seg_eq0": base.market_seg_pair, "integ_eq0": base.market_integ_pair,
                "seg_eqfy": fy.market_seg_pair, "integ_eqfy": fy.market_integ_pair,
                "n_dest": d[d.year.between(2010, 2013)].dest.nunique()})
out = pd.DataFrame(res)
out["linteg_eq0"] = np.log1p(out.integ_eq0)
out["linteg_eqfy"] = np.log1p(out.integ_eqfy)
print(out.describe().T[["count", "mean", "std", "min", "max"]].round(4).to_string())
print(out[["seg_eq0", "linteg_eq0", "seg_eqfy", "linteg_eqfy"]].corr().round(3).to_string())
out.to_stata(OUT / "企业基期市场分割等权.dta", write_index=False, version=118)
