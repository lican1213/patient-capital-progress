"""ar86_build_dest_yearly.py — 第四十六轮 A：目的省逐年变量（企业×目的省×年份）。

规则见本 exploration README 第四十六轮。
  seg_eq / seg_gdp / seg_gdw：导师城市对市场分割当年值，母公司城市取企业首个样本年城市，目的省内城市按 等权 / 2014 年 GDP / 2014 年 GDP÷球面距离 加权；
  region：国家统计局东中西三分；gdp_hi、lngdpr：目的省当年 GDP 与本省（企业当年母公司所在省份）比较；
  rdint：企业当年研发强度（导师主面板1）。
先核对 seg_eq 与 16 号 Segt_z（全面板标准化后）逐格一致。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta、city_distance_full.xlsx；
  data/raw/mentor_panel_20261008/主面板1、主面板2；data/raw/price_index/城市对市场分割…2001-2024.dta；CSMAR 上市公司信息；16 号主面板3
输出（不入版控）：data/derived/advisor_send_20261008/目的省逐年变量_ar86.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar86_build_dest_yearly.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
M1 = ROOT / "data/raw/mentor_panel_20261008/主面板1_含区位熵_地理IV_创新指标.dta"
M2 = ROOT / "data/raw/mentor_panel_20261008/主面板2_关联公司具体细节.dta"
OUT = ROOT / "data/derived/advisor_send_20261008/目的省逐年变量_ar86.dta"

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out"])
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
city0 = ar.sort_values(["stkcd", "year"]).groupby("stkcd").city_out.first().rename("city0")

af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["PROVINCE", "CITY"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk[["city", "prov"]], af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])

# 城市对指数当年值（城市级，未平均）
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta", columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(city0)) & sg.year.between(2014, 2024)].copy()
sg["dest"] = sg.city_in.map(cmap); sg["year"] = sg.year.astype(int)
sg = sg.dropna(subset=["dest", "market_seg_pair"])

# 目的城市 2014 年 GDP、坐标与到母公司城市的距离
gdp = (pd.read_stata(M2, columns=["city_in", "gdp_in_2014"]).dropna().drop_duplicates("city_in").set_index("city_in").gdp_in_2014)
di = pd.read_excel(ROOT / "data/raw/source_snapshots/city_distance_full.xlsx")
co = pd.concat([di[["city_out", "longitude_out", "latitude_out"]].set_axis(["city", "lon", "lat"], axis=1),
                di[["city_in", "longitude_in", "latitude_in"]].set_axis(["city", "lon", "lat"], axis=1)]).dropna().drop_duplicates("city").set_index("city")
sg["gdp"] = sg.city_in.map(gdp)
lo, la = sg.city_out.map(co.lon), sg.city_out.map(co.lat)
ld, ldd = sg.city_in.map(co.lon), sg.city_in.map(co.lat)
p1, p2 = np.radians(la), np.radians(ldd)
sg["km"] = 6371 * 2 * np.arcsin(np.sqrt(np.sin((p2 - p1) / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(np.radians(ld - lo) / 2) ** 2))
sg["w_gdp"] = sg.gdp
sg["w_gdw"] = sg.gdp / sg.km


def wavg(g, w):
    x = g.dropna(subset=[w])
    x = x[x[w] > 0]
    return np.average(x.market_seg_pair, weights=x[w]) if len(x) else np.nan


grp = sg.groupby(["city_out", "dest", "year"])
s = pd.DataFrame({"seg_eq": grp.market_seg_pair.mean(),
                  "seg_gdp": grp.apply(lambda g: wavg(g, "w_gdp")),
                  "seg_gdw": grp.apply(lambda g: wavg(g, "w_gdw")),
                  "n_eq": grp.size(),
                  "n_gdw": grp.apply(lambda g: int(((g.w_gdw > 0) & g.w_gdw.notna()).sum()))}).reset_index().rename(columns={"city_out": "city0"})
print("省内城市数：等权中位数", s.n_eq.median(), "GDP/距离可用中位数", s.n_gdw.median())

p = pd.read_stata(P16, columns=["stkcd", "year", "dest_id", "dest", "Segt_z"])
for c in ("stkcd", "year", "dest_id"):
    p[c] = p[c].astype(int)
n0 = len(p)
p = p.join(city0, on="stkcd").merge(s, on=["city0", "dest", "year"], how="left")
assert len(p) == n0
z = (p.seg_eq - p.seg_eq.mean()) / p.seg_eq.std()
print("seg_eq 标准化与 16 号 Segt_z 最大差", float((z - p.Segt_z).abs().max()))
assert (z - p.Segt_z).abs().max() < 1e-9 and (z.isna() == p.Segt_z.isna()).all()
print("三种权重相关（2015 年起）"); print(p[p.year >= 2015][["seg_eq", "seg_gdp", "seg_gdw"]].corr().round(3).to_string())

# 东中西（国家统计局三分）
EAST = {"北京市", "天津市", "河北省", "辽宁省", "上海市", "江苏省", "浙江省", "福建省", "山东省", "广东省", "海南省"}
CENT = {"山西省", "吉林省", "黑龙江省", "安徽省", "江西省", "河南省", "湖北省", "湖南省"}
p["d_east"] = p.dest.isin(EAST).astype(int)
p["d_cent"] = p.dest.isin(CENT).astype(int)

# 省份×年份 GDP 与企业当年所在省份、研发强度
m1 = pd.read_stata(M1, columns=["stkcd", "year", "母公司所在省份", "GDP母公司所在省份", "研发投入占营业收入比例"])
m1["stkcd"] = m1.stkcd.astype(int); m1["year"] = m1.year.astype(int)
pg = m1.dropna(subset=["GDP母公司所在省份"]).groupby(["母公司所在省份", "year"])["GDP母公司所在省份"].first()
assert set(p.dest) <= set(pg.index.get_level_values(0))
fm = m1.drop_duplicates(["stkcd", "year"]).rename(columns={"母公司所在省份": "home", "研发投入占营业收入比例": "rdint"})
p = p.merge(fm[["stkcd", "year", "home", "rdint"]], on=["stkcd", "year"], how="left")
p["gdp_d"] = [pg.get((d, t), np.nan) for d, t in zip(p.dest, p.year)]
p["gdp_h"] = [pg.get((h, t), np.nan) for h, t in zip(p.home, p.year)]
p["gdp_hi"] = np.where(p.gdp_d.notna() & p.gdp_h.notna(), (p.gdp_d > p.gdp_h).astype(float), np.nan)
p["lngdpr"] = np.log(p.gdp_d / p.gdp_h)
print("目的省等于本省的行（应为 0 或极少，16 号已剔除本省）", int((p.dest == p.home).sum()))
print("gdp_hi 均值（2015 起）", round(p.loc[p.year >= 2015, "gdp_hi"].mean(), 3), "缺失率", round(p.loc[p.year >= 2015, "gdp_hi"].isna().mean(), 4))
print("rdint 缺失率（2015 起）", round(p.loc[p.year >= 2015, "rdint"].isna().mean(), 4))
out = p[["stkcd", "dest_id", "year", "seg_eq", "seg_gdp", "seg_gdw", "d_east", "d_cent", "gdp_hi", "lngdpr", "rdint"]]
out.to_stata(OUT, write_index=False, version=118)
print(len(out), OUT)
