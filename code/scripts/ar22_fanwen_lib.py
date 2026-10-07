"""ar22_fanwen_lib.py — 范文表格排版辅助函数，取自 explorations/unified_market_dyadic_20260923/scripts/um24_fanwen_skeleton_docx.py（去掉其输入路径常量；build 增加 merge_last 参数，允许表头最后一行横向合并）。"""
import csv
import re
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt


STD = "括号内为企业层面聚类稳健标准误；***、**和*分别表示1%、5%和10%的统计显著性水平。"
MINUS = "−"

# 需要斜体的变量符号（标签列、被解释变量行、表注中出现时）
VARS = {
    "Investp", "Investc", "Invests", "Investk", "Patient", "L.Patient", "LongInst", "Hitech", "IMR",
    "Pri_Number", "Pri_Hold", "LPatei", "WW", "TFP", "LowSeg", "ShortDist", "Resil", "Expand", "Cross",
    "INV", "Dual", "Lev", "Cashflow", "Indep", "Top5", "TobinQ", "ROA", "Growth", "SOE", "Lservice",
    "Lerner", "Integra0", "RD0", "Seg", "Seg0", "lnDist", "Entry", "Size", "BeltRoad", "Yangtze",
    "GreatBay", "Chengyu", "δ",
}
TOKEN = re.compile(r"L\.Patient|[A-Za-z_][A-Za-z0-9_]*|δ")


# ---------------------------------------------------------------- 读源稿表格（按 gridSpan 展开）
def read_tables(path):
    doc = Document(str(path))
    out = []
    for tbl in doc.element.body.iter(qn("w:tbl")):
        rows = []
        for tr in tbl.findall(qn("w:tr")):
            row = []
            for tc in tr.findall(qn("w:tc")):
                text = "".join(t.text or "" for t in tc.iter(qn("w:t"))).strip()
                gs = tc.find(".//" + qn("w:gridSpan"))
                row.extend([text] * (int(gs.get(qn("w:val"))) if gs is not None else 1))
            rows.append(row)
        out.append(rows)
    return out




def src_row(t, label, occurrence=0):
    """按行标签取源表第 t 张（1 起）的整行；返回数据列（不含标签列）及其下一行（标准误）。"""
    hits = [i for i, r in enumerate(S[t - 1]) if r[0] == label]
    i = hits[occurrence]
    return S[t - 1][i][1:], S[t - 1][i + 1][1:]


def src_line(t, label, occurrence=0):
    hits = [r for r in S[t - 1] if r[0] == label]
    return hits[occurrence][1:]


def pick(vals, cols):
    """cols 为源表 1 起的数据列号。"""
    return [vals[c - 1] for c in cols]


# ---------------------------------------------------------------- 底层格式
def set_fonts(run, size, bold=False, italic=False, east="宋体", sup=False):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.name = "Times New Roman"
    rpr = run._element.get_or_add_rPr()
    rf = rpr.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts")
        rpr.insert(0, rf)
    for k in ("w:ascii", "w:hAnsi", "w:cs"):
        rf.set(qn(k), "Times New Roman")
    rf.set(qn("w:eastAsia"), east)
    if sup:
        run.font.superscript = True


def exact_spacing(p, pts, before=0, after=0):
    pf = p.paragraph_format
    pf.line_spacing = Pt(pts)
    pf.line_spacing_rule = 4  # EXACTLY
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)


def fix_minus(s):
    return re.sub(r"(^|[\s(（])-(?=\d)", lambda m: m.group(1) + MINUS, s)


def write_rich(p, text, size, italic_vars=True):
    """把文本拆成 run：变量斜体、结尾星号上标、R² 中 R 斜体且 2 上标。"""
    text = fix_minus(text)
    m = re.match(r"^(.*?)(\*+)$", text)
    body, stars = (m.group(1), m.group(2)) if m and m.group(1) else (text, "")
    pos = 0
    pieces = []
    for mt in TOKEN.finditer(body):
        if mt.start() > pos:
            pieces.append((body[pos:mt.start()], False))
        pieces.append((mt.group(0), italic_vars and mt.group(0) in VARS))
        pos = mt.end()
    if pos < len(body):
        pieces.append((body[pos:], False))
    for seg, ital in pieces:
        # R² / R2 处理
        parts = re.split(r"(R²|R2(?![0-9]))", seg) if not ital else [seg]
        for part in parts:
            if part in ("R²", "R2"):
                set_fonts(p.add_run("R"), size, italic=True)
                set_fonts(p.add_run("2"), size, sup=True)
            elif part:
                set_fonts(p.add_run(part), size, italic=ital)
    if stars:
        set_fonts(p.add_run(stars), size, sup=True)


def cell_border(cell, side, sz):
    tcpr = cell._tc.get_or_add_tcPr()
    b = tcpr.find(qn("w:tcBorders"))
    if b is None:
        b = OxmlElement("w:tcBorders")
        tcpr.append(b)
    e = OxmlElement(f"w:{side}")
    e.set(qn("w:val"), "single")
    e.set(qn("w:sz"), str(sz))
    e.set(qn("w:space"), "0")
    e.set(qn("w:color"), "000000")
    b.append(e)


