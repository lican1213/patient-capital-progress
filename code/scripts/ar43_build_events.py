"""ar43_build_events.py — 第十三轮：按 D-135 审计修正新增事件与功能分类（替代 ar10/ar19 中受影响的输出，原件保留）。

修正三处（审计报告 explorations/skeleton_source_audit_20261007/review/骨架全链审计_20261007.md 第 2 节 C）：
  1. 首次披露在完整子公司明细中认定（同 um01 双边 entry），不再先限制到母公司面板年份；
  2. 企业层功能分类要求上一年明细可观察（完整明细中企业 t−1 年有记录），否则该企业—年份记缺失，不判为“进入新省份”；
  3. 上一年在该省已有子公司但全部没有功能标签时，新子公司记为“旧功能未知”，不计入功能互补。
其余定义不变：跨省＝子公司所在省≠母公司所在省（analysis_ready 当年）；企业首个面板年无法区分新增与存量，记缺失；
  研发型＝第三方研发标签且非房地产（同 ar10）；生产＝production 或 processing；研发互补同 ar19。
企业—年份（firm_events_v2.dta）：n_new n_rep n_comp n_unkprev n_unl n_rdcomp new_x_rdfix new_ECW home_east new_x_all prior_obs
双边（dyad_rdfix_v2.dta：stkcd year dest_id）：new_rdfix_any，样本规则同双边 entry（首个面板年缺失，不要求上一年明细）
输出到 data/derived/advisor_revision_20261005/（不入版控）；审计 本 exploration 的 output/tables/ar43_build_audit.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar43_build_events.py（项目根目录）
"""
from pathlib import Path

import numpy as np
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
cols = ["stkcd", "sub_name", "province_in", "year", "Corebs", "is_div_rd", "is_div_production", "is_div_processing",
        "is_div_sales", "is_market_expand", "city_out东中西部", "city_in东中西部"]
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta", columns=cols)
af["stkcd"] = af.stkcd.astype(int)
af["year"] = af.year.astype(int)
af = af[af.stkcd.isin(fy0.index)].copy()
assert not af.duplicated(["stkcd", "year", "sub_name"]).any()
re_ = af.sub_name.fillna("").str.contains("房地产|置业|物业|地产") | af.Corebs.fillna("").str.contains("房地产")
af["f_rd"] = ((af.is_div_rd == 1) & ~re_).astype(int)
af["f_prod"] = ((af.is_div_production.fillna(0) + af.is_div_processing.fillna(0)) > 0).astype(int)
af["f_sales"] = (af.is_div_sales == 1).astype(int)
af["f_mkt"] = (af.is_market_expand == 1).astype(int)
# 1. 首次披露：完整明细
af["first"] = af.groupby(["stkcd", "sub_name"]).year.transform("min")
# 2. 上一年明细可观察
obs = af[["stkcd", "year"]].drop_duplicates()
pobs = obs.assign(year=obs.year + 1, prior_obs=1)
# 上一年在各省已有子公司的功能并集（完整明细 t−1 年）
prev = af.groupby(["stkcd", "year", "province_in"])[FUN].max().reset_index()
prev["year"] = prev.year + 1
prev = prev.rename(columns={f: "p" + f for f in FUN})
prev["has_prev"] = 1

ev = af.merge(ar, on=["stkcd", "year"], how="inner").merge(fy0, on="stkcd")
nw = ev[(ev.province_in != ev.home_prov) & (ev.year == ev["first"]) & (ev.year > ev.fy0)].copy()
nw = nw.merge(pobs, on=["stkcd", "year"], how="left").merge(prev, on=["stkcd", "year", "province_in"], how="left")
nw["prior_obs"] = nw.prior_obs.fillna(0).astype(int)
nw["has_prev"] = nw.has_prev.fillna(0).astype(int)
for f in FUN:
    nw["p" + f] = nw["p" + f].fillna(0)
