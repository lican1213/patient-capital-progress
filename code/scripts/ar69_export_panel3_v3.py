"""ar69_export_panel3_v3.py — 第三十轮：主面板3 的三列市场分割改为母公司城市固定在企业首个样本年。

规则见本 exploration README 第三十轮（运行前写定）。城市→省份映射、指数处理与 um01_build.py、ar49_build_seg_base.py 相同，
只把匹配用的母公司城市从当年总部换成企业首个样本年的总部；标准化总体仍为全部二元面板行中非缺失者。其余列逐格不变。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/derived/advisor_send_20261008/主面板3_企业目的省年份_v2.dta、企业目的省基期市场分割_首年总部.dta（ar68，核对用）；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta
输出（不入版控）：data/derived/advisor_send_20261008/主面板3_企业目的省年份_v3.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar69_export_panel3_v3.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
S = ROOT / "data/derived/advisor_send_20261008"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")

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
sgt = sgt.rename(columns={"city_out": "city0"})
seg0 = sgt[sgt.year.between(2010, 2013)].groupby(["city0", "dest"]).market_seg_pair.mean().rename("Seg0").reset_index()
seg14 = sgt[sgt.year == 2014].drop(columns="year").rename(columns={"market_seg_pair": "Seg14"})
segt = sgt.rename(columns={"market_seg_pair": "Segt"})

rd = pd.read_stata(S / "主面板3_企业目的省年份_v2.dta", iterator=True)
labels = rd.variable_labels()
p0 = rd.read()
p = p0.copy()
p["stkcd_i"] = p.stkcd.astype(int); p["year_i"] = p.year.astype(int)
p = p.join(city0, on="stkcd_i")
p = p.merge(seg0, on=["city0", "dest"], how="left")
p = p.merge(seg14, on=["city0", "dest"], how="left")
p = p.merge(segt.rename(columns={"year": "year_i"}), on=["city0", "dest", "year_i"], how="left")
assert len(p) == len(p0)
for v in ["Seg0", "Seg14", "Segt"]:
    p[v + "_z"] = (p[v] - p[v].mean()) / p[v].std()

# 核对：Seg0_z 与 ar68 的 Seg0f_z 逐格相同
f = pd.read_stata(S / "企业目的省基期市场分割_首年总部.dta")
f["stkcd"] = f.stkcd.astype(int); f["year"] = f.year.astype(int); f["dest_id"] = f.dest_id.astype(int)
k = p[["stkcd_i", "year_i", "dest_id", "Seg0_z"]].assign(dest_id=lambda d: d.dest_id.astype(int)).rename(columns={"stkcd_i": "stkcd", "year_i": "year"})
k = k.merge(f, on=["stkcd", "year", "dest_id"], how="left", validate="1:1")
assert (k.Seg0_z.isna() == k.Seg0f_z.isna()).all() and (k.Seg0_z - k.Seg0f_z).abs().max() < 1e-9

cols = list(p0.columns)
out = p[cols]
other = [c for c in cols if c not in ("Seg0_z", "Seg14_z", "Segt_z")]
pd.testing.assert_frame_equal(out[other].reset_index(drop=True), p0[other].reset_index(drop=True))
for v in ["Seg0_z", "Seg14_z", "Segt_z"]:
    print(v, "缺失率", round(out[v].isna().mean(), 4), "原", round(p0[v].isna().mean(), 4),
          "与原相关", round(pd.concat([out[v], p0[v]], axis=1).corr().iat[0, 1], 4))
labels.update({"Seg0_z": "基期市场分割（首个样本年总部城市，2010—2013年均值，标准化）",
               "Seg14_z": "2014年市场分割（首个样本年总部城市，标准化）",
               "Segt_z": "当年市场分割（首个样本年总部城市，标准化）"})
out.to_stata(S / "主面板3_企业目的省年份_v3.dta", write_index=False, version=118, variable_labels=labels)
print(len(out), S / "主面板3_企业目的省年份_v3.dta")
