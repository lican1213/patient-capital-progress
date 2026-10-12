"""ar75_build_prov_seg.py — 第三十五轮：省对逐年市场分割（相对价格法，朱凯等 2019），并构造表7、表8变量。

规则见本 exploration README 第三十五轮（运行前写定）。
指数：ΔQ_kijt = ln(P_kit/100) − ln(P_kjt/100)；q_kijt = |ΔQ_kijt| − 该商品该年全部省对 |ΔQ| 的均值；
  seg_ijt = Var_k(q_kijt)（16 类，样本方差）；31 省 465 个省对。
表7：Seg_it = Σ_p W_ip·seg_{home,p,t}，W_ip 为导师权重（目的城市 2014 年 GDP ÷ 母公司城市到该城市球面距离，
  在全部外省城市上归一）按省加总；母公司城市、GDP、坐标与 ar64 相同（首个样本年城市）。另算 t−1，
  以及对照：同一城市权重 × 当期城市对指数（导师做法）。
表8：seg_{母公司首年所在省, 目的省, t} 与 t−1，并入 16 号主面板3。
只读输入：本轮价格面板；data/derived/analysis_ready.dta；data/raw/source_snapshots/affiliate_detail_2014_2024.dta；
  data/raw/mentor_panel_20261008/主面板1、主面板2；data/raw/price_index/ 城市对指数与距离表；CSMAR 上市公司信息；
  deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta
输出（不入版控）：data/derived/prov_seg_20261010/{省对市场分割.csv, 表7_企业年份市场分割.dta, 表8_企业目的省年份市场分割.dta}
运行：python3 explorations/advisor_revision_20261005/scripts/ar75_build_prov_seg.py [价格面板文件名 输出后缀]（项目根目录）
  第三十六轮：... ar75_build_prov_seg.py 居民消费价格8类_省份年份.csv _cpi8
"""
import sys
from itertools import combinations
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/prov_seg_20261010"
MP = ROOT / "data/raw/mentor_panel_20261008"
CY = Path("data/raw/price_index")
DX = CY / "曹越论文初稿的面板和命令代码"
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
PRICE = sys.argv[1] if len(sys.argv) > 1 else "零售价格分类指数_省份年份.csv"
TAG = sys.argv[2] if len(sys.argv) > 2 else ""
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"


def short(p):
    for suf in ["维吾尔自治区", "壮族自治区", "回族自治区", "自治区", "省", "市"]:
        if isinstance(p, str) and p.endswith(suf):
            return p[: -len(suf)]
    return p


# 1. 省对市场分割
pr = pd.read_csv(OUT / PRICE)
print("价格面板：", PRICE)
pr["lp"] = np.log(pr.p / 100)
w = pr.pivot_table(index=["year", "good"], columns="prov", values="lp")
provs = sorted(pr.prov.unique())
rows = []
for a, b in combinations(provs, 2):
    rows.append(pd.DataFrame({"pa": a, "pb": b, "year": w.index.get_level_values(0), "good": w.index.get_level_values(1),
                              "adq": (w[a] - w[b]).abs().to_numpy()}))
dq = pd.concat(rows, ignore_index=True)
dq["q"] = dq.adq - dq.groupby(["year", "good"]).adq.transform("mean")
seg = dq.groupby(["pa", "pb", "year"]).q.var().rename("seg").reset_index()
print("省对数", seg.groupby("year").size().iat[0], "；年份", seg.year.min(), "—", seg.year.max())
print(seg.groupby("year").seg.agg(["mean", "std", "median"]).mul(1e4).round(3).to_string())
segw = seg.pivot_table(index=["pa", "pb"], columns="year", values="seg")
yrs = sorted(seg.year.unique())
print("省对指数相邻年份相关：", {f"{y}-{y + 1}": round(segw[y].corr(segw[y + 1]), 2) for y in yrs[:-1]})
m1013 = segw[[2010, 2011, 2012, 2013]].mean(1)
print("2010—2013 均值与各年相关：", {y: round(m1013.corr(segw[y]), 2) for y in [2010, 2011, 2012, 2013, 2014]})
seg.to_csv(OUT / f"省对市场分割{TAG}.csv", index=False)
sym = pd.concat([seg, seg.rename(columns={"pa": "pb", "pb": "pa"})])          # 无方向，两向同值
sym = sym.rename(columns={"pa": "home_p", "pb": "dest_p"})