share = sum(((nw[f] == 1) & (nw["p" + f] == 1)).astype(int) for f in FUN) > 0
lab = nw[FUN].sum(axis=1) > 0
plab = nw[["p" + f for f in FUN]].sum(axis=1) > 0
po, hp = nw.prior_obs == 1, nw.has_prev == 1
nw["c_unobs"] = (~po).astype(int)
nw["c_new"] = (po & ~hp).astype(int)
nw["c_rep"] = (po & hp & share).astype(int)
nw["c_comp"] = (po & hp & ~share & lab & plab).astype(int)
nw["c_unkprev"] = (po & hp & ~share & lab & ~plab).astype(int)
nw["c_unl"] = (po & hp & ~lab).astype(int)
nw["c_rdcomp"] = (po & (nw.f_rd == 1) & (nw.pf_rd == 0) & ((nw.pf_prod == 1) | (nw.pf_sales == 1))).astype(int)
nw["c_rdfix"] = nw.f_rd
nw["c_ECW"] = ((nw["city_out东中西部"] == "东部") & (nw["city_in东中西部"] == "中西部")).astype(int)
nw["c_all"] = 1
assert (nw[["c_unobs", "c_new", "c_rep", "c_comp", "c_unkprev", "c_unl"]].sum(axis=1) == 1).all()
aud["new_cross"] = len(nw)
for c in ["c_unobs", "c_new", "c_rep", "c_comp", "c_unkprev", "c_unl", "c_rdcomp", "c_rdfix", "c_ECW"]:
    aud[f"n_{c}"] = int(nw[c].sum())

# 与旧构造（ar19：先限制到面板再求首次出现）对照
old_first = ev.groupby(["stkcd", "sub_name"]).year.transform("min")
old = ev[(ev.province_in != ev.home_prov) & (ev.year == old_first) & (ev.year > ev.fy0)]
aud["old_new_cross"] = len(old)
aud["old_events_dropped_earlier_raw_disclosure"] = int((old.year > old["first"]).sum())

# 企业—年份
C = ["c_new", "c_rep", "c_comp", "c_unkprev", "c_unl", "c_rdcomp", "c_rdfix", "c_ECW", "c_all"]
V = ["n_new", "n_rep", "n_comp", "n_unkprev", "n_unl", "n_rdcomp", "new_x_rdfix", "new_ECW", "new_x_all"]
firm = nw.groupby(["stkcd", "year"])[C].sum()
firm.columns = V
firm = ar[["stkcd", "year"]].merge(firm.reset_index(), on=["stkcd", "year"], how="left").merge(fy0.reset_index(), on="stkcd")
firm = firm.merge(pobs, on=["stkcd", "year"], how="left")
firm["prior_obs"] = firm.prior_obs.fillna(0).astype(int)
for v in V:
    firm[v] = firm[v].fillna(0)
    firm.loc[(firm.year <= firm.fy0) | (firm.prior_obs == 0), v] = np.nan
reg = ev.groupby(["stkcd", "year"])["city_out东中西部"].agg(lambda s: s.mode().iat[0] if s.notna().any() else np.nan)
firm = firm.merge((reg == "东部").astype(float).where(reg.notna()).rename("home_east").reset_index(), on=["stkcd", "year"], how="left")
aud["firm_rows"] = len(firm)
aud["firm_missing_prior_obs_after_first_year"] = int(((firm.year > firm.fy0) & (firm.prior_obs == 0)).sum())
aud["firm_nonmissing_n_new"] = int(firm.n_new.notna().sum())
firm.drop(columns="fy0").to_stata(OUT / "firm_events_v2.dta", write_index=False, version=118)

# 双边研发型新增（dest_id 编码同 ar10/um01：完整明细省份名排序）
provs = sorted(pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                             columns=["province_in"]).province_in.dropna().unique())
da = pd.DataFrame({"dest": provs})
da["dest_id"] = da.dest.astype("category").cat.codes + 1
d = nw[nw.f_rd == 1].groupby(["stkcd", "year", "province_in"]).size().rename("n").reset_index()
d = d.merge(da, left_on="province_in", right_on="dest")[["stkcd", "year", "dest_id"]]
d["new_rdfix_any"] = 1
aud["dyad_rdfix_cells"] = len(d)
d.to_stata(OUT / "dyad_rdfix_v2.dta", write_index=False, version=118)
pd.Series(aud).to_csv(EXP / "output/tables/ar43_build_audit.csv", header=["value"])
print(pd.Series(aud).to_string())
