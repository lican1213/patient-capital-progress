"""ar40c_manual_sample.py — 第十四轮：MD&A 抽取人工验收的抽样与起止证据（README 第十四轮，抽样规则在看第二版结果前写定）。

抽样：已查实的 3 份；ok_fallback 随机 2 份；2014、2015 年各随机 2 份；正文字数最短 3 份、最长 2 份；2016—2024 年其余随机 6 份（种子 20261007，不重复）。
证据：每份给出原 PDF 起点页中节标题前后的行、抽取文本开头，终点后一页（下一节起始页）的开头、抽取文本结尾。
输出：本 exploration 的 review/lmda_manual_check/sample_evidence.md（逐份证据，供人工判定）与 output/tables/ar40c_manual_sample.csv（抽样清单，判定列待填）
运行：python3 explorations/advisor_revision_20261005/scripts/ar40c_manual_sample.py（项目根目录）
"""
import argparse
import random
from pathlib import Path

import fitz
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "explorations/advisor_revision_20261005"
D = ROOT / "data/derived/advisor_revision_20261005"
SRC = ROOT / "data/raw/annual_reports"
m = pd.read_csv(D / "mda_manifest.csv", dtype={"stkcd": str})
m["key"] = m.stkcd + "_" + m.year.astype(str)
ok = m[m.status.str.startswith("ok")].copy()
ap = argparse.ArgumentParser()
ap.add_argument("--round", type=int, default=1)
RND = ap.parse_args().round
rng = random.Random({1: 20261007, 2: 20261008, 3: 20261009, 4: 20261010}[RND])
picked = []
prev = set()
if RND >= 2:   # 第二、三轮：排除此前各轮全部样本
    for r0 in range(1, RND):
        prev |= set(pd.read_csv(EXP / f"output/tables/ar40c_manual_sample_round{r0}.csv", dtype=str).key)
    ok = ok[~ok.key.isin(prev)]


def take(keys, why):
    for k in keys:
        if k not in [p[0] for p in picked]:
            picked.append((k, why))


if RND == 1:
    take(["002291_2017", "002291_2018", "002053_2024"], "已查实错误")
fb = sorted(ok[ok.status == "ok_fallback"].key)
if RND == 4:   # 第四轮：备用规则样本另行全部核对（ar40d），这里不抽
    pass
elif RND == 3:   # 第三轮：2 份顶层编号类、1 份设计版
    take(rng.sample(sorted(ok[ok.note == "顶层编号"].key), 2), "备用规则·顶层编号")
    take(rng.sample(sorted(ok[ok.note == "设计版"].key), 1), "备用规则·设计版")
else:
    take(rng.sample(fb, min(2 if RND == 1 else 3, len(fb))), "备用规则")
for y in (2014, 2015):
    take(rng.sample(sorted(ok[(ok.status == "ok") & (ok.year == y)].key), 2), f"{y}年")
srt = ok[ok.status == "ok"].sort_values("chars")
take(list(srt.key[:3]), "最短")
take(list(srt.key[-2:]), "最长")
rest = sorted(set(ok[(ok.status == "ok") & ok.year.between(2016, 2024)].key) - {p[0] for p in picked})
take(rng.sample(rest, {1: 6, 2: 8, 3: 8, 4: 11}[RND]), "随机")
if RND == 3:   # 修正确认，不计入 20 份
    picked.append(("600585_2017", "修正确认"))
assert len(picked) == (21 if RND == 3 else 20), len(picked)

out = EXP / "review/lmda_manual_check"
out.mkdir(parents=True, exist_ok=True)
md = ["# MD&A 抽取人工验收证据（第十四轮）\n"]
rows = []
for k, why in picked:
    r = m[m.key == k].iloc[0]
    doc = fitz.open(SRC / f"{k}.pdf")
    txt = (D / "mda" / f"{k}.txt").read_text(encoding="utf-8")
    ps, pe = int(r.page_start), int(r.page_end)
    start_page = [ln for ln in doc[ps - 1].get_text().split("\n") if ln.strip()]
    nxt = [ln for ln in doc[pe].get_text().split("\n") if ln.strip()] if pe < len(doc) else ["（已到文末）"]
    md.append(f"## {k}（{why}）：{r.status}，节={r.section}，第 {ps}—{pe} 页，终点节={r.end_title}，字数 {r.chars}，全文 {len(doc)} 页\n")
    md.append("起点页前 12 行：\n```\n" + "\n".join(start_page[:12]) + "\n```")
    md.append("抽取文本开头：\n```\n" + txt[:240] + "\n```")
    md.append(f"终点后一页（第 {pe + 1} 页）前 8 行：\n```\n" + "\n".join(nxt[:8]) + "\n```")
    endpg = [ln for ln in doc[pe - 1].get_text().split("\n") if ln.strip()]
    hit = [j for j, ln in enumerate(endpg) if str(r.end_title)[:4] and str(r.end_title)[:4] in ln.replace(" ", "")]
    if hit:
        j = hit[-1]
        md.append(f"终点页（第 {pe} 页）下一节标题前后：\n```\n" + "\n".join(endpg[max(0, j - 4):j + 3]) + "\n```")
    md.append("抽取文本结尾：\n```\n" + txt[-240:] + "\n```\n")
    rows.append({"key": k, "why": why, "status": r.status, "section": r.section, "page_start": ps, "page_end": pe,
                 "end_title": r.end_title, "chars": r.chars, "pages_total": len(doc), "start_ok": "", "end_ok": "", "note": ""})
(out / f"sample_evidence_round{RND}.md").write_text("\n".join(md), encoding="utf-8")
pd.DataFrame(rows).to_csv(EXP / f"output/tables/ar40c_manual_sample_round{RND}_draw.csv", index=False)
print(pd.DataFrame(rows)[["key", "why", "section", "page_start", "page_end", "end_title", "chars"]].to_string(index=False))