# 与购买的城市对数据（合并到省对）比较
cs = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
fullprov = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(fullprov)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
cs["pa"] = cs.city_out.map(cmap).map(short); cs["pb"] = cs.city_in.map(cmap).map(short)
cs = cs.dropna(subset=["pa", "pb", "market_seg_pair"])
cs_all = cs                                                            # 未筛选的城市对，供导师权重取目的城市集合
cs = cs[cs.pa < cs.pb]; cs["year"] = cs.year.astype(int)             # 仅用于省对相关比较；按字符串筛选会漏掉"上海"作目的省
cpp = cs.groupby(["pa", "pb", "year"]).market_seg_pair.mean().rename("cseg").reset_index()
cmp_ = seg.merge(cpp, on=["pa", "pb", "year"])
print("与城市对数据（省对平均）同年相关：", cmp_.groupby("year").apply(lambda g: round(g.seg.corr(g.cseg), 2)).to_dict())

# 2. 企业首个样本年母公司城市与省份
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
first = ar.sort_values(["stkcd", "year"]).groupby("stkcd").first().reset_index()
first["home_p"] = first.home_prov.map(short)
assert first.home_p.dropna().isin(provs).all(), set(first.home_p.dropna()) - set(provs)

# 3. 导师权重（同 ar64）：城市级 GDP/距离，全部外省城市归一，再按省加总
def hav(lon1, lat1, lon2, lat2):
    lon1, lat1, lon2, lat2 = map(np.radians, (lon1, lat1, lon2, lat2))
    a = np.sin((lat2 - lat1) / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin((lon2 - lon1) / 2) ** 2
    return 2 * 6371.0 * np.arcsin(np.sqrt(a))


co = {}
m1 = pd.read_stata(MP / "主面板1_含区位熵_地理IV_创新指标.dta", columns=["city_out", "city_lon", "city_lat"]).dropna()
for r in m1.drop_duplicates("city_out").itertuples():
    co.setdefault(r.city_out, (r.city_lon, r.city_lat))
for r in pd.read_excel(DX / "城市间球面距离计算结果_完整版.xlsx").itertuples():
    if pd.notna(r.longitude_out):
        co.setdefault(r.city_out, (r.longitude_out, r.latitude_out))
    if pd.notna(r.longitude_in):
        co.setdefault(r.city_in, (r.longitude_in, r.latitude_in))
for r in pd.read_excel(DX / "补充城市经纬度.xlsx").itertuples():
    co.setdefault(r.city, (r.lon, r.lat))
co = pd.DataFrame([(k, v[0], v[1]) for k, v in co.items()], columns=["city", "lon", "lat"])
gdp = (pd.read_stata(MP / "主面板2_关联公司具体细节.dta", columns=["city_in", "gdp_in_2014"])
       .dropna().drop_duplicates("city_in").set_index("city_in").gdp_in_2014)
dest = pd.DataFrame({"city_in": sorted(set(cs_all.city_in))})            # 与 ar64 相同的目的城市集合（城市对指数中的城市）
dest["dest_full"] = dest.city_in.map(cmap); dest["dest_p"] = dest.dest_full.map(short); dest["gdp"] = dest.city_in.map(gdp)
dest = dest.merge(co.rename(columns={"city": "city_in", "lon": "lo2", "lat": "la2"}), on="city_in", how="left")
dest = dest.dropna(subset=["dest_p", "gdp", "lo2"])
hc = co.rename(columns={"city": "home_city", "lon": "lo1", "lat": "la1"})
W = []
for f in first.dropna(subset=["home_city"]).itertuples():
    h = hc[hc.home_city == f.home_city]
    if h.empty:
        continue
    d = dest[dest.dest_full != f.home_prov].copy()
    d["w"] = d.gdp / hav(h.lo1.iat[0], h.la1.iat[0], d.lo2, d.la2)
    d = d[np.isfinite(d.w)]
    d["w"] = d.w / d.w.sum()
    W.append(d.assign(stkcd=f.stkcd, home_city=f.home_city, home_p=f.home_p)[["stkcd", "home_city", "home_p", "city_in", "dest_p", "w"]])
W = pd.concat(W)
Wp = W.groupby(["stkcd", "home_p", "dest_p"]).w.sum().reset_index()
print("表7 权重：企业数", W.stkcd.nunique(), "；每家外省城市数中位数", int(W.groupby("stkcd").size().median()),
      "；每家外省省份数中位数", int(Wp.groupby("stkcd").size().median()))

# 4. 表7：企业×年份 Seg（省级当期、t−1；城市对当期对照）
s7 = Wp.merge(sym, on=["home_p", "dest_p"])
s7["ws"] = s7.w * s7.seg
t7 = s7.groupby(["stkcd", "year"]).agg(seg_pv=("ws", "sum"), wsum=("w", "sum")).reset_index()
assert (t7.wsum.sub(1).abs() < 1e-9).all()
t7 = t7[["stkcd", "year", "seg_pv"]]
t7l = t7.assign(year=t7.year + 1).rename(columns={"seg_pv": "seg_pv_l1"})
csy = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                    columns=["city_out", "city_in", "year", "market_seg_pair"])
csy = csy[csy.city_out.isin(set(W.home_city)) & csy.year.astype(int).between(2013, 2024)]
csy["year"] = csy.year.astype(int)
sc = W.merge(csy.rename(columns={"city_out": "home_city"}), on=["home_city", "city_in"])
sc["ws"] = sc.w * sc.market_seg_pair
tc = sc.groupby(["stkcd", "year"]).agg(seg_city=("ws", "sum"), wcov=("w", "sum")).reset_index()
tc["seg_city"] = tc.seg_city / tc.wcov                                   # 当年缺指数的城市按剩余权重重新归一
tab7 = (pd.DataFrame({"stkcd": sorted(W.stkcd.unique())}).merge(pd.DataFrame({"year": range(2014, 2025)}), how="cross")
        .merge(t7, on=["stkcd", "year"], how="left").merge(t7l, on=["stkcd", "year"], how="left")
        .merge(tc[["stkcd", "year", "seg_city"]], on=["stkcd", "year"], how="left"))
