"""ar05_build_round3.py — 第三轮预登记（review/round3_prereg.md）所需的企业—年份与双边变量。

企业—年份（firm_r3.dta）：
  SegR / SegR_mean / SegI / SegI_new / SegR_sales / ncov（文献口径市场分割，朱凯等 2019）
  mentor 字段：net_x（新增跨省子公司数量，净变化）、net_xcap（新增跨省子公司注册资本，净变化）、net_sp（新增同省异市）
  自建毛新增：new_x、new_x_rd、new_x_prod、new_x_sales、new_x_mkt、new_x_xind；存量 stk_x_rd
  流向：new_EE、new_ECW、new_CWE、new_CWCW；母公司区域 home_east
  基期研发强度 rd0（研发投入占营业收入比例，企业首年）
双边（dyad_r3.dta：stkcd year dest_id）：new_rd_any（当年该省新增研发型子公司）
目的省属性（dest_attr.dta：dest_id）：east、mkt0（市场化总指数 2010—13 均值）、rdres0（上市公司发明专利申请量省均值对数，2010—13）
输出到 data/derived/advisor_revision_20261005/（不入版控）；审计 output/tables/ar05_build_audit.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar05_build_round3.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
OUT = ROOT / "data/derived/advisor_revision_20261005"
CY = Path("data/raw/price_index")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
aud = {}

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "city_out", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov", "city_out": "home_city"})
ar["stkcd"] = ar.stkcd.astype(int); ar["year"] = ar.year.astype(int)
fy0 = ar.groupby("stkcd").year.min().rename("fy0")

cols = ["stkcd", "sub_name", "province_in", "city_in", "year", "city_out东中西部", "city_in东中西部",
        "新增跨省子公司数量", "新增跨省子公司注册资本", "新增同省异市子公司数量",
        "is_div_rd", "is_div_production", "is_div_processing", "is_div_sales", "is_market_expand", "is_cross_industry"]
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=cols)
af["stkcd"] = af.stkcd.astype(int); af["year"] = af.year.astype(int)
af = af.merge(ar[["stkcd", "year", "home_prov", "home_city"]], on=["stkcd", "year"], how="inner").merge(fy0, on="stkcd")
af["cross"] = (af.province_in != af.home_prov).astype(int)
af["first"] = af.groupby(["stkcd", "sub_name"]).year.transform("min")
af["new"] = ((af.year == af["first"]) & (af.year > af.fy0)).astype(int)
af["prod"] = ((af.is_div_production + af.is_div_processing) > 0).astype(int)
provs = sorted(af.province_in.dropna().unique())

# 1. 导师现成字段（企业—年份内唯一）
mf = af.groupby(["stkcd", "year"])[["新增跨省子公司数量", "新增跨省子公司注册资本", "新增同省异市子公司数量"]].first()
mf.columns = ["net_x", "net_xcap", "net_sp"]
aud["net_x_negative_share"] = float((mf.net_x < 0).mean())

# 2. 自建毛新增与类型、流向
cr = af[af.cross == 1].copy()
nw = cr[cr.new == 1]
g = lambda d, name: d.groupby(["stkcd", "year"]).size().rename(name)
parts = [g(nw, "new_x"), g(nw[nw.is_div_rd == 1], "new_x_rd"), g(nw[nw["prod"] == 1], "new_x_prod"),
         g(nw[nw.is_div_sales == 1], "new_x_sales"), g(nw[nw.is_market_expand == 1], "new_x_mkt"),
         g(nw[nw.is_cross_industry == 1], "new_x_xind"), g(cr[cr.is_div_rd == 1], "stk_x_rd")]
for o, d, nm in [("东部", "东部", "new_EE"), ("东部", "中西部", "new_ECW"), ("中西部", "东部", "new_CWE"), ("中西部", "中西部", "new_CWCW")]:
    parts.append(g(nw[(nw["city_out东中西部"] == o) & (nw["city_in东中西部"] == d)], nm))
reg = af.groupby(["stkcd", "year"])["city_out东中西部"].agg(lambda s: s.mode().iat[0] if s.notna().any() else np.nan)
home_east = (reg == "东部").astype(float).where(reg.notna()).rename("home_east")
firm = ar[["stkcd", "year"]].set_index(["stkcd", "year"]).join(mf).join(pd.concat(parts, axis=1)).join(home_east)
cnt = [c for c in firm.columns if c.startswith(("new_", "stk_"))]
firm[cnt] = firm[cnt].fillna(0)
firm = firm.reset_index().merge(fy0, on="stkcd")
for c in [c for c in cnt if c.startswith("new_")]:
    firm.loc[firm.year <= firm.fy0, c] = np.nan     # 企业首年无法区分新增与存量
aud["corr_netx_newx"] = float(firm[["net_x", "new_x"]].corr().iat[0, 1])

# 3. 文献口径分割：母公司城市→目的省（省内城市对中位数/均值），当年值
cmap_src = pd.read_stata(STK, columns=["CITY", "PROVINCE"]).rename(columns={"CITY": "city", "PROVINCE": "prov"})
cmap = pd.concat([cmap_src, af[["city_in", "province_in"]].rename(columns={"city_in": "city", "province_in": "prov"})]).dropna()
cmap = cmap[cmap.prov.isin(provs)].groupby("city").prov.agg(lambda s: s.mode().iat[0])
sg = pd.read_stata(CY / "城市对市场分割和市场一体化_基于价格指数_有方向_2001-2024.dta",
                   columns=["city_out", "city_in", "year", "market_seg_pair"])
sg = sg[sg.city_out.isin(set(ar.home_city)) & sg.year.between(2014, 2024)].dropna(subset=["market_seg_pair"])
sg["year"] = sg.year.astype(int)
sg["dest"] = sg.city_in.map(cmap)
sg = sg.dropna(subset=["dest"])
pm = sg.groupby(["city_out", "dest", "year"]).market_seg_pair.agg(["median", "mean"]).reset_index()
pm.columns = ["home_city", "dest", "year", "seg_md", "seg_mn"]
base = ar[["stkcd", "year", "home_city", "home_prov"]].merge(pd.DataFrame({"dest": provs}), how="cross")
base = base[base.dest != base.home_prov].merge(pm, on=["home_city", "dest", "year"], how="left")
cov = cr.groupby(["stkcd", "year", "province_in"]).size().rename("ncs").reset_index().rename(columns={"province_in": "dest"})
covn = nw.groupby(["stkcd", "year", "province_in"]).size().rename("nnew").reset_index().rename(columns={"province_in": "dest"})
covs = cr[(cr.is_div_sales == 1) | (cr.is_market_expand == 1)].groupby(["stkcd", "year", "province_in"]).size().rename("nsl").reset_index().rename(columns={"province_in": "dest"})
base = base.merge(cov, on=["stkcd", "year", "dest"], how="left").merge(covn, on=["stkcd", "year", "dest"], how="left").merge(covs, on=["stkcd", "year", "dest"], how="left")
for c in ["ncs", "nnew", "nsl"]:
    base[c] = (base[c].fillna(0) > 0).astype(int)


def segstats(d):
    out = {}
    for s, tag in [("seg_md", ""), ("seg_mn", "_mean")]:
        tot = d[s].sum(min_count=1)
        out["SegR" + tag] = d.loc[d.ncs == 1, s].sum() / tot if tot and tot > 0 else np.nan
    allm = d.seg_md.mean()
    out["SegI"] = d.loc[d.ncs == 1, "seg_md"].mean() / allm if d.ncs.sum() > 0 and allm > 0 else np.nan
    out["SegI_new"] = d.loc[d.nnew == 1, "seg_md"].mean() / allm if d.nnew.sum() > 0 and allm > 0 else np.nan
    tot = d.seg_md.sum(min_count=1)
    out["SegR_sales"] = d.loc[d.nsl == 1, "seg_md"].sum() / tot if tot and tot > 0 else np.nan
    out["ncov"] = int(d.ncs.sum())
    out["nseg"] = int(d.seg_md.notna().sum())
    return pd.Series(out)


ss = base.groupby(["stkcd", "year"]).apply(segstats).reset_index()
ss.loc[ss.nseg < 20, ["SegR", "SegR_mean", "SegI", "SegI_new", "SegR_sales"]] = np.nan
firm = firm.merge(ss, on=["stkcd", "year"], how="left")
aud["SegR_nonmiss"] = int(firm.SegR.notna().sum()); aud["SegI_nonmiss"] = int(firm.SegI.notna().sum())
aud["corr_SegR_median_mean"] = float(firm[["SegR", "SegR_mean"]].corr().iat[0, 1])
aud["corr_SegR_ncov"] = float(firm[["SegR", "ncov"]].corr().iat[0, 1])

# 4. 基期研发强度
rd = pd.read_stata(CY / "上市公司-研发投入与专利数据（2000-2024年）.dta",
                   columns=["stkcd", "year", "研发投入占营业收入比例", "企业发明专利申请量", "省份"])
rd["stkcd"] = pd.to_numeric(rd.stkcd, errors="coerce"); rd = rd.dropna(subset=["stkcd"])
rd["stkcd"] = rd.stkcd.astype(int); rd["year"] = rd.year.astype(int)
r0 = firm[["stkcd"]].drop_duplicates().merge(fy0.reset_index(), on="stkcd").merge(
    rd[["stkcd", "year", "研发投入占营业收入比例"]].rename(columns={"year": "fy0"}), on=["stkcd", "fy0"], how="left")
firm = firm.merge(r0[["stkcd", "研发投入占营业收入比例"]].rename(columns={"研发投入占营业收入比例": "rd0"}), on="stkcd", how="left")
aud["rd0_nonmiss_firms"] = int(r0["研发投入占营业收入比例"].notna().sum())
firm.drop(columns=["fy0"]).to_stata(OUT / "firm_r3.dta", write_index=False, version=118)

# 5. 目的省属性（dest_id 与 um01 同一编码：省份名排序）
da = pd.DataFrame({"dest": provs}); da["dest_id"] = da.dest.astype("category").cat.codes + 1
reg_in = af.groupby("province_in")["city_in东中西部"].agg(lambda s: s.mode().iat[0])
da["east"] = (da.dest.map(reg_in) == "东部").astype(int)
mk = pd.read_stata(CY / "1997-2024年市场化指数和各分项指数.dta"); mk["year"] = mk.year.astype(int)
da["mkt0"] = da.dest.map(mk[mk.year.between(2010, 2013)].groupby("province_in").market.mean())
rdp = rd[rd.year.between(2010, 2013)].groupby(["省份", "year"])["企业发明专利申请量"].sum().groupby(level=0).mean()
da["rdres0"] = np.log1p(da.dest.map(rdp))
aud["dest_attr_missing"] = int(da[["mkt0", "rdres0"]].isna().any(axis=1).sum())
aud["dest_attr_corr_east_rdres"] = float(da[["east", "rdres0"]].corr().iat[0, 1])
aud["dest_attr_corr_mkt_rdres"] = float(da[["mkt0", "rdres0"]].corr().iat[0, 1])
da[["dest_id", "east", "mkt0", "rdres0"]].to_stata(OUT / "dest_attr.dta", write_index=False, version=118)

# 6. 双边：当年该省是否新增研发型子公司
dr = nw[nw.is_div_rd == 1].groupby(["stkcd", "year", "province_in"]).size().rename("n").reset_index()
dr = dr.merge(da[["dest", "dest_id"]], left_on="province_in", right_on="dest")
dr["new_rd_any"] = 1
dr[["stkcd", "year", "dest_id", "new_rd_any"]].to_stata(OUT / "dyad_r3.dta", write_index=False, version=118)

pd.Series(aud).to_csv(EXP / "output/tables/ar05_build_audit.csv", header=["value"])
print(pd.Series(aud).to_string())
print(da.to_string(index=False))
