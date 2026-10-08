"""ar40_mda_extract.py — 从年报 PDF 抽取“管理层讨论与分析”一节文本（LMDA 自建第二步）。

计划：quality_reports/plans/2026-10-07_lmda_build.md
规则（第二版，2026-10-07 按 LMDA 过程审计修正，见 quality_reports/advisor_feedback_20261005/LMDA过程审计_20261007.md）：
  1. 只把“整行就是 第X节＋标题”的行当作节标题（去空白后比对，允许目录行尾的点线与页码；标题与“第X节”分两行时合并）。
     正文中引用某节的句子（如“第四节‘管理层讨论与分析’中风险因素”）不再当作标题。第一版用包含匹配，会把引用当成章节起点。
  2. 目标节：标题恰为“管理层讨论与分析”“经营情况讨论与分析”“董事会报告”“董事局报告”“董事会工作报告”之一（可带括号补注），按此顺序优先。
  3. 终点：起点之后第一个节号不同的节标题；与起点节号相同的行视为重复页眉，不作终点。第一版把每页重复的页眉当成新节，只留下中间片段。
  4. 同一目标节出现多次（目录、正文）时取跨度最长的一段，以跳过目录。
  5. 段内删去重复的本节页眉、公司年报页眉与纯页码行；记录起止页码与终点节标题，供人工核对。
  第二版第二轮（人工验收第一轮查出 5 处错误后，按错误类型修正，见 README 第十四轮）：
  6. 终点只认与起点同为“节”或同为“章”、且节号大于起点的标题，优先节号恰好加一；“第四章”内部用“第一节”编号的小节、表格中的“第X节”不再当终点。
  7. A+H 公司：标题含“内地”“境内”的经营情况讨论与分析优先；按联交所规则编制的“管理层讨论与分析”（开头提及联交所、香港上市规则）在另有董事会报告一节时改取董事会报告。
  8. 设计版年报（无“第X节”编号）：取独占一行的“经营情况讨论与分析”等标题，到独占一行的下一节标题（重要事项、公司治理等）为止；
     顶层“四、董事会报告”编号的备用规则只用于董事会报告类标题，不再把小节“一、经营情况讨论与分析”当整节。
  11. 第四轮全部备用规则核对后：顶层编号的经营讨论类规则先于设计版规则；设计版起点允许带章节序号（如“经营情况讨论与分析04”），
      终点允许带编号，区间内出现“公司业务概要”等前置节标题时舍去该起点（多为导读页）；段内乱码字符占比超过 5% 记为 garbled，不计指标。
  10. 第四轮（人工验收第三轮查出设计版年报下一节名为“重大事项”）：下一节标题清单补“重大事项”“社会责任”“股本变动及股东情况”等，
      设计版按“以清单中标题开头、整行不超过 25 字”认定。
  9. 第三轮（人工验收第二轮查出 A+H 顶层编号格式错误）：顶层编号备用规则先认“X、管理层讨论与分析／经营情况讨论与分析”（X 不为“一”，
     终点须为下一编号的节级标题），没有时才取“X、董事会报告”。
  其余同第一版：备用规则（顶层“四、董事会报告”编号）、文本过短记 scanned_or_empty、找不到记 no_section。第一版代码保留为 ar40_mda_extract_v1_未验收.py。
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
TITLES = ["管理层讨论与分析", "经营情况讨论与分析", "董事会报告", "董事局报告", "董事会工作报告"]
SEC = re.compile(rf"^第([{NUM}]{{1,3}})([节章])(.*)$")
DOMESTIC = re.compile(r"(内地|境内).{0,15}(经营情况讨论与分析|管理层讨论与分析)$")
BOARD = ["董事会报告", "董事局报告", "董事会工作报告"]
NEXTSEC = ("重要事项", "重大事项", "公司治理", "企业管治", "董事会报告", "监事会报告", "环境与社会责任", "环境和社会责任",
           "社会责任", "股份变动及股东情况", "普通股股份变动及股东情况", "股本变动及股东情况", "董事、监事、高级管理人员")
HKRULE = re.compile(r"联交所|香港联合交易所|香港上市规则")
PRESEC = ("公司业务概要", "公司简介和主要财务指标", "公司简介", "释义", "重要提示", "董事长致辞", "致股东")
GARBLE = 0.05   # 段内非中文、非拉丁、非常用符号字符占比超过此值，视为字体无 Unicode 映射的乱码文本
TOCTAIL = re.compile(r"[.．…·•\-—_]{2,}\d*$|\d+$")
PAGEHDR = re.compile(r"^\s*(\S{2,40}?(20\d\d|二〇[一二]\S)\s*年\s*(年度|半年度)?报告(全文)?(正文)?)\s*$")
PAGENO = re.compile(r"^\s*(\d{1,4}|\d{1,4}\s*/\s*\d{1,4}|第\s*\d+\s*页.*|-\s*\d+\s*-)\s*$")
BADCH = re.compile(r"[“”‘’\"'，。；：:、（(]")


def cn2int(s):
    if s == "十":
        return 10
    if s.startswith("十"):
        return 10 + NUM.index(s[1]) + 1
    if s.endswith("十"):
        return (NUM.index(s[0]) + 1) * 10
    if "十" in s:
        a, b = s.split("十")
        return (NUM.index(a) + 1) * 10 + NUM.index(b) + 1
    return NUM.index(s) + 1


def headings(lines):
    """返回 [(行号, 节号, 节或章, 标题)]：只收整行为“第X节＋标题”的行。"""
    out = []
    for i, ln in enumerate(lines):
        t = re.sub(r"\s", "", ln)
        m = SEC.match(t)
        if not m:
            continue
        title = m.group(3)
        if not title:  # 标题在下一非空行
            for j in range(i + 1, min(i + 4, len(lines))):
                nx = re.sub(r"\s", "", lines[j])
                if nx:
                    title = nx
                    break
        title = TOCTAIL.sub("", title)
        # 两节挤在一行（“第八节 优先股相关情况 第九节 债券相关情况”）时只取第一节
        title = re.split(rf"第[{NUM}]{{1,3}}[节章]", title)[0]
        core = re.sub(r"[（(][^）)]{0,15}[）)]$", "", title)
        if not (2 <= len(core) <= 25) or BADCH.search(core):
            continue
        out.append((i, cn2int(m.group(1)), m.group(2), title))
    return out


def clean(seg_lines, target_title):
    keep = []
    for ln in seg_lines:
        t = re.sub(r"\s", "", ln)
        if PAGEHDR.match(ln) or PAGENO.match(ln):
            continue
        m = SEC.match(t)
        if m and keep and target_title in t:   # 段内重复的本节页眉
            continue
        keep.append(ln)
    return "\n".join(keep)


def odd_share(seg):
    t = re.sub(r"\s", "", seg)
    ok = lambda o: (o < 0x250 or 0x4E00 <= o <= 0x9FFF or 0x3000 <= o <= 0x303F or 0xFF00 <= o <= 0xFFEF or 0x2000 <= o <= 0x2BFF
                    or 0x3400 <= o <= 0x4DBF or 0x0370 <= o <= 0x03FF or 0x0400 <= o <= 0x04FF or 0xE000 <= o <= 0xF8FF
                    or 0xF900 <= o <= 0xFAFF or 0x2E80 <= o <= 0x2FDF or 0x3300 <= o <= 0x33FF or 0xFE30 <= o <= 0xFE6F)
    return sum(1 for c in t if not ok(ord(c))) / max(len(t), 1)


def extract(pdf):
    row = _extract(pdf)
    if row[2].startswith("ok"):
        sh = odd_share((OUT / f"{row[0]}_{row[1]}.txt").read_text(encoding="utf-8"))
        if sh > GARBLE:
            row[2], row[8] = "garbled", f"乱码字符占比 {sh:.3f}"
    return row


def _extract(pdf):
    code, year = pdf.stem.split("_")
    try:
        doc = fitz.open(pdf)
        pages = [p.get_text() for p in doc]
    except Exception as e:
        return [code, year, "pdf_error", "", 0, "", "", "", str(e)[:60]]
    text = "\n".join(pages)
    if len(re.sub(r"\s", "", text)) < 5000:
        return [code, year, "scanned_or_empty", "", 0, "", "", "", ""]
    lines, lpage = [], []
    for k, pg in enumerate(pages, start=1):
        for ln in pg.split("\n"):
            lines.append(ln)
            lpage.append(k)
    hs = headings(lines)

    def section_end(idx):
        i, num, mk, _ = hs[idx]
        later = [(j, n2, t2) for (j, n2, mk2, t2) in hs[idx + 1:] if j > i and mk2 == mk and n2 > num]
        nxt = next((h for h in later if h[1] == num + 1), later[0] if later else None)
        return (nxt[0], nxt[2]) if nxt else (len(lines), "")

    def best_for(match):
        best = None
        for idx, (i, num, mk, t) in enumerate(hs):
            core = re.sub(r"[（(][^）)]{0,15}[）)]$", "", t)
            if not match(core):
                continue
            e, endt = section_end(idx)
            span = sum(len(x) for x in lines[i:e])
            if best is None or span > best[0]:
                best = (span, i, e, endt, core)
        return best if best and best[0] > 2000 else None

    order = [("domestic", lambda c: bool(DOMESTIC.search(c)))] + [(t, (lambda t: lambda c: c == t)(t)) for t in TITLES]
    found = {name: best_for(f) for name, f in order}
    pick = next((found[name] for name, _ in order if found[name]), None)
    if pick and pick[4] in ("管理层讨论与分析", "经营情况讨论与分析"):
        head = "".join(lines[pick[1]:pick[1] + 40])
        board = next((found[b] for b in BOARD if found[b]), None)
        if HKRULE.search(head) and board:   # A+H：联交所口径的管理层讨论与分析，改取董事会报告
            pick = board
    if pick:
        _, i, e, endt, title = pick
        seg = clean(lines[i:e], title)
        (OUT / f"{code}_{year}.txt").write_text(seg, encoding="utf-8")
        return [code, year, "ok", title, len(seg), lpage[i], lpage[e - 1], endt, ""]
    def numbered(titles):
        """顶层编号的年报（如“五、经营情况讨论与分析”“四、董事会报告”），取到下一个顶层编号为止。"""
        for title in titles:
            mdna = title not in BOARD
            best = None
            for i, ln in enumerate(lines):
                m = re.match(rf"^\s*([{NUM}]+)、\s*{title}\s*$", ln)
                if not m:
                    continue
                k = NUM.find(m.group(1)[-1])
                if k < 0 or k + 1 >= len(NUM) or (mdna and m.group(1) == "一"):
                    continue
                nre = re.compile(rf"^\s*{NUM[k + 1]}、\s*(\S{{2,20}})\s*$")
                e = next((j for j in range(i + 1, len(lines)) if (mm := nre.match(lines[j]))
                          and (not mdna or mm.group(1).startswith(NEXTSEC))), len(lines))
                if mdna and e == len(lines):
                    continue
                span = sum(len(x) for x in lines[i:e])
                if best is None or span > best[0]:
                    best = (span, i, e)
            if best and best[0] > 2000:
                return title, best[1], best[2]
        return None

    def design():
        """设计版年报（无“第X节”）：独占一行的节标题（可带章节序号如“04”）到独占一行的下一节标题；
        区间内若出现“公司业务概要”等前置节标题，说明起点是目录或导读页，舍去。"""
        nxt = re.compile(r"^(?:[一二三四五六七八九十]+、)?(.{2,23}?)\d{0,2}$")
        for title in TITLES:
            best = None
            for i, ln in enumerate(lines):
                if re.sub(r"\d{1,2}$", "", re.sub(r"\s", "", ln)) != title:
                    continue
                e = len(lines)
                for j in range(i + 1, len(lines)):
                    t = re.sub(r"\s", "", lines[j])
                    mm = nxt.match(t) if len(t) <= 25 else None
                    if mm and mm.group(1).startswith(NEXTSEC) and mm.group(1) != title:
                        e = j
                        break
                if e == len(lines):
                    continue
                if any(re.sub(r"\d{1,2}$", "", re.sub(r"\s", "", x)).startswith(PRESEC) and len(re.sub(r"\s", "", x)) <= 14
                       for x in lines[i + 1:e]):
                    continue
                span = sum(len(x) for x in lines[i:e])
                if best is None or span > best[0]:
                    best = (span, i, e)
            if best and best[0] > 2000:
                return title, best[1], best[2]
        return None

    for rule, got in (("顶层编号", lambda: numbered(["管理层讨论与分析", "经营情况讨论与分析"])), ("设计版", design),
                      ("顶层编号", lambda: numbered(BOARD))):
        r = got()
        if r:
            title, i, e = r
            seg = clean(lines[i:e], title)
            (OUT / f"{code}_{year}.txt").write_text(seg, encoding="utf-8")
            return [code, year, "ok_fallback", title, len(seg), lpage[i], lpage[e - 1],
                    lines[e].strip()[:20] if e < len(lines) else "", rule]
    return [code, year, "no_section", "", 0, "", "", "", "|".join(t for _, _, _, t in hs[:14])[:200]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--procs", type=int, default=6)
    ap.add_argument("--only", default="", help="只跑指定年报，逗号分隔，如 002291_2018（试验用，会覆盖清单）")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    pdfs = sorted(p for p in SRC.glob("*_*.pdf") if p.stat().st_size > 10000)
    if a.only:
        pdfs = [SRC / f"{x}.pdf" for x in a.only.split(",")]
    if a.limit:
        pdfs = pdfs[: a.limit]
    with Pool(a.procs) as pool:
        rows = pool.map(extract, pdfs, chunksize=8)
    with MAN.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["stkcd", "year", "status", "section", "chars", "page_start", "page_end", "end_title", "note"])
        w.writerows(rows)
    from collections import Counter
    print(len(rows), Counter(r[2] for r in rows), Counter(r[3] for r in rows))


if __name__ == "__main__":
    main()
