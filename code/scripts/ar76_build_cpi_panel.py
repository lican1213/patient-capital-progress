"""ar76_build_cpi_panel.py — 第三十六轮：省份×年份×居民消费价格 8 大类指数（上年=100）面板，2008—2024。

规则见本 exploration README 第三十六轮（运行前写定）。
xls（2009—2014、2021 年版）直接读；图片年份用 data/derived/prov_seg_20261010/ocr_cpi/cfinal_<版次>.csv
  （scripts/ar75_ocr/parse_c.py：数字列按横向位置聚类、列数须等于该年代标准列数，多种分块多数一致；
  2021 年版图片与 xls 九列 288 格逐格一致；每省总指数须落在 8 大类最小、最大值之间）。
2016 年起统计分类调整，每年用当年 8 大类，不做拼接。
输出（不入版控）：data/derived/prov_seg_20261010/居民消费价格8类_省份年份.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar76_build_cpi_panel.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data/raw/source_snapshots/nbs_yearbook_cpi_category_20261010"
OUT = ROOT / "data/derived/prov_seg_20261010"
PROV = ["北京", "天津", "河北", "山西", "内蒙古", "辽宁", "吉林", "黑龙江", "上海", "江苏", "浙江", "安徽", "福建", "江西",
        "山东", "河南", "湖北", "湖南", "广东", "广西", "海南", "重庆", "四川", "贵州", "云南", "西藏", "陕西", "甘肃", "青海",
        "宁夏", "新疆"]
LAY = {63: [1, 2, 13, 16, 21, 27, 39, 49, 59], 61: [1, 2, 23, 29, 33, 40, 47, 56, 59]}
XLS = {2009: ("ed2009_I0806C.xls", 63), 2010: ("ed2010_I0906C.xls", 63), 2011: ("ed2011_I0906C.xls", 63),
       2012: ("ed2012_I0906C.xls", 63), 2013: ("ed2013_Z1006C.xls", 63), 2014: ("ed2014_Z0506C.xls", 63),
       2021: ("ed2021_C05-06.xls", 61)}
IMG = [2015, 2016, 2017, 2018, 2019, 2020, 2022, 2023, 2024, 2025]
COLS = ["总指数"] + [f"c{k}" for k in range(1, 9)]


def read_xls(f, nc):
    x = pd.read_excel(f, header=None)
    lab = x[0].astype(str).str.replace(r"\s+", "", regex=True)
    rows = {}
    for i, s in lab.items():
        if s in PROV and s not in rows:
            rows[s] = i
    assert len(rows) == 31, f"{f.name} 缺省份"
    t = x.loc[[rows[p] for p in PROV], LAY[nc]].apply(pd.to_numeric, errors="coerce")
    t.index = PROV; t.columns = COLS
    return t


chk = read_xls(RAW / XLS[2021][0], 61).round(1)
img = pd.read_csv(OUT / "ocr_cpi" / "cfinal_2021.csv", index_col=0).loc[PROV, COLS]
n_diff = int((~np.isclose(chk.to_numpy(), img.to_numpy())).sum())
print("2021 年版：图片识别与 xls 比对 9 列×31 省，不一致格数", n_diff)
assert n_diff == 0
frames = [read_xls(RAW / f, nc).assign(year=ed - 1, src="xls") for ed, (f, nc) in XLS.items()]
frames += [pd.read_csv(OUT / "ocr_cpi" / f"cfinal_{ed}.csv", index_col=0).loc[PROV, COLS].assign(year=ed - 1, src="ocr") for ed in IMG]
pan = pd.concat(frames).rename_axis("prov").reset_index()
assert pan[COLS].notna().all().all(), "有缺格"
lo, hi = pan[COLS[1:]].min(axis=1), pan[COLS[1:]].max(axis=1)
viol = pan[(pan.总指数 < lo - 0.05) | (pan.总指数 > hi + 0.05)]
print("总指数越出 8 类范围的省年：", len(viol), viol[["prov", "year", "src"]].values.tolist())
long = pan.melt(id_vars=["prov", "year", "src"], value_vars=COLS[1:], var_name="good", value_name="p")
print(long.groupby("year").agg(src=("src", "first"), n=("p", "count"), mean=("p", "mean"), sd=("p", "std")).round(2).to_string())
assert long.groupby("year").p.count().eq(31 * 8).all()
long.to_csv(OUT / "居民消费价格8类_省份年份.csv", index=False)
print(OUT / "居民消费价格8类_省份年份.csv")
