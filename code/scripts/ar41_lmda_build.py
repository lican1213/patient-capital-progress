"""ar41_lmda_build.py — 由 MD&A 文本计算管理者短视指标与 LMDA（LMDA 自建第三步）。

计划：quality_reports/plans/2026-10-07_lmda_build.md
定义（胡楠、薛付婧、王昊楠，2021，《管理世界》第5期；初稿8机制节）：
  短视度 = 43 个“短期视域”词总词频 / MD&A 总词频 × 100；LMDA = ln(1 + 短视度)。
  总词频为 jieba 分词后的词数（只计含汉字、字母或数字的词，不计标点与空白）。43 个词加入 jieba 自定义词典，保证整词切分。
词表来源：
  W30：原文网络发行版附表2 明列——种子词 10 个、扩充词 20 个（原文附表写“等（共33个）”）。
  W13：其余 13 个取自二手资料，与原文附表1 列出的“尽快”相似词（尽早、早日、及早）一致，但未能在原文中逐字核对。
  主指标用 43 个词（W30＋W13），另报只用 W30 的版本作对照。
输入：data/derived/advisor_revision_20261005/mda/*.txt；mda_manifest.csv
输出：data/derived/advisor_revision_20261005/lmda.dta、lmda.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar41_lmda_build.py [--procs 6]（项目根目录）
"""
import argparse
import logging
import re
from multiprocessing import Pool
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
D = ROOT / "data/derived/advisor_revision_20261005"
SEED = ["天内", "数月", "年内", "尽快", "立刻", "马上", "契机", "之际", "压力", "考验"]
EXP20 = ["日内", "数天", "随即", "即刻", "在即", "最晚", "最迟", "关头", "恰逢", "来临之际", "前夕", "适逢", "遇上", "正逢",
         "之时", "难度", "困境", "严峻考验", "双重压力", "通胀压力"]
W13 = ["上涨压力", "应尽快", "尽早", "早日", "及早", "时值", "时机", "到来之际", "财务压力", "环境压力", "诸多困难", "融资压力",
       "还款压力"]
W30 = SEED + EXP20
W43 = W30 + W13
assert len(set(W30)) == 30 and len(set(W43)) == 43
TOK = re.compile(r"[一-鿿A-Za-z0-9]")


def init():
    import jieba
    jieba.setLogLevel(logging.WARNING)
    for w in W43:
        jieba.add_word(w, freq=200000)
    globals()["jieba"] = jieba


def count(path):
    code, year = path.stem.split("_")
    text = path.read_text(encoding="utf-8").replace("\n", "")
    toks = [t for t in jieba.lcut(text) if TOK.search(t)]
    n = len(toks)
    c43 = sum(1 for t in toks if t in W43set)
    c30 = sum(1 for t in toks if t in W30set)
    return code, int(year), n, c43, c30


W43set, W30set = set(W43), set(W30)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--procs", type=int, default=6)
    a = ap.parse_args()
    m = pd.read_csv(D / "mda_manifest.csv", dtype={"stkcd": str})
    ok = m[m.status.str.startswith("ok")]
    files = [D / "mda" / f"{c}_{y}.txt" for c, y in zip(ok.stkcd, ok.year)]
    with Pool(a.procs, initializer=init) as pool:
        rows = pool.map(count, files, chunksize=16)
    r = pd.DataFrame(rows, columns=["code", "year", "mda_words", "n43", "n30"])
    r["myopia"] = r.n43 / r.mda_words * 100
    r["myopia30"] = r.n30 / r.mda_words * 100
    import numpy as np
    r["LMDA"] = np.log1p(r.myopia)
    r["LMDA30"] = np.log1p(r.myopia30)
    r["stkcd"] = r.code.astype(int)
    r = r.merge(ok[["stkcd", "year", "section"]].assign(stkcd=lambda x: x.stkcd.astype(int)), on=["stkcd", "year"], how="left")
    r = r[["stkcd", "year", "section", "mda_words", "n43", "n30", "myopia", "myopia30", "LMDA", "LMDA30"]]
    r.to_csv(D / "lmda.csv", index=False)
    r.rename(columns={"section": "mda_section"}).to_stata(D / "lmda.dta", write_index=False, version=118)
    print(len(r))
    print(r[["mda_words", "myopia", "myopia30", "LMDA"]].describe().round(4).to_string())
    print(r[r.year <= 2018].myopia.describe().round(4).to_string())


if __name__ == "__main__":
    main()
