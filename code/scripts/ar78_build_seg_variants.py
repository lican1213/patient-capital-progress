"""ar78_build_seg_variants.py — 第三十八轮：市场分割四种口径（r3、r3l、nb、nbr3）× 两种价格数据（16 类、CPI 8 类）。

规则见本 exploration README 第三十八轮（运行前写定）。
输入：data/derived/prov_seg_20261010/省对市场分割.csv、省对市场分割_cpi8.csv（第三十五、三十六轮）；
  导师权重、母公司首年城市与 ar75_build_prov_seg.py 第 2、3 节相同（含第三十七轮修正：目的城市集合不筛选）。
输出（不入版控）：data/derived/prov_seg_20261010/表7_变体_ar78.dta（stkcd year，变量 <口径>_<数据>，×1e4）、
  表8_变体_ar78.dta（stkcd year dest，同名变量）
运行：python3 explorations/advisor_revision_20261005/scripts/ar78_build_seg_variants.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/prov_seg_20261010"
MP = ROOT / "data/raw/mentor_panel_20261008"
CY = Path("data/raw/price_index")
DX = CY / "曹越论文初稿的面板和命令代码"
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
SRC = {"r16": "省对市场分割.csv", "c8": "省对市场分割_cpi8.csv"}
# 相邻省份（陆地接壤；海南按惯例与广东相邻）
ADJ = {"北京": "天津 河北", "天津": "北京 河北", "河北": "北京 天津 山西 内蒙古 辽宁 山东 河南",
       "山西": "河北 内蒙古 陕西 河南", "内蒙古": "黑龙江 吉林 辽宁 河北 山西 陕西 宁夏 甘肃",
       "辽宁": "吉林 内蒙古 河北", "吉林": "黑龙江 辽宁 内蒙古", "黑龙江": "吉林 内蒙古", "上海": "江苏 浙江",
       "江苏": "上海 浙江 安徽 山东", "浙江": "上海 江苏 安徽 江西 福建", "安徽": "江苏 浙江 江西 湖北 河南 山东",
       "福建": "浙江 江西 广东", "江西": "浙江 安徽 湖北 湖南 广东 福建", "山东": "河北 河南 安徽 江苏",
       "河南": "河北 山西 陕西 湖北 安徽 山东", "湖北": "河南 安徽 江西 湖南 重庆 陕西",
       "湖南": "湖北 江西 广东 广西 贵州 重庆", "广东": "福建 江西 湖南 广西 海南", "广西": "广东 湖南 贵州 云南",
       "海南": "广东", "重庆": "湖北 湖南 贵州 四川 陕西", "四川": "重庆 贵州 云南 西藏 青海 甘肃 陕西",
       "贵州": "四川 重庆 湖南 广西 云南", "云南": "四川 贵州 广西 西藏", "西藏": "新疆 青海 四川 云南",
       "陕西": "山西 河南 湖北 重庆 四川 甘肃 宁夏 内蒙古", "甘肃": "陕西 四川 青海 新疆 内蒙古 宁夏",
       "青海": "甘肃 新疆 西藏 四川", "宁夏": "内蒙古 陕西 甘肃", "新疆": "甘肃 青海 西藏"}
ADJ = {k: v.split() for k, v in ADJ.items()}
assert len(ADJ) == 31 and all(a in ADJ[b] for a in ADJ for b in ADJ[a]), "相邻表须对称"


def short(p):
    for suf in ["维吾尔自治区", "壮族自治区", "回族自治区", "自治区", "省", "市"]:
        if isinstance(p, str) and p.endswith(suf):
            return p[: -len(suf)]
    return p


def roll(df, keys, v, lag):
    """三年平均：lag=0 取 t−2..t，lag=1 取 t−3..t−1；三年都有才算。"""
    w = df.pivot_table(index=keys, columns="year", values=v)
    yrs = list(range(w.columns.min(), w.columns.max() + 2))
    w = w.reindex(columns=yrs)
    r = w.T.rolling(3, min_periods=3).mean().T
    if lag:
        r = r.shift(1, axis=1)
    return r.stack().dropna().rename(v).reset_index()                    # 新版 pandas stack 保留缺失，须显式去掉


# 1. 各口径：省对（无方向，两向同值）与省级（相邻法）
pair, prov = {}, {}
for s, f in SRC.items():
    seg = pd.read_csv(OUT / f)
    sym = pd.concat([seg, seg.rename(columns={"pa": "pb", "pb": "pa"})]).rename(columns={"pa": "hp", "pb": "dp"})
    pair[f"r3_{s}"] = roll(sym, ["hp", "dp"], "seg", 0)
    pair[f"r3l_{s}"] = roll(sym, ["hp", "dp"], "seg", 1)
    nb = sym[sym.apply(lambda r: r.dp in ADJ[r.hp], axis=1)].groupby(["hp", "year"]).seg.mean().reset_index()
    nb = nb.rename(columns={"hp": "dp"})
    assert nb.groupby("year").size().eq(31).all()
    prov[f"nb_{s}"] = nb
    prov[f"nbr3_{s}"] = roll(nb, ["dp"], "seg", 0)
    print(s, "年份", seg.year.min(), "—", seg.year.max(), "；相邻法省级指数相邻年份相关：",
          nb.pivot(index="dp", columns="year", values="seg").corr().pipe(lambda c: np.diag(c, 1)).round(2).tolist())

# 2. 母公司首年城市与导师权重（同 ar75 第 2、3 节，含第三十七轮修正）
cs = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta", columns=["city_out", "city_in"])
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=["city_in", "province_in"])
fullprov = sorted(af.province_in.dropna().unique())
stk = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([stk, af.rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(fullprov)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
first = ar.sort_values(["stkcd", "year"]).groupby("stkcd").first().reset_index()
first["home_p"] = first.home_prov.map(short)


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
dest = pd.DataFrame({"city_in": sorted(set(cs.city_in))})
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
    W.append(d.assign(stkcd=f.stkcd, home_p=f.home_p)[["stkcd", "home_p", "dest_p", "w"]])
Wp = pd.concat(W).groupby(["stkcd", "home_p", "dest_p"]).w.sum().reset_index()
print("表7 权重：企业数", Wp.stkcd.nunique(), "；每家外省省份数中位数", int(Wp.groupby("stkcd").size().median()))
assert int(Wp.groupby("stkcd").size().median()) == 30

# 3. 表7：Σ_p W_ip·Z（权重和须为 1，否则该企业年缺失）
tab7 = pd.DataFrame({"stkcd": sorted(Wp.stkcd.unique())}).merge(pd.DataFrame({"year": range(2014, 2025)}), how="cross")
for k, z in {**pair, **prov}.items():
    if k in pair:
        m = Wp.merge(z, left_on=["home_p", "dest_p"], right_on=["hp", "dp"])
    else:
        m = Wp.merge(z, left_on="dest_p", right_on="dp")
    m = m.dropna(subset=["seg"])                                         # 缺失不能按 0 加总
    m["ws"] = m.w * m.seg
    t = m.groupby(["stkcd", "year"]).agg(v=("ws", "sum"), ws=("w", "sum")).reset_index()
    t = t[(t.ws - 1).abs() < 1e-9]
    tab7 = tab7.merge(t[["stkcd", "year", "v"]].rename(columns={"v": k}), on=["stkcd", "year"], how="left")
    tab7[k] = tab7[k] * 1e4
print("表7 各口径非缺失年份：\n", tab7.groupby("year").count().drop(columns="stkcd").to_string())
tab7.to_stata(OUT / "表7_变体_ar78.dta", write_index=False, version=118)

# 4. 表8：省对口径按（首年省, 目的省），相邻法按目的省
p16 = pd.read_stata(P16, columns=["stkcd", "year", "dest"])
p16["stkcd"] = p16.stkcd.astype(int); p16["year"] = p16.year.astype(int)
p16 = p16.merge(first[["stkcd", "home_p"]], on="stkcd", how="left")
p16["dest_p"] = p16.dest.map(short)
for k, z in pair.items():
    p16 = p16.merge(z.rename(columns={"hp": "home_p", "dp": "dest_p", "seg": k}), on=["home_p", "dest_p", "year"], how="left")
for k, z in prov.items():
    p16 = p16.merge(z.rename(columns={"dp": "dest_p", "seg": k}), on=["dest_p", "year"], how="left")
keep = ["stkcd", "year", "dest"] + list(pair) + list(prov)
print("表8 各口径非缺失率（按年）：\n", p16.groupby("year")[keep[3:]].apply(lambda g: g.notna().mean()).round(3).to_string())
p16[keep].to_stata(OUT / "表8_变体_ar78.dta", write_index=False, version=118)
print("输出：", OUT)