for v in ["seg_pv", "seg_pv_l1", "seg_city"]:
    tab7[v] = tab7[v] * 1e4                                               # ×10000，便于读系数
print("表7 变量（×10000）：\n", tab7.groupby("year")[["seg_pv", "seg_pv_l1", "seg_city"]].mean().round(3).to_string())
print("企业层同年相关：", tab7[["seg_pv", "seg_pv_l1", "seg_city"]].corr().round(3).to_string())
tab7.to_stata(OUT / f"表7_企业年份市场分割{TAG}.dta", write_index=False, version=118)

# 5. 表8：母公司首年所在省 × 目的省 × 年
p16 = pd.read_stata(P16, columns=["stkcd", "year", "dest"])
p16["stkcd"] = p16.stkcd.astype(int); p16["year"] = p16.year.astype(int)
p16 = p16.merge(first[["stkcd", "home_p"]], on="stkcd", how="left")
p16["dest_p"] = p16.dest.map(short)
assert p16.dest_p.isin(provs).all()
p16 = p16.merge(sym, on=["home_p", "dest_p", "year"], how="left").rename(columns={"seg": "pseg"})
p16 = p16.merge(sym.assign(year=sym.year + 1).rename(columns={"seg": "pseg_l1"}), on=["home_p", "dest_p", "year"], how="left")
print("表8 非缺失率（按年）：\n", p16.groupby("year")[["pseg", "pseg_l1"]].apply(lambda g: g.notna().mean()).round(3).to_string())
p16[["stkcd", "year", "dest", "pseg", "pseg_l1"]].to_stata(OUT / f"表8_企业目的省年份市场分割{TAG}.dta", write_index=False, version=118)
print("输出：", OUT)
