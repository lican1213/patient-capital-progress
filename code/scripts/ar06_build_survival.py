"""ar06_build_survival.py — 第四轮 M4b：跨省子公司固定基期队列存续（README 第四轮预登记）。

企业—年份（survival.dta：stkcd year）
  stock0：基期 t 跨省子公司存量（企业×规范化子公司名去重）
  du3 / du5：基期队列在 t+3 / t+5 年仍被披露的数量；obs3 / obs5：母公司在 t+k 年仍在导师主面板
  dr3 / dr5：存续率（du/stock0）
跨省口径：子公司所在省 != 母公司所在省（明细字段 province_in / province_out）。
审计：本 exploration 的 output/tables/ar06_survival_audit.csv（各年明细行数、每家企业平均披露数、样本流）
运行：python3 explorations/advisor_revision_20261005/scripts/ar06_build_survival.py（项目根目录）
"""
from pathlib import Path
import re
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/advisor_revision_20261005"
TAB = ROOT / "explorations/advisor_revision_20261005/output/tables"
MP = Path("data/mentor_panel/主面板_含区位熵_地理IV_创新指标.dta")


def norm(s):
    # 统一全半角括号、去空白，作为子公司规范名
    s = str(s).replace("（", "(").replace("）", ")")
    return re.sub(r"\s+", "", s)


af = pd.read_stata(ROOT / "data/raw/source_snapshots/affiliate_detail_2014_2024.dta",
                   columns=["stkcd", "sub_name", "province_in", "province_out", "year"])
af["stkcd"] = af.stkcd.astype(int)
af["year"] = af.year.astype(int)
af["sn"] = af.sub_name.map(norm)
aud = []
per = af.groupby("year").agg(rows=("sn", "size"), firms=("stkcd", "nunique"))
for y, r in per.iterrows():
    aud.append({"item": f"rows_{y}", "value": r.rows})
    aud.append({"item": f"rows_per_firm_{y}", "value": round(r.rows / r.firms, 3)})

cr = af[af.province_in != af.province_out][["stkcd", "year", "sn"]].drop_duplicates()
aud.append({"item": "cross_rows_dedup", "value": len(cr)})

mp = pd.read_stata(MP, columns=["stkcd", "year"])
mp["stkcd"] = mp.stkcd.astype(int)
mp["year"] = mp.year.astype(int)
panel = set(zip(mp.stkcd, mp.year))

stock = cr.groupby(["stkcd", "year"]).size().rename("stock0").reset_index()
have = set(zip(cr.stkcd, cr.year, cr.sn))
rows = []
for (s, y), g in cr.groupby(["stkcd", "year"]):
    rec = {"stkcd": s, "year": y}
    for k in (3, 5):
        rec[f"obs{k}"] = int((s, y + k) in panel)
        rec[f"du{k}"] = sum((s, y + k, n) in have for n in g.sn) if rec[f"obs{k}"] else float("nan")
    rows.append(rec)
sv = stock.merge(pd.DataFrame(rows), on=["stkcd", "year"])
for k in (3, 5):
    sv[f"dr{k}"] = sv[f"du{k}"] / sv.stock0
    for lab, cap in (("main", 2023), ("mentor", 2024)):
        m = (sv.year + k <= cap) & (sv[f"obs{k}"] == 1)
        aud.append({"item": f"n_{k}y_{lab}", "value": int(m.sum())})
        aud.append({"item": f"mean_dr{k}_{lab}", "value": round(sv.loc[m, f"dr{k}"].mean(), 4)})
# 末年完整性：基期 2020 与 2021 的三年存续率对比
for y in (2019, 2020, 2021):
    m = (sv.year == y) & (sv.obs3 == 1)
    aud.append({"item": f"mean_dr3_base{y}", "value": round(sv.loc[m, "dr3"].mean(), 4)})

OUT.mkdir(parents=True, exist_ok=True)
sv.to_stata(OUT / "survival.dta", write_index=False, version=118)
pd.DataFrame(aud).to_csv(TAB / "ar06_survival_audit.csv", index=False)
print(pd.DataFrame(aud).to_string(index=False))
