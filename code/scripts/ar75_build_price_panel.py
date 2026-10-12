"""ar75_build_price_panel.py — 第三十五轮：省份×年份×16 类商品零售价格指数（上年=100）面板，2008—2022。

规则见本 exploration README 第三十五轮（运行前写定）。
来源：data/raw/source_snapshots/nbs_yearbook_retail_price_20261010/（统计年鉴 xls 与图片）；
  图片年份用 data/derived/prov_seg_20261010/ocr/final_<版次>.csv（scripts/ar75_ocr 三次分块识别、多数一致）。
  2021 年版 xls 与图片识别结果须逐格一致（识别方法检验）。
输出（不入版控）：data/derived/prov_seg_20261010/零售价格分类指数_省份年份.csv
运行：python3 explorations/advisor_revision_20261005/scripts/ar75_build_price_panel.py（项目根目录）
"""
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data/raw/source_snapshots/nbs_yearbook_retail_price_20261010"
OUT = ROOT / "data/derived/prov_seg_20261010"
PROV = ["北京", "天津", "河北", "山西", "内蒙古", "辽宁", "吉林", "黑龙江", "上海", "江苏", "浙江", "安徽", "福建", "江西",
        "山东", "河南", "湖北", "湖南", "广东", "广西", "海南", "重庆", "四川", "贵州", "云南", "西藏", "陕西", "甘肃", "青海",
        "宁夏", "新疆"]
# 年鉴第 2、10—24 列：16 类商品（食品子项不用）
GOODS = {2: "食品", 10: "饮料烟酒", 11: "服装鞋帽", 12: "纺织品", 13: "家用电器及音像器材", 14: "文化办公用品", 15: "日用品",
         16: "体育娱乐用品", 17: "交通通信用品", 18: "家具", 19: "化妆品", 20: "金银珠宝", 21: "中西药品及医疗保健用品",
         22: "书报杂志及电子出版物", 23: "燃料", 24: "建筑材料及五金电料"}
XLS = {2009: "ed2009_I0807C.xls", 2010: "ed2010_I0907C.xls", 2011: "ed2011_I0907C.xls", 2012: "ed2012_I0907C.xls",
       2013: "ed2013_Z1007C.xls", 2014: "ed2014_Z0507C.xls", 2021: "ed2021_C05-07.xls"}
OCR = [2015, 2016, 2017, 2018, 2019, 2020, 2022, 2023]


def read_xls(f):
    x = pd.read_excel(f, header=None)
    lab = x[0].astype(str).str.replace(r"\s+", "", regex=True)
    rows = {}
    for i, s in lab.items():
        if s in PROV and s not in rows:
            rows[s] = i
    miss = [p for p in PROV if p not in rows]
    assert not miss, f"{f.name} 缺省份 {miss}"
    t = x.loc[[rows[p] for p in PROV], list(GOODS)].apply(pd.to_numeric, errors="coerce")
    t.index = PROV
    t.columns = list(GOODS.values())
    return t


def read_ocr(ed):
    t = pd.read_csv(OUT / "ocr" / f"final_{ed}.csv", index_col=0).loc[PROV, [str(k) for k in GOODS]]
    t.columns = list(GOODS.values())
    return t


# 识别方法检验：2021 年版图片识别 vs xls
chk_x = read_xls(RAW / XLS[2021]).round(1)
chk_o = read_ocr(2021)
n_diff = int((~np.isclose(chk_x.to_numpy(), chk_o.to_numpy())).sum())
print("2021 年版：图片识别与 xls 比对 16 类×31 省，不一致格数", n_diff)
assert n_diff == 0

frames = []
for ed, f in XLS.items():
    frames.append(read_xls(RAW / f).assign(year=ed - 1, src="xls"))
for ed in OCR:
    frames.append(read_ocr(ed).assign(year=ed - 1, src="ocr"))
pan = pd.concat(frames).rename_axis("prov").reset_index()
long = pan.melt(id_vars=["prov", "year", "src"], var_name="good", value_name="p")
print("年份：", sorted(long.year.unique()))
print("缺失格：", int(long.p.isna().sum()), "；取值范围", long.p.min(), "—", long.p.max())
print(long.groupby("year").agg(src=("src", "first"), n=("p", "count"), mean=("p", "mean"), sd=("p", "std")).round(2).to_string())
assert long.groupby("year").p.count().eq(31 * 16).all()
long.to_csv(OUT / "零售价格分类指数_省份年份.csv", index=False)
print(OUT / "零售价格分类指数_省份年份.csv")
