"""ar74_build_gdpdist_prov.py — 第三十四轮：母公司城市到目的省距离，省内由等权改为按城市 2014 年 GDP 加权。

规则见本 exploration README 第三十四轮（运行前写定）。
坐标、城市→省映射、半正矢距离与 um01_build.py 第 6 步完全相同，只把省内平均换成 GDP 加权平均。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta、city_distance_full.xlsx；
  data/raw/mentor_panel_20261008/主面板2_关联公司具体细节.dta（gdp_in_2014）；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta；
  deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta（核对 lndist）
输出（不入版控）：data/derived/advisor_send_20261008/距离对数_省内GDP加权.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar74_build_gdpdist_prov.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_send_20261008"
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"

# 企业×年份母公司城市（当年）与首个样本年城市
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out"])
ar = ar.rename(columns={"city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
ar["home_city_f"] = ar.sort_values(["stkcd", "year"]).groupby("stkcd").home_city.transform("first")

# 城市→省份映射（同 um01 第 4 步）
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])

# 距离（同 um01 第 6 步），加目的城市 GDP
di = pd.read_excel(ROOT / "data/raw/source_snapshots/city_distance_full.xlsx")
co = pd.concat([di[["city_out", "longitude_out", "latitude_out"]].set_axis(["city", "lon", "lat"], axis=1),
                di[["city_in", "longitude_in", "latitude_in"]].set_axis(["city", "lon", "lat"], axis=1)]).dropna().drop_duplicates("city")
co["dest"] = co.city.map(cmap)
homes = set(ar.home_city) | set(ar.home_city_f)
hc = co[co.city.isin(homes)][["city", "lon", "lat"]]
dd = hc.merge(co.dropna(subset=["dest"]), how="cross", suffixes=("_o", "_d"))
p1, p2 = np.radians(dd.lat_o), np.radians(dd.lat_d)
dd["km"] = 6371 * 2 * np.arcsin(np.sqrt(np.sin((p2 - p1) / 2) ** 2 +
           np.cos(p1) * np.cos(p2) * np.sin(np.radians(dd.lon_d - dd.lon_o) / 2) ** 2))
dd = dd[dd.city_o != dd.city_d]
gdp = (pd.read_stata(ROOT / "data/raw/mentor_panel_20261008/主面板2_关联公司具体细节.dta", columns=["city_in", "gdp_in_2014"])
       .dropna().drop_duplicates("city_in").set_index("city_in").gdp_in_2014)
dd["gdp"] = dd.city_d.map(gdp)
dest_cities = co.dropna(subset=["dest"])
nog = dest_cities[~dest_cities.city.isin(gdp.index)]
print("目的城市（有坐标和省份）", len(dest_cities), "；有 2014 年 GDP", len(dest_cities) - len(nog))
print("无 GDP、不进入加权的城市：", "、".join(sorted(nog.city)))


def agg(g):
    w = g.dropna(subset=["gdp"])
    return pd.Series({"dist_eq": g.km.mean(),
                      "dist_gdp": np.average(w.km, weights=w.gdp) if len(w) else np.nan,
                      "n_city": len(g), "n_city_gdp": len(w)})


pd_ = dd.groupby(["city_o", "dest"]).apply(agg).reset_index().rename(columns={"city_o": "home"})
print(pd_[["dist_eq", "dist_gdp", "n_city", "n_city_gdp"]].describe().round(2).to_string())
print("等权与GDP加权距离（对数）相关：", round(np.log(pd_[["dist_eq", "dist_gdp"]]).corr().iat[0, 1], 4))

# 并到 16 号的企业×目的省×年份
p16 = pd.read_stata(P16, columns=["stkcd", "year", "dest", "lndist"])
p16["stkcd"] = p16.stkcd.astype(int); p16["year"] = p16.year.astype(int)
p16 = p16.merge(ar, on=["stkcd", "year"], how="left")
cur = pd_.rename(columns={"home": "home_city"})
p16 = p16.merge(cur[["home_city", "dest", "dist_eq", "dist_gdp"]], on=["home_city", "dest"], how="left")
fst = pd_.rename(columns={"home": "home_city_f", "dist_gdp": "dist_gdp_f"})
p16 = p16.merge(fst[["home_city_f", "dest", "dist_gdp_f"]], on=["home_city_f", "dest"], how="left")
p16["lndist_eq_chk"] = np.log(p16.dist_eq)
p16["lndist_gdp"] = np.log(p16.dist_gdp)
p16["lndist_gdp_f"] = np.log(p16.dist_gdp_f)

# 核对：等权复算须与 16 号 lndist 一致
both = p16.dropna(subset=["lndist", "lndist_eq_chk"])
mx = (both.lndist - both.lndist_eq_chk).abs().max()
print("等权复算与16号 lndist：两边非缺失", len(both), "，最大差", mx,
      "；16号有而复算缺", int((p16.lndist.notna() & p16.lndist_eq_chk.isna()).sum()),
      "；复算有而16号缺", int((p16.lndist.isna() & p16.lndist_eq_chk.notna()).sum()))
assert mx < 1e-6, "等权复算与 16 号 lndist 不一致，停止"
print("非缺失率：lndist", round(p16.lndist.notna().mean(), 4), " lndist_gdp", round(p16.lndist_gdp.notna().mean(), 4),
      " lndist_gdp_f", round(p16.lndist_gdp_f.notna().mean(), 4))
print("lndist 与 lndist_gdp 相关（观测层）：", round(p16[["lndist", "lndist_gdp"]].corr().iat[0, 1], 4))

out = p16[["stkcd", "year", "dest", "lndist_gdp", "lndist_gdp_f"]]
out.to_stata(OUT / "距离对数_省内GDP加权.dta", write_index=False, version=118)
print(OUT / "距离对数_省内GDP加权.dta")
