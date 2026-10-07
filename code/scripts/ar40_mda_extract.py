"""ar40_mda_extract.py — 从年报 PDF 抽取“管理层讨论与分析”一节文本（LMDA 自建第二步）。

计划：quality_reports/plans/2026-10-07_lmda_build.md
规则：节标题依年报格式不同依次认“管理层讨论与分析”“经营情况讨论与分析”“董事会报告”；
      取“第X节 <上述标题>”到下一个“第X节”之间的文本，若出现多次（目录与正文），取最长的一段以跳过目录；
      去掉页眉（“××公司20××年年度报告”类单行）与纯页码行；文本过短记为 scanned_or_empty，找不到节标题记为 no_section。
输入：data/raw/annual_reports/{stkcd6}_{year}.pdf（ar39 下载）
输出：data/derived/advisor_revision_20261005/mda/{stkcd6}_{year}.txt；清单 data/derived/advisor_revision_20261005/mda_manifest.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar40_mda_extract.py [--limit N] [--procs 6]（项目根目录）
"""
import argparse
import csv
import re
from multiprocessing import Pool
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "data/raw/annual_reports"
OUT = ROOT / "data/derived/advisor_revision_20261005/mda"
MAN = OUT.parent / "mda_manifest.csv"
NUM = "一二三四五六七八九十"
HEAD = re.compile(rf"^\s*第\s*[{NUM}]+\s*[节章]\s*(.{{0,30}})$", re.M)
TITLES = ["管理层讨论与分析", "经营情况讨论与分析", "董事会报告", "董事局报告", "董事会工作报告"]
PAGEHDR = re.compile(r"^\s*(\S{2,40}?(20\d\d|二〇[一二]\S)\s*年\s*(年度|半年度)?报告(全文)?(正文)?)\s*$")
PAGENO = re.compile(r"^\s*(\d{1,4}|\d{1,4}\s*/\s*\d{1,4}|第\s*\d+\s*页.*|-\s*\d+\s*-)\s*$")


def clean(seg):
    keep = [ln for ln in seg.split("\n") if not PAGEHDR.match(ln) and not PAGENO.match(ln)]
    return "\n".join(keep)


def extract(pdf):
    code, year = pdf.stem.split("_")
    try:
        doc = fitz.open(pdf)
        text = "\n".join(p.get_text() for p in doc)
    except Exception as e:
        return [code, year, "pdf_error", "", 0, str(e)[:60]]
    if len(re.sub(r"\s", "", text)) < 5000:
        return [code, year, "scanned_or_empty", "", 0, ""]
    heads = [(m.start(), re.sub(r"\s", "", m.group(1))) for m in HEAD.finditer(text)]
    # 标题可能与“第X节”分在两行：标题为空时取下一非空行
    fixed = []
    for pos, t in heads:
        if not t:
            nxt = text[text.find("\n", pos) + 1: text.find("\n", pos) + 60].strip().split("\n")[0]
            t = re.sub(r"\s", "", nxt)
        fixed.append((pos, t))
    for title in TITLES:
        best = None
        for i, (pos, t) in enumerate(fixed):
            if title in t:
                end = fixed[i + 1][0] if i + 1 < len(fixed) else len(text)
                if best is None or end - pos > best[1] - best[0]:
                    best = (pos, end)
        if best and best[1] - best[0] > 2000:
            seg = clean(text[best[0]:best[1]])
            (OUT / f"{code}_{year}.txt").write_text(seg, encoding="utf-8")
            return [code, year, "ok", title, len(seg), ""]
    # 备用规则：顶层以“四、董事会报告”编号的年报，取到下一个顶层编号（如“五、”）为止
    for title in TITLES:
        best = None
        for m in re.finditer(rf"^\s*([{NUM}]+)、\s*{title}\s*$", text, re.M):
            k = NUM.find(m.group(1)[-1])
            if k < 0 or k + 1 >= len(NUM):
                continue
            nxt = re.compile(rf"^\s*{NUM[k + 1]}、\s*\S{{2,20}}\s*$", re.M).search(text, m.end())
            end = nxt.start() if nxt else len(text)
            if best is None or end - m.start() > best[1] - best[0]:
                best = (m.start(), end)
        if best and best[1] - best[0] > 2000:
            seg = clean(text[best[0]:best[1]])
            (OUT / f"{code}_{year}.txt").write_text(seg, encoding="utf-8")
            return [code, year, "ok_fallback", title, len(seg), ""]
    return [code, year, "no_section", "", 0, "|".join(t for _, t in fixed[:14])[:200]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--procs", type=int, default=6)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    pdfs = sorted(p for p in SRC.glob("*_*.pdf") if p.stat().st_size > 10000)
    if a.limit:
        pdfs = pdfs[: a.limit]
    with Pool(a.procs) as pool:
        rows = pool.map(extract, pdfs, chunksize=8)
    with MAN.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["stkcd", "year", "status", "section", "chars", "note"])
        w.writerows(rows)
    from collections import Counter
    print(len(rows), Counter(r[2] for r in rows), Counter(r[3] for r in rows))


if __name__ == "__main__":
    main()
