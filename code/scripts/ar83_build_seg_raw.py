"""ar83_build_seg_raw.py — 第四十三轮：导师城市对市场分割的逐年原始值（企业×目的省×年份）。

规则见本 exploration README 第四十三轮（运行前写定）。城市→省份映射、首年总部城市、省内等权平均与 ar69_export_panel3_v3.py 完全相同；
另保留 2008 年起的年份以便算上一年值与三年均值。先核对：当年值按全面板（16 号全部行中非缺失者）标准化后与 16 号 Segt_z 一致。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta（数值对称，见 D-169）；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta；16 号主面板3（核对用）
输出（不入版控）：data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta（stkcd、dest_id、year、seg_t、seg_l1、seg_m3、seg_m3l）
运行：python3 explorations/advisor_revision_20261005/scripts/ar83_build_seg_raw.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
P3 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
OUT = ROOT / "data/derived/advisor_send_20261008/城市对分割_逐年原始值.dta"

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out"])
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
city0 = ar.sort_values(["stkcd", "year"]).groupby("stkcd").city_out.first().rename("city0")

af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["PROVINCE", "CITY"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk[["city", "prov"]], af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])

sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(city0))]
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest", "market_seg_pair"])
sgt = sg.groupby(["city_out", "dest", "year"]).market_seg_pair.mean().reset_index()
sgt["year"] = sgt.year.astype(int)
sgt = sgt.rename(columns={"city_out": "city0", "market_seg_pair": "seg_t"})

# 上一年、三年均值（三年都有才算）：在 城市×目的省 的完整年份网格上移动
sgt = sgt.set_index(["city0", "dest", "year"]).seg_t
full = pd.MultiIndex.from_product([sgt.index.levels[0], sgt.index.levels[1], range(2001, 2025)], names=sgt.index.names)
s = sgt.reindex(full).groupby(level=[0, 1])
d = pd.DataFrame({"seg_t": sgt.reindex(full)})
d["seg_l1"] = s.shift(1)
d["seg_m3"] = s.transform(lambda x: x.rolling(3, min_periods=3).mean())
d["seg_m3l"] = d.groupby(level=[0, 1]).seg_m3.shift(1)
d = d.reset_index()

p0 = pd.read_stata(P3, columns=["stkcd", "year", "dest_id", "dest", "Segt_z"])
p = p0.copy(); p["stkcd"] = p.stkcd.astype(int); p["year"] = p.year.astype(int)
p = p.join(city0, on="stkcd").merge(d, on=["city0", "dest", "year"], how="left")
assert len(p) == len(p0)
z = (p.seg_t - p.seg_t.mean()) / p.seg_t.std()
diff = (z - p.Segt_z).abs().max()
print("当年值全面板标准化与 16 号 Segt_z 最大差", diff, "缺失一致", bool((z.isna() == p.Segt_z.isna()).all()))
assert diff < 1e-6 and (z.isna() == p.Segt_z.isna()).all()
for v in ["seg_t", "seg_l1", "seg_m3", "seg_m3l"]:
    print(v, "缺失率(2015起)", round(p.loc[p.year >= 2015, v].isna().mean(), 4), "最小值", float(p[v].min()))
out = p[["stkcd", "dest_id", "year", "seg_t", "seg_l1", "seg_m3", "seg_m3l"]]
out.to_stata(OUT, write_index=False, version=118)
print(len(out), OUT)