def table_props(tbl, widths):
    tblpr = tbl._tbl.tblPr
    for tag in ("w:tblStyle", "w:tblW", "w:jc", "w:tblBorders", "w:tblLayout", "w:tblCellMar"):
        for e in tblpr.findall(qn(tag)):
            tblpr.remove(e)
    w = OxmlElement("w:tblW"); w.set(qn("w:w"), str(sum(widths))); w.set(qn("w:type"), "dxa")
    jc = OxmlElement("w:jc"); jc.set(qn("w:val"), "center")
    bd = OxmlElement("w:tblBorders")
    for side, sz in (("top", 8), ("left", 0), ("bottom", 8), ("right", 0), ("insideH", 0), ("insideV", 0)):
        e = OxmlElement(f"w:{side}")
        e.set(qn("w:val"), "single" if sz else "none")
        e.set(qn("w:sz"), str(sz)); e.set(qn("w:space"), "0"); e.set(qn("w:color"), "000000" if sz else "auto")
        bd.append(e)
    lay = OxmlElement("w:tblLayout"); lay.set(qn("w:type"), "fixed")
    mar = OxmlElement("w:tblCellMar")
    for side, v in (("top", 0), ("left", 108), ("bottom", 0), ("right", 108)):
        e = OxmlElement(f"w:{side}"); e.set(qn("w:w"), str(v)); e.set(qn("w:type"), "dxa"); mar.append(e)
    for e in (w, jc, bd, lay, mar):
        tblpr.append(e)
    grid = tbl._tbl.tblGrid
    for gc, wd in zip(grid.findall(qn("w:gridCol")), widths):
        gc.set(qn("w:w"), str(wd))


def row_flags(row, header):
    trpr = row._tr.get_or_add_trPr()
    trpr.append(OxmlElement("w:cantSplit"))
    if header:
        trpr.append(OxmlElement("w:tblHeader"))


def caption(doc, text, before=12):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    exact_spacing(p, 18, before=before, after=3)
    p.paragraph_format.keep_with_next = True
    set_fonts(p.add_run(text), 9, bold=True, east="黑体")


def note(doc, text):
    p = doc.add_paragraph()
    exact_spacing(p, 12, before=2, after=0)
    pos = 0
    for m in re.finditer(r"\*+", text):
        if m.start() > pos:
            write_rich(p, text[pos:m.start()], 7.5)
        set_fonts(p.add_run(m.group(0)), 7.5, sup=True)
        pos = m.end()
    if pos < len(text):
        write_rich(p, text[pos:], 7.5)


def build(doc, header, body, widths=None, label_w=2300, full_w=9000, merge_label=True, keep=True, merge_last=False):
    """header：若干行（每行首格为标签）；相同相邻文字的非空格子按行合并（gridSpan）。
    body：行列表；以 None 作为元素的行表示“系数/标准误”成对行，标签列纵向合并。"""
    ncol = len(header[0])
    if widths is None:
        rest = (full_w - label_w) // (ncol - 1)
        widths = [label_w] + [rest] * (ncol - 1)
    rows = header + body
    tbl = doc.add_table(rows=len(rows), cols=ncol)
    table_props(tbl, widths)
    for i, data in enumerate(rows):
        is_head = i < len(header)
        row = tbl.rows[i]
        row_flags(row, is_head)
        for j, cell in enumerate(row.cells):
            cell.width = widths[j]
            cell.vertical_alignment = 1
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            exact_spacing(p, 14)
            p.paragraph_format.keep_with_next = keep or is_head
            txt = data[j] if data[j] is not None else ""
            if txt:
                write_rich(p, txt, 9)
        if i == len(header) - 1:
            for cell in row.cells:
                cell_border(cell, "bottom", 4)
    # 表头左上“变量”纵向合并
    if merge_label and len(header) > 1:
        top = tbl.cell(0, 0)
        top.merge(tbl.cell(len(header) - 1, 0))
        for p in top.paragraphs[1:]:
            p._element.getparent().remove(p._element)
        cell_border(top, "bottom", 4)
    # 表头分组行内相同文字横向合并（跳过标签列、列号行和最末的被解释变量行）
    for i in range(len(header)):
        j = 1
        while j < ncol:
            k = j
            while k + 1 < ncol and header[i][k + 1] == header[i][j] and header[i][j] and (i < len(header) - 1 or merge_last) and not header[i][1].startswith("（"):
                k += 1
            if k > j:
                keep = tbl.cell(i, j)
                merged = keep.merge(tbl.cell(i, k))
                for p in merged.paragraphs[1:]:
                    p._element.getparent().remove(p._element)
                if i == len(header) - 1:
                    cell_border(merged, "bottom", 4)
            j = k + 1
    # 系数行与标准误行的标签列纵向合并
    for i, data in enumerate(body):
        if data[0] == "" and i > 0 and body[i - 1][0] and any(re.match(r"^\(", c or "") for c in data[1:]):
            r = len(header) + i
            a = tbl.cell(r - 1, 0)
            a.merge(tbl.cell(r, 0))
            for p in a.paragraphs[1:]:
                p._element.getparent().remove(p._element)
    return tbl


def coef_pair(label, pair):
    b, se = pair
    return [[label] + b, [""] + se]


def nums_head(n):
    return ["变量"] + [f"（{i}）" for i in range(1, n + 1)]


def yes(n, v="是"):
    return [v] * n


