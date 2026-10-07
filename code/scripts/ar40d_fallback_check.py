"""ar40d_fallback_check.py — 第十四轮第四轮验收：全部备用规则样本（ok_fallback）的起止证据，逐份人工核对，不抽样。

证据：起点页中起点行前后各 3 行；终点页中终点行前 4 行、终点行及后 2 行；同时列出该年报中所有独占一行、像节标题的行（页码＋文字），
      用来判断起点之前是否还有更合适的经营讨论节、终点是否就是下一节。
输出：本 exploration 的 review/lmda_manual_check/fallback_all_round4.md
运行：python3 explorations/advisor_revision_20261005/scripts/ar40d_fallback_check.py（项目根目录）
"""
import re
from pathlib import Path

import fitz
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
D = ROOT / "data/derived/advisor_revision_20261005"
SRC = ROOT / "data/raw/annual_reports"
KEYS = ("讨论与分析", "董事会报告", "重要事项", "重大事项", "公司治理", "管治", "社会责任", "股份变动", "股本变动",
        "董事、监事", "业务概要", "业务回顾", "致股东", "董事长")
m = pd.read_csv(D / "mda_manifest.csv", dtype={"stkcd": str})
fb = m[m.status == "ok_fallback"]
md = ["# 备用规则样本全部核对证据（第四轮）\n"]
for _, r in fb.iterrows():
    k = f"{r.stkcd}_{r.year}"
    doc = fitz.open(SRC / f"{k}.pdf")
    txt = (D / "mda" / f"{k}.txt").read_text(encoding="utf-8")
    first = txt.strip().split("\n")[0].strip()
    md.append(f"## {k}：{r.note}，节={r.section}，第 {int(r.page_start)}—{int(r.page_end)} 页，终点={r.end_title}，字数 {r.chars}，全文 {len(doc)} 页\n")
    heads = []
    for i, p in enumerate(doc):
        for ln in p.get_text().split("\n"):
            t = re.sub(r"\s", "", ln)
            if 2 <= len(t) <= 22 and any(x in t for x in KEYS) and not re.search(r"[，。；：]", t):
                heads.append(f"p{i + 1}:{t}")
    seen, uniq = set(), []
    for h in heads:
        if h.split(":", 1)[1] not in seen:
            seen.add(h.split(":", 1)[1])
            uniq.append(h)
    md.append("节标题样的行（每种文字首次出现）：" + "；".join(uniq[:40]) + "\n")
    md.append("抽取文本开头：\n```\n" + txt[:200] + "\n```")
    ep = [ln for ln in doc[int(r.page_end) - 1].get_text().split("\n") if ln.strip()]
    key = str(r.end_title)[:4]
    hit = [j for j, ln in enumerate(ep) if key and key in ln.replace(" ", "")]
    if hit:
        j = hit[-1]
        md.append(f"终点页第 {int(r.page_end)} 页终点行前后：\n```\n" + "\n".join(ep[max(0, j - 4):j + 3]) + "\n```")
    md.append("抽取文本结尾：\n```\n" + txt[-200:] + "\n```\n")
(EXP / "review/lmda_manual_check/fallback_all_round4.md").write_text("\n".join(md), encoding="utf-8")
print(len(fb))
