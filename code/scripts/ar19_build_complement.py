"""ar19_build_complement.py — 第五轮 R2c：新增跨省子公司按“复制/互补/新进入”分类（README“第五轮 R2”）。

新增口径同 ar10：企业×子公司名首次出现，晚于企业首个观测年，子公司所在省≠母公司所在省。
功能标签：rdfix（第三方研发标签且非房地产，同 ar10）、生产（production 或 processing）、销售、市场扩张。
企业上一年在该目的省已有的子公司＝t−1 年明细中出现在该省的全部子公司（不论新旧）。
  新进入：t−1 年在该省没有子公司
  复制：  t−1 年在该省有子公司，且至少一家与新子公司共享一个功能标签
  互补：  t−1 年在该省有子公司，无共享标签，且新子公司至少有一个标签
  未分类：t−1 年在该省有子公司，但新子公司没有任何标签
  研发互补：rdfix 新子公司进入 t−1 年已有生产或销售子公司、但没有 rdfix 子公司的省份
输出（不入版控）：data/derived/advisor_revision_20261005/firm_complement.dta（stkcd year + n_*）
审计：本 exploration 的 output/tables/ar19_build_audit.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar19_build_complement.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
OUT = ROOT / "data/derived/advisor_revision_20261005"
FUN = ["f_rd", "f_prod", "f_sales", "f_mkt"]
aud = {}

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov"})
ar["stkcd"] = ar.stkcd.astype(int)
ar["year"] = ar.year.astype(int)
fy0 = ar.groupby("stkcd").year.min().rename("fy0")
cols = ["stkcd", "sub_name", "province_in", "year", "Corebs", "is_div_rd", "is_div_production",
        "is_div_processing", "is_div_sales", "is_market_expand"]
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=cols)
af["stkcd"] = af.stkcd.astype(int)
af["year"] = af.year.astype(int)
af = af.merge(ar, on=["stkcd", "year"], how="inner").merge(fy0, on="stkcd")
re_ = af.sub_name.fillna("").str.contains("房地产|置业|物业|地产") | af.Corebs.fillna("").str.contains("房地产")
af["f_rd"] = ((af.is_div_rd == 1) & ~re_).astype(int)
af["f_prod"] = ((af.is_div_production.fillna(0) + af.is_div_processing.fillna(0)) > 0).astype(int)
af["f_sales"] = (af.is_div_sales == 1).astype(int)
af["f_mkt"] = (af.is_market_expand == 1).astype(int)
af["first"] = af.groupby(["stkcd", "sub_name"]).year.transform("min")

# 上一年在各省已有子公司的功能并集（t−1 年明细），按 year+1 对齐到 t
prev = af.groupby(["stkcd", "year", "province_in"])[FUN].max().reset_index()
prev["year"] = prev.year + 1
prev = prev.rename(columns={f: "p" + f for f in FUN})
prev["has_prev"] = 1

nw = af[(af.province_in != af.home_prov) & (af.year == af["first"]) & (af.year > af.fy0)].copy()
# 同一企业同名子公司首年在明细中重复出现时只算一次
nw = nw.drop_duplicates(["stkcd", "sub_name"])
nw = nw.merge(prev, on=["stkcd", "year", "province_in"], how="left")
nw["has_prev"] = nw.has_prev.fillna(0).astype(int)
for f in FUN:
    nw["p" + f] = nw["p" + f].fillna(0)
share = sum(((nw[f] == 1) & (nw["p" + f] == 1)).astype(int) for f in FUN) > 0
lab = nw[FUN].sum(axis=1) > 0
nw["c_new"] = (nw.has_prev == 0).astype(int)
nw["c_rep"] = ((nw.has_prev == 1) & share).astype(int)
nw["c_comp"] = ((nw.has_prev == 1) & ~share & lab).astype(int)
nw["c_unl"] = ((nw.has_prev == 1) & ~lab).astype(int)
nw["c_rdcomp"] = ((nw.f_rd == 1) & (nw.pf_rd == 0) & ((nw.pf_prod == 1) | (nw.pf_sales == 1))).astype(int)
assert (nw[["c_new", "c_rep", "c_comp", "c_unl"]].sum(axis=1) == 1).all()
aud["new_cross"] = len(nw)
for c in ["c_new", "c_rep", "c_comp", "c_unl", "c_rdcomp"]:
    aud[f"n_{c}"] = int(nw[c].sum())
# 首个可比年：t−1 明细必须存在（样本首年之后），与 ar10 一致
firm = nw.groupby(["stkcd", "year"])[["c_new", "c_rep", "c_comp", "c_unl", "c_rdcomp"]].sum()
firm.columns = ["n_new", "n_rep", "n_comp", "n_unl", "n_rdcomp"]
firm = ar[["stkcd", "year"]].merge(firm.reset_index(), on=["stkcd", "year"], how="left").merge(fy0.reset_index(), on="stkcd")
for v in ["n_new", "n_rep", "n_comp", "n_unl", "n_rdcomp"]:
    firm[v] = firm[v].fillna(0)
    firm.loc[firm.year <= firm.fy0, v] = float("nan")
# 核对：四类之和等于 ar10 的毛新增
rd = pd.read_stata(OUT / "firm_rdfix.dta", columns=["stkcd", "year", "new_x_all"])
chk = firm.merge(rd, on=["stkcd", "year"])
tot = chk[["n_new", "n_rep", "n_comp", "n_unl"]].sum(axis=1, min_count=1)
aud["max_absdiff_vs_ar10_new_x_all"] = float((tot.fillna(-1) - chk.new_x_all.fillna(-1)).abs().max())
# R3：毛新增注册资本（含省内新增；非人民币币种剔除；只计注册资本非缺失）
ac = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                   columns=["stkcd", "sub_name", "province_in", "year", "关联公司注册资本", "Curtype"])
ac["stkcd"] = ac.stkcd.astype(int)
ac["year"] = ac.year.astype(int)
ac = ac.merge(ar, on=["stkcd", "year"], how="inner").merge(fy0, on="stkcd")
ac["first"] = ac.groupby(["stkcd", "sub_name"]).year.transform("min")
na = ac[(ac.year == ac["first"]) & (ac.year > ac.fy0)].drop_duplicates(["stkcd", "sub_name"])
na = na[~na.Curtype.isin(["USD", "HKD", "JPY", "EUR"]) & na["关联公司注册资本"].notna()].copy()
na["cap_x"] = na["关联公司注册资本"].where(na.province_in != na.home_prov, 0)
aud["new_all_with_cap"] = len(na)
aud["new_cross_with_cap"] = int((na.province_in != na.home_prov).sum())
cp = na.groupby(["stkcd", "year"]).agg(gcap_all=("关联公司注册资本", "sum"), gcap_x=("cap_x", "sum")).reset_index()
cp["capsh_x"] = cp.gcap_x / cp.gcap_all.where(cp.gcap_all > 0)
firm = firm.merge(cp[["stkcd", "year", "capsh_x"]], on=["stkcd", "year"], how="left")
aud["capsh_x_nonmissing"] = int(firm.capsh_x.notna().sum())
aud["capsh_x_min"] = float(firm.capsh_x.min())
aud["capsh_x_max"] = float(firm.capsh_x.max())
firm.drop(columns="fy0").to_stata(OUT / "firm_complement.dta", write_index=False, version=118)
pd.Series(aud).to_csv(EXP / "output/tables/ar19_build_audit.csv", header=["value"])
print(pd.Series(aud).to_string())
