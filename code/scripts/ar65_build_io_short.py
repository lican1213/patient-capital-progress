"""ar65_build_io_short.py — 第二十七轮：企业当期短期（非长期）主动机构持股，供旧表8第（4）列当期补跑。

规则见本 exploration README 第二十七轮（运行前写定）。筛选与 um01_build.py 第 7 节完全相同（主动、非社保、非被动、实体层），
只是不做年份平移：io_short 为当年值（um01 的 L_io_short 为上一年值）。另输出 L_io_short 用于核对。
只读输入：data/derived/patient_rebuild_20260922/holder_status.parquet、holders.parquet
输出（不入版控）：data/derived/advisor_send_20261008/企业短期机构持股当期.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar65_build_io_short.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
PR = ROOT / "data/derived/patient_rebuild_20260922"
OUT = ROOT / "data/derived/advisor_send_20261008/企业短期机构持股当期.dta"

hs = pd.read_parquet(PR / "holder_status.parquet", columns=["Symbol", "ShareHolderID", "HoldProportion", "S2", "passive", "year"])
ho = pd.read_parquet(PR / "holders.parquet", columns=["ShareHolderID", "entity", "investor", "welfare"])
hs = hs.merge(ho, on="ShareHolderID", how="left")
hs = hs[(hs.investor == True) & (hs.welfare != True) & (hs.passive != True) & hs.entity.fillna("").ne("")]
hs["stkcd"] = pd.to_numeric(hs.Symbol, errors="coerce")
hs = hs.dropna(subset=["stkcd"]); hs["stkcd"] = hs.stkcd.astype(int)
io = hs.groupby(["stkcd", "year"]).apply(lambda d: pd.Series({
    "io_long": d.HoldProportion[d.S2].sum(), "io_short": d.HoldProportion[~d.S2].sum()})).reset_index()
io["year"] = io.year.astype(int)
lag = io[["stkcd", "year", "io_short"]].assign(year=io.year + 1).rename(columns={"io_short": "L_io_short_chk"})
io = io.merge(lag, on=["stkcd", "year"], how="left")
# 核对：与旧双边面板的 L_io_short 一致
dy = pd.read_stata(ROOT / "data/derived/unified_market_dyadic_20260923/dyad.dta", columns=["stkcd", "year", "L_io_short"])
dy = dy.drop_duplicates(["stkcd", "year"]).dropna()
dy["stkcd"] = dy.stkcd.astype(int); dy["year"] = dy.year.astype(int)
c = dy.merge(io, on=["stkcd", "year"])
print("核对 L_io_short：配对", len(c), "最大绝对差", (c.L_io_short - c.L_io_short_chk).abs().max())
print(io.describe().T.round(4).to_string())
io[["stkcd", "year", "io_short", "io_long"]].to_stata(OUT, write_index=False, version=118)
print(OUT)
