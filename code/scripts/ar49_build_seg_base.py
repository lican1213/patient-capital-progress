"""ar49_build_seg_base.py — 第十七轮：双边面板补当期 Patient 与市场分割的其他基期。

规则见本 exploration README 第十七轮（运行前写定）。
按 um01_build.py 的同一口径重建双边面板键（stkcd、year、dest_id）与母公司城市，生成：
  Patient    当期耐心资本（analysis_ready）
  Seg0_chk   2010—2013 年均值（现行口径，用于与 dyad.dta 的 Seg0_z 对照）
  Seg14_z    2014 年单年（样本第一年）
  Segt_z     当年市场分割（不设基期）
标准化总体与 um01 相同：全部双边行中非缺失者。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta；data/derived/unified_market_dyadic_20260923/dyad.dta
输出（不入版控）：data/derived/advisor_revision_20261005/dyad_timing.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar49_build_seg_base.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_revision_20261005"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")

# 1. 企业-年份（同 um01 第 1 步）
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份", "Patient"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)

# 2. 目的省列表与城市→省映射（同 um01 第 3、4 步）
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
dy = ar.merge(pd.DataFrame({"dest": provs}), how="cross")
dy = dy[dy.dest != dy.home_prov].copy()
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"])
m1 = stk.rename(columns={"CITY": "city", "PROVINCE": "prov"})
m2 = af.rename(columns={"city_in": "city", "province_in": "prov"})
cmap = pd.concat([m1, m2]).dropna()
cmap = cmap[cmap.prov.isin(provs)]
cmap = cmap.groupby("city").prov.agg(lambda s: s.mode().iat[0])

# 3. 市场分割：母公司城市→目的省各城市均值（同 um01 第 5 步），另取 2014 年与当年
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(dy.home_city))]
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest", "market_seg_pair"])
sgt = sg.groupby(["city_out", "dest", "year"]).market_seg_pair.mean().reset_index()
sgt["year"] = sgt.year.astype(int)
seg0 = sgt[sgt.year.between(2010, 2013)].groupby(["city_out", "dest"]).market_seg_pair.mean().rename("Seg0").reset_index()
seg14 = sgt[sgt.year == 2014].drop(columns="year").rename(columns={"market_seg_pair": "Seg14"})
segt = sgt.rename(columns={"market_seg_pair": "Segt"})
dy = dy.merge(seg0.rename(columns={"city_out": "home_city"}), on=["home_city", "dest"], how="left")
dy = dy.merge(seg14.rename(columns={"city_out": "home_city"}), on=["home_city", "dest"], how="left")
dy = dy.merge(segt.rename(columns={"city_out": "home_city"}), on=["home_city", "dest", "year"], how="left")

dy["dest_id"] = dy.dest.astype("category").cat.codes + 1
for v in ["Seg0", "Seg14", "Segt"]:
    dy[v + "_z"] = (dy[v] - dy[v].mean()) / dy[v].std()
out = dy[["stkcd", "year", "dest_id", "Patient", "Seg0_z", "Seg14_z", "Segt_z"]].rename(columns={"Seg0_z": "Seg0_chk"})

# 4. 与 dyad.dta 对照：行数、键唯一、Seg0 一致
ref = pd.read_stata(ROOT / "data/derived/unified_market_dyadic_20260923/dyad.dta", columns=["stkcd", "year", "dest_id", "Seg0_z"])
ref["stkcd"] = ref.stkcd.astype(int); ref["year"] = ref.year.astype(int); ref["dest_id"] = ref.dest_id.astype(int)
out["dest_id"] = out.dest_id.astype(int)
assert len(out) == len(ref), (len(out), len(ref))
assert not out.duplicated(["stkcd", "year", "dest_id"]).any()
chk = ref.merge(out, on=["stkcd", "year", "dest_id"], how="outer", indicator=True)
assert (chk._merge == "both").all()
d = (chk.Seg0_z - chk.Seg0_chk).abs()
assert (chk.Seg0_z.isna() == chk.Seg0_chk.isna()).all()
assert d.max() < 1e-6, d.max()
print("rows", len(out), "Seg0 max diff", d.max())
for v in ["Seg0_chk", "Seg14_z", "Segt_z", "Patient"]:
    print(v, "missing share", round(out[v].isna().mean(), 4))
print(out[["Seg0_chk", "Seg14_z", "Segt_z"]].corr().round(3).to_string())
out.to_stata(OUT / "dyad_timing.dta", write_index=False, version=118)
