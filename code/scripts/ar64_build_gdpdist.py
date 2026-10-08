"""ar64_build_gdpdist.py — 第二十六轮：GDP/距离加权、覆盖全部外省城市、固定基期的企业市场分割与一体化。

规则见本 exploration README 第二十六轮（运行前写定）。
权重沿用导师主面板2 w_ext_2014 的公式：目的城市 2014 年 GDP ÷ 母公司城市到目的城市的球面距离；
分配范围改为母公司所在省以外的全部城市（有 GDP、坐标和分割指数的），母公司城市取企业首个样本年的 city_out。
分割、一体化：母公司城市到各城市的有方向指数 2010—2013 年均值，再按权重加权；一体化另取 ln(1+x)。
只读输入：data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/mentor_panel/主面板1_含区位熵_地理IV_创新指标.dta、主面板2_关联公司具体细节.dta；
  data/raw/price_index/城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta；
  data/raw/city_coords/城市间球面距离计算结果_完整版.xlsx、补充城市经纬度.xlsx；
  data/raw/csmar/STK_LISTEDCOINFOANL.dta
输出（不入版控）：data/derived/advisor_send_20261008/企业基期市场分割GDP距离加权.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar64_build_gdpdist.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_send_20261008"
MP = ROOT / "data/mentor_panel"
CY = Path("data/raw/price_index")
DX = Path("data/raw/city_coords")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")


def hav(lon1, lat1, lon2, lat2):
    lon1, lat1, lon2, lat2 = map(np.radians, (lon1, lat1, lon2, lat2))
    a = np.sin((lat2 - lat1) / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin((lon2 - lon1) / 2) ** 2
    return 2 * 6371.0 * np.arcsin(np.sqrt(a))


# 企业首个样本年的母公司城市与省份（同 ar63）
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
first = ar.sort_values(["stkcd", "year"]).groupby("stkcd").first().reset_index()

# 城市→省份映射（同 ar63）
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
provs = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])

# 坐标：主面板1 → 完整版距离表 → 补充表，先到先用
co = {}
m1 = pd.read_stata(MP / "主面板1_含区位熵_地理IV_创新指标.dta", columns=["city_out", "city_lon", "city_lat"]).dropna()
for r in m1.drop_duplicates("city_out").itertuples():
    co.setdefault(r.city_out, (r.city_lon, r.city_lat))
xl = pd.read_excel(DX / "城市间球面距离计算结果_完整版.xlsx")
for r in xl.itertuples():
    if pd.notna(r.longitude_out):
        co.setdefault(r.city_out, (r.longitude_out, r.latitude_out))
    if pd.notna(r.longitude_in):
        co.setdefault(r.city_in, (r.longitude_in, r.latitude_in))
for r in pd.read_excel(DX / "补充城市经纬度.xlsx").itertuples():
    co.setdefault(r.city, (r.lon, r.lat))
co = pd.DataFrame([(k, v[0], v[1]) for k, v in co.items()], columns=["city", "lon", "lat"])

# 城市 2014 年 GDP：导师主面板2 的 gdp_in_2014（每城市唯一值）
m2 = pd.read_stata(MP / "主面板2_关联公司具体细节.dta", columns=["city_out", "city_in", "gdp_in_2014", "球面距离"])
gdp = m2[["city_in", "gdp_in_2014"]].dropna().drop_duplicates("city_in").set_index("city_in").gdp_in_2014

# 核对：坐标重算的距离与主面板2 球面距离
chk = m2[["city_out", "city_in", "球面距离"]].dropna().drop_duplicates(["city_out", "city_in"])
chk = chk.merge(co.rename(columns={"city": "city_out", "lon": "lo1", "lat": "la1"}), on="city_out")
chk = chk.merge(co.rename(columns={"city": "city_in", "lon": "lo2", "lat": "la2"}), on="city_in")
chk["d"] = hav(chk.lo1, chk.la1, chk.lo2, chk.la2)
print("距离核对：配对数", len(chk), "相关", round(chk[["d", "球面距离"]].corr().iat[0, 1], 4),
      "绝对差中位数(km)", round((chk.d - chk.球面距离).abs().median(), 2),
      "差>20km占比", round(((chk.d - chk.球面距离).abs() > 20).mean(), 4))

# 有方向指数：母公司城市→各城市，2010—2013 年均值
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair", "market_integ_pair"])
sg = sg[sg.city_out.isin(set(first.home_city)) & sg.year.astype(int).between(2010, 2013)]
sg = sg.groupby(["city_out", "city_in"])[["market_seg_pair", "market_integ_pair"]].mean().reset_index()
sg["dest_prov"] = sg.city_in.map(cmap)
n_all = sg.city_in.nunique()
sg["gdp"] = sg.city_in.map(gdp)
sg = sg.merge(co.rename(columns={"city": "city_out", "lon": "lo1", "lat": "la1"}), on="city_out", how="left")
sg = sg.merge(co.rename(columns={"city": "city_in", "lon": "lo2", "lat": "la2"}), on="city_in", how="left")
sg["dist"] = hav(sg.lo1, sg.la1, sg.lo2, sg.la2)
ok = sg.dropna(subset=["dest_prov", "gdp", "dist", "market_seg_pair"])
print("目的城市：有分割指数", n_all, "，有 GDP、坐标和省份可进入权重", ok.city_in.nunique())
miss = sorted(set(sg.city_in) - set(ok.city_in))
print("未进入权重的城市（GDP 或坐标缺失）：", "、".join(miss))
ok = ok.assign(w=ok.gdp / ok.dist)

res = []
for _, f in first.iterrows():
    d = ok[(ok.city_out == f.home_city) & (ok.dest_prov != f.home_prov)]
    full = sg[(sg.city_out == f.home_city) & (sg.dest_prov != f.home_prov)]
    if d.empty:
        res.append({"stkcd": f.stkcd}); continue
    w = d.w / d.w.sum()
    res.append({"stkcd": f.stkcd,
                "seg_gd0": (w * d.market_seg_pair).sum(),
                "integ_gd0": (w * d.market_integ_pair).sum(),
                "n_city_gd": len(d), "n_city_all": len(full),
                "gdp_cov": d.gdp.sum() / gdp.reindex(full.city_in).sum(),   # 进入权重城市的 GDP 占全部外省有 GDP 城市之比
                "w_max": w.max()})
out = pd.DataFrame(res)
out["linteg_gd0"] = np.log1p(out.integ_gd0)
print(out.describe().T[["count", "mean", "std", "min", "max"]].round(4).to_string())
eq = pd.read_stata(OUT / "企业基期市场分割等权.dta")
cc = out.merge(eq, on="stkcd")
print("与 ar63 等权口径相关：\n", cc[["seg_gd0", "seg_eq0", "linteg_gd0", "linteg_eq0"]].corr().round(3).to_string())
out.to_stata(OUT / "企业基期市场分割GDP距离加权.dta", write_index=False, version=118)
print(OUT / "企业基期市场分割GDP距离加权.dta")
