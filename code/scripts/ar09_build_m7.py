"""ar09_build_m7.py — 第四轮 M7a/M7b/M7c 数据（README“M7 进一步分析补缺”）。

dest_attr_m7.dta（dest_id）：tfp0（目的省 2014 年导师面板上市公司 TFP 省均值）
dyad_lq.dta（stkcd dest_id）：lq（目的省对企业行业的区位熵，CSMAR 2010—13 总部计数均值）
审计：本 exploration 的 output/tables/ar09_build_audit.csv；ar09_label_audit.csv（M7c 交叉表）；ar09_label_disagree.csv（抽样）
运行：python3 explorations/advisor_revision_20261005/scripts/ar09_build_m7.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
OUT = ROOT / "data/derived/advisor_revision_20261005"
TAB = EXP / "output/tables"
MP = Path("data/mentor_panel/主面板_含区位熵_地理IV_创新指标.dta")
STK = Path("data/raw/csmar/STK_LISTEDCOINFOANL.dta")
aud = {}

# dest_id 编码：与 um01/ar05 相同（明细 province_in 省份名排序）
af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                   columns=["stkcd", "sub_name", "province_in", "province_out", "year", "Corebs", "is_div_rd"])
provs = sorted(af.province_in.dropna().unique())
da = pd.DataFrame({"dest": provs})
da["dest_id"] = da.dest.astype("category").cat.codes + 1

# M7a 目的省期初 TFP（2014，导师面板，按母公司所在省份）
mp = pd.read_stata(MP, columns=["stkcd", "year", "TFP", "母公司所在省份"])
t0 = mp[mp.year == 2014].groupby("母公司所在省份").TFP.mean()
da["tfp0"] = da.dest.map(t0)
aud["tfp0_missing_prov"] = int(da.tfp0.isna().sum())
aud["tfp0_nfirms_2014"] = int(mp[(mp.year == 2014) & mp.TFP.notna()].shape[0])
old = pd.read_stata(OUT / "dest_attr.dta").merge(da, on="dest_id")
for v in ["east", "mkt0", "rdres0"]:
    aud[f"corr_tfp0_{v}"] = round(float(old[["tfp0", v]].corr().iat[0, 1]), 3)
da[["dest_id", "tfp0"]].to_stata(OUT / "dest_attr_m7.dta", write_index=False, version=118)

# M7b 同行业区位熵（总部计数，2010—13）
st = pd.read_stata(STK, columns=["Symbol", "EndDate", "IndustryCodeC", "PROVINCE"])
st["y"] = pd.to_datetime(st.EndDate, errors="coerce").dt.year
st["stkcd"] = pd.to_numeric(st.Symbol, errors="coerce")
b = st[st.y.between(2010, 2013) & st.IndustryCodeC.ne("") & st.PROVINCE.isin(provs)].dropna(subset=["IndustryCodeC"])
b = b.drop_duplicates(["stkcd", "y"])
lqs = []
for y, g in b.groupby("y"):
    n_dk = g.groupby(["PROVINCE", "IndustryCodeC"]).size()
    n_d = g.groupby("PROVINCE").size()
    n_k = g.groupby("IndustryCodeC").size()
    full = pd.MultiIndex.from_product([n_d.index, n_k.index], names=["PROVINCE", "IndustryCodeC"])
    n_dk = n_dk.reindex(full, fill_value=0)
    lq = (n_dk / n_d.reindex(n_dk.index.get_level_values(0)).values) / (n_k.reindex(n_dk.index.get_level_values(1)).values / len(g))
    lqs.append(lq.rename("lq").reset_index().assign(y=y))
lq = pd.concat(lqs).groupby(["PROVINCE", "IndustryCodeC"]).lq.mean().reset_index()
# 企业行业：样本首年（导师面板首年）对应的 CSMAR 行业代码；该年缺失则取最近年份
fy = mp.groupby("stkcd").year.min().rename("fy").reset_index()
fy["stkcd"] = fy.stkcd.astype(int)
ind = st.dropna(subset=["stkcd"]).query("IndustryCodeC != ''")[["stkcd", "y", "IndustryCodeC"]]
ind = ind.merge(fy, on="stkcd")
ind["gap"] = (ind.y - ind.fy).abs()
ind = ind.sort_values(["stkcd", "gap", "y"]).drop_duplicates("stkcd")[["stkcd", "IndustryCodeC"]]
aud["firms_with_industry"] = int(len(ind))
aud["firms_in_panel"] = int(len(fy))
dl = ind.merge(da[["dest", "dest_id"]], how="cross").merge(
    lq, left_on=["dest", "IndustryCodeC"], right_on=["PROVINCE", "IndustryCodeC"], how="left")
dl["lq"] = dl.lq.fillna(0.0)
aud["lq_share_zero"] = round(float((dl.lq == 0).mean()), 3)
aud["lq_share_gt1"] = round(float((dl.lq > 1).mean()), 3)
aud["lq_p99"] = round(float(dl.lq.quantile(0.99)), 3)
dl[["stkcd", "dest_id", "lq"]].to_stata(OUT / "dyad_lq.dta", write_index=False, version=118)

# M7c 功能标签文本核对（新增跨省子公司：企业×子公司名首次出现、非企业首个观测年）
af["stkcd"] = af.stkcd.astype(int)
af["year"] = af.year.astype(int)
af = af.merge(fy, on="stkcd")
af["first"] = af.groupby(["stkcd", "sub_name"]).year.transform("min")
nw = af[(af.province_in != af.province_out) & (af.year == af["first"]) & (af.year > af.fy)].copy()
pat = "研发|研究|技术开发|试验|检测"
nw["kw"] = nw.Corebs.fillna("").str.contains(pat).astype(int)
nw["has_text"] = nw.Corebs.fillna("").str.len().gt(0).astype(int)
ct = pd.crosstab(nw.is_div_rd, nw.kw, margins=True)
ct.to_csv(TAB / "ar09_label_audit.csv")
aud["new_cross_subs"] = int(len(nw))
aud["share_text_missing"] = round(float(1 - nw.has_text.mean()), 3)
aud["kw_rate_given_rd1"] = round(float(nw.loc[nw.is_div_rd == 1, "kw"].mean()), 3)
aud["kw_rate_given_rd0"] = round(float(nw.loc[nw.is_div_rd == 0, "kw"].mean()), 3)
aud["agreement"] = round(float((nw.kw == nw.is_div_rd).mean()), 3)
dis = pd.concat([nw[(nw.is_div_rd == 1) & (nw.kw == 0)].sample(15, random_state=20261007),
                 nw[(nw.is_div_rd == 0) & (nw.kw == 1)].sample(15, random_state=20261007)])
dis[["stkcd", "year", "sub_name", "is_div_rd", "kw", "Corebs"]].to_csv(TAB / "ar09_label_disagree.csv", index=False)

# 全部明细中研发标签的房地产污染（所有年份、所有异地子公司行）
allrd = af[af.is_div_rd == 1]
re_all = allrd.sub_name.fillna("").str.contains("房地产|置业|物业|地产") | allrd.Corebs.fillna("").str.contains("房地产")
aud["rd_label_rows_all"] = int(len(allrd))
aud["rd_label_realestate_share_all"] = round(float(re_all.mean()), 3)
aud["rd_label_kw_share_all"] = round(float(allrd.Corebs.fillna("").str.contains(pat).mean()), 3)
pd.Series(aud).to_csv(TAB / "ar09_build_audit.csv", header=["value"])
print(pd.Series(aud).to_string())
print(ct)
