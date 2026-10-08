"""ar10_build_rdfix.py — 第四轮 M7e：修正研发标签（README“M7e”）。

新增口径与第三轮 ar05 完全一致：企业×子公司名首次出现，且晚于企业在 analysis_ready 的首个观测年；跨省＝子公司所在省≠母公司所在省（analysis_ready）。
企业—年份（firm_rdfix.dta）：new_x_rdfix、new_x_rdtxt、new_x_all（毛新增，核对＝ar05 new_x）
双边（dyad_rdfix.dta：stkcd year dest_id）：new_rdfix_any、new_rdtxt_any
审计：本 exploration 的 output/tables/ar10_build_audit.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar10_build_rdfix.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
OUT = ROOT / "data/derived/advisor_revision_20261005"
aud = {}

ar = pd.read_stata(ROOT / "data/derived/analysis_ready.dta", columns=["stkcd", "year", "母公司所在省份"])
ar = ar.rename(columns={"母公司所在省份": "home_prov"})
ar["stkcd"] = ar.stkcd.astype(int)
ar["year"] = ar.year.astype(int)
fy0 = ar.groupby("stkcd").year.min().rename("fy0")
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                   columns=["stkcd", "sub_name", "province_in", "year", "Corebs", "is_div_rd"])
af["stkcd"] = af.stkcd.astype(int)
af["year"] = af.year.astype(int)
af = af.merge(ar, on=["stkcd", "year"], how="inner").merge(fy0, on="stkcd")
af["first"] = af.groupby(["stkcd", "sub_name"]).year.transform("min")
nw = af[(af.province_in != af.home_prov) & (af.year == af["first"]) & (af.year > af.fy0)].copy()
txt = nw.Corebs.fillna("")
re_ = nw.sub_name.fillna("").str.contains("房地产|置业|物业|地产") | txt.str.contains("房地产")
nw["rdfix"] = ((nw.is_div_rd == 1) & ~re_).astype(int)
nw["rdtxt"] = txt.str.contains("研发|研究|技术开发|试验|检测").astype(int)
aud["new_cross"] = len(nw)
aud["n_rd_orig"] = int(nw.is_div_rd.sum())
aud["n_rdfix"] = int(nw.rdfix.sum())
aud["n_rdtxt"] = int(nw.rdtxt.sum())
aud["overlap_fix_txt"] = int(((nw.rdfix == 1) & (nw.rdtxt == 1)).sum())

g = lambda d, name: d.groupby(["stkcd", "year"]).size().rename(name)
firm = pd.concat([g(nw, "new_x_all"), g(nw[nw.rdfix == 1], "new_x_rdfix"), g(nw[nw.rdtxt == 1], "new_x_rdtxt")], axis=1)
firm = ar[["stkcd", "year"]].merge(firm.reset_index(), on=["stkcd", "year"], how="left")
firm = firm.merge(fy0.reset_index(), on="stkcd")
for v in ["new_x_all", "new_x_rdfix", "new_x_rdtxt"]:
    firm[v] = firm[v].fillna(0)
    firm.loc[firm.year <= firm.fy0, v] = float("nan")
# 核对：毛新增应与第三轮 new_x 一致
r3 = pd.read_stata(OUT / "firm_r3.dta", columns=["stkcd", "year", "new_x"])
chk = firm.merge(r3, on=["stkcd", "year"])
aud["max_absdiff_vs_r3_new_x"] = float((chk.new_x_all.fillna(-1) - chk.new_x.fillna(-1)).abs().max())
firm.drop(columns="fy0").to_stata(OUT / "firm_rdfix.dta", write_index=False, version=118)

provs = sorted(pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                             columns=["province_in"]).province_in.dropna().unique())
da = pd.DataFrame({"dest": provs})
da["dest_id"] = da.dest.astype("category").cat.codes + 1
parts = []
for lab in ["rdfix", "rdtxt"]:
    d = nw[nw[lab] == 1].groupby(["stkcd", "year", "province_in"]).size().rename("n").reset_index()
    d = d.merge(da, left_on="province_in", right_on="dest")[["stkcd", "year", "dest_id"]]
    d[f"new_{lab}_any"] = 1
    parts.append(d.set_index(["stkcd", "year", "dest_id"]))
dy = pd.concat(parts, axis=1).fillna(0).reset_index()
dy.to_stata(OUT / "dyad_rdfix.dta", write_index=False, version=118)
pd.Series(aud).to_csv(EXP / "output/tables/ar10_build_audit.csv", header=["value"])
print(pd.Series(aud).to_string())
