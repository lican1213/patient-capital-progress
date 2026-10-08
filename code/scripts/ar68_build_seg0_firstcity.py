"""ar68_build_seg0_firstcity.py — 第二十九轮：表8 市场分割的母公司城市固定在企业首个样本年。

规则见本 exploration README 第二十九轮（运行前写定）。
先按 um01_build.py 原逻辑重建 Seg0（当年总部城市→目的省各城市 2010—2013 年有方向分割均值），核对与主面板3 的 Seg0_z 一致；
再把母公司城市换成企业首个样本年的 city_out 得到 Seg0f，同法在全部二元面板行上标准化。目的省集合与 entry 不变。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/derived/advisor_send_20261008/主面板3_企业目的省年份_v2.dta；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta
输出（不入版控）：data/derived/advisor_send_20261008/企业目的省基期市场分割_首年总部.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar68_build_seg0_firstcity.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
S = ROOT / "data/derived/advisor_send_20261008"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")

# 企业—年份的当年总部城市与首个样本年总部城市
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"city_out": "home_city", "母公司所在省份": "home_prov"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
first = ar.sort_values(["stkcd", "year"]).groupby("stkcd").home_city.first().rename("city0")
ar = ar.join(first, on="stkcd")
mv = ar.groupby("stkcd").home_city.nunique().gt(1).rename("mover").astype(int)
ar = ar.join(mv, on="stkcd")

# 城市→省份映射（同 um01_build.py 第 4 步）
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["PROVINCE", "CITY"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk[["city", "prov"]], af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])

# 有方向市场分割：城市→目的省各城市逐年均值，再取 2010—2013 年均值（同 um01_build.py 第 5 步）
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(ar.home_city) | set(ar.city0))]
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest", "market_seg_pair"])
sgt = sg.groupby(["city_out", "dest", "year"]).market_seg_pair.mean().reset_index()
seg0 = sgt[sgt.year.between(2010, 2013)].groupby(["city_out", "dest"]).market_seg_pair.mean().rename("v").reset_index()

# 合到主面板3 的行上
p = pd.read_stata(S / "主面板3_企业目的省年份_v2.dta", columns=["stkcd", "year", "dest_id", "dest", "Seg0_z"])
p["stkcd"] = p.stkcd.astype(int); p["year"] = p.year.astype(int)
n0 = len(p)
p = p.merge(ar[["stkcd", "year", "home_city", "city0", "mover"]], on=["stkcd", "year"], how="left", validate="m:1")
p = p.merge(seg0.rename(columns={"city_out": "home_city", "v": "Seg0"}), on=["home_city", "dest"], how="left")
p = p.merge(seg0.rename(columns={"city_out": "city0", "v": "Seg0f"}), on=["city0", "dest"], how="left")
assert len(p) == n0

# 核对：重建的当年城市口径与主面板3 的 Seg0_z 一致
z = (p.Seg0 - p.Seg0.mean()) / p.Seg0.std()
gap = (z - p.Seg0_z).abs()
print("重建 Seg0_z 与主面板3：缺失一致", bool((z.isna() == p.Seg0_z.isna()).all()), "最大绝对差", float(gap.max()))
assert (z.isna() == p.Seg0_z.isna()).all() and gap.max() < 1e-5

p["Seg0f_z"] = (p.Seg0f - p.Seg0f.mean()) / p.Seg0f.std()
ch = p[(p.Seg0f_z - p.Seg0_z).abs() > 1e-9]
print("总部迁移企业", int(ar.groupby("stkcd").mover.first().sum()), "；Seg0f_z 与 Seg0_z 不同的行", len(ch),
      "，涉及企业", ch.stkcd.nunique(), "；Seg0f_z 缺失率", round(p.Seg0f_z.isna().mean(), 4),
      "（原", round(p.Seg0_z.isna().mean(), 4), "）")
print("非迁移企业行上两者最大差", float((p.Seg0f_z - p.Seg0_z)[p.mover == 0].abs().max()))
print("相关", round(p[["Seg0_z", "Seg0f_z"]].corr().iat[0, 1], 4))
# 首年总部城市所在省份成为目的省的行（迁移企业迁出原省后）
hp0 = ar.sort_values(["stkcd", "year"]).groupby("stkcd").home_prov.first().rename("prov0")
p = p.join(hp0, on="stkcd")
print("目的省等于首年总部省份的行", int((p.dest == p.prov0).sum()), "，企业", p.loc[p.dest == p.prov0, "stkcd"].nunique())
p["dest_is_prov0"] = (p.dest == p.prov0).astype(int)
out = p[["stkcd", "year", "dest_id", "Seg0f_z", "mover", "dest_is_prov0"]]
out.to_stata(S / "企业目的省基期市场分割_首年总部.dta", write_index=False, version=118,
             variable_labels={"Seg0f_z": "基期市场分割（首个样本年总部城市，2010—2013年均值，标准化）",
                              "mover": "样本期内总部城市变化过", "dest_is_prov0": "目的省为首年总部所在省"})
print(S / "企业目的省基期市场分割_首年总部.dta")
