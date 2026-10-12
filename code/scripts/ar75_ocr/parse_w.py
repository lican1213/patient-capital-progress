"""把 Vision OCR 的 tsv 还原成 32 行（全国+31省）× 24 列的表。
用法：python3 -I parse.py <tsv> <out.csv>
列顺序同年鉴 xls 第1—24列：总指数、食品、7个食品子项、15个其他大类。
数值均为一位小数；识别丢小数点的 3—4 位整数补回小数点；超出 [50, 250] 的视为识别错误置缺。
"""
import re, sys
import numpy as np
import pandas as pd

ROWS = ["全国", "北京", "天津", "河北", "山西", "内蒙古", "辽宁", "吉林", "黑龙江", "上海", "江苏", "浙江", "安徽", "福建",
        "江西", "山东", "河南", "湖北", "湖南", "广东", "广西", "海南", "重庆", "四川", "贵州", "云南", "西藏", "陕西", "甘肃",
        "青海", "宁夏", "新疆"]
NCOL = int(sys.argv[3]) if len(sys.argv) > 3 else 24
tok_re = re.compile(r"^\d{2,4}(\.\d)?$")


def val(p):
    if "." not in p:
        if len(p) in (3, 4):
            p = p[:-1] + "." + p[-1]
        else:
            return np.nan
    v = float(p)
    return v if 50 <= v <= 250 else np.nan


t = pd.read_csv(sys.argv[1], sep="\t", header=None, names=["s", "x", "y", "w", "h"], quoting=3)
t["s"] = t.s.astype(str).str.replace("。", ".").str.replace("，", " ").str.replace(",", " ")
t["yc"] = t.y + t.h / 2
t["xc"] = t.x + t.w / 2

# 行：左侧省份标签，按 y 聚类去重后，从“全国”起向下取 32 行
lab = t[(t.x < 0.035) & ~t.s.str.contains(r"\d") & (t.s.str.len() <= 4) & (t.s.str.len() >= 2)]
LX = (lab.x + lab.w).quantile(0.9) + 0.001
quan = lab[lab.s.str.contains("全")]
if len(quan):
    top = quan.yc.max(); nrow = 32
else:  # 2015、2016 年版：上方为全国分年份行，省份从“北京”起，无全国行
    top = lab[lab.s.str.replace(" ", "").str.contains("北京")].yc.max(); nrow = 31
# 行位置取自数字块的 y 聚类（标签偶有漏识别），从“全国”所在高度起向下，须恰好 32 行
num = t[t.s.str.split().apply(lambda ps: bool(ps) and all(tok_re.match(p) for p in ps)) & (t.x >= LX)]
num = num[num.yc <= top + 0.006].sort_values("yc", ascending=False)
groups = []
for y in num.yc:
    if groups and abs(groups[-1][-1] - y) < 0.006:
        groups[-1].append(y)
    else:
        groups.append([y])
ys = [np.median(g) for g in groups if len(g) >= 5]
if len(ys) != nrow:
    sys.exit(f"数字行数 {len(ys)} != {nrow}")
rows_y = np.array(ys)
R0 = 32 - nrow  # 无全国行时从第 1 行（北京）起

cells = []
for r in t.itertuples():
    parts = r.s.split()
    if not parts or not all(tok_re.match(p) for p in parts) or r.x < LX:
        continue
    L = len(r.s); pos = 0
    for p in parts:
        i = r.s.index(p, pos); pos = i + len(p)
        cells.append((val(p), "." in p, r.x + r.w * (i + len(p) / 2) / L, r.yc))
c = pd.DataFrame(cells, columns=["v", "hasdot", "xc", "yc"])
gap = np.median(np.abs(np.diff(rows_y)))
d = np.abs(c.yc.to_numpy()[:, None] - rows_y[None, :])
c["row"] = d.argmin(1) + R0; c = c[d.min(1) < 0.4 * gap]
# 列：x 中心按间隙切成 24 段
xs = np.sort(c.xc.to_numpy())
gaps = np.diff(xs)
cut = np.sort(np.argsort(gaps)[-(NCOL - 1):])
edges = [(xs[i] + xs[i + 1]) / 2 for i in cut]
c["col"] = np.searchsorted(edges, c.xc.to_numpy())
# 同格多候选（分块重叠）：优先带小数点、再取众数；冲突计数
out = np.full((32, NCOL), np.nan); conflict = 0
for (r, k), g in c.dropna(subset=["v"]).groupby(["row", "col"]):
    g2 = g[g.hasdot] if g.hasdot.any() else g
    vals = g2.v.round(1)
    if vals.nunique() > 1:
        conflict += 1
    out[r, k] = vals.mode().iat[0]
tab = pd.DataFrame(out, index=ROWS, columns=range(1, NCOL + 1))
tab.to_csv(sys.argv[2])
print(f"{sys.argv[1]}: 缺格 {int(np.isnan(out).sum())}，候选冲突格 {conflict}，最小 {np.nanmin(out)}，最大 {np.nanmax(out)}")
