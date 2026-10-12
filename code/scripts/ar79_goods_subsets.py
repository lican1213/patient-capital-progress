"""ar79_goods_subsets.py — 第三十九轮：按近年文献的商品类别，从 16 类零售价格面板取子集，另存面板。

规则见本 exploration README 第三十九轮（运行前写定）。
输入：data/derived/prov_seg_20261010/零售价格分类指数_省份年份.csv（第三十五轮）
输出（不入版控）：data/derived/prov_seg_20261010/零售价格_<口径>.csv；随后各跑一次
  python3 explorations/advisor_revision_20261005/scripts/ar75_build_prov_seg.py 零售价格_<口径>.csv _<口径>
运行：python3 explorations/advisor_revision_20261005/scripts/ar79_goods_subsets.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data/derived/prov_seg_20261010"
ALL16 = ["食品", "饮料烟酒", "服装鞋帽", "纺织品", "家用电器及音像器材", "文化办公用品", "日用品", "体育娱乐用品", "交通通信用品",
         "家具", "化妆品", "金银珠宝", "中西药品及医疗保健用品", "书报杂志及电子出版物", "燃料", "建筑材料及五金电料"]
SUB = {
    "k15": [g for g in ALL16 if g != "金银珠宝"],                                     # 三篇近年文献均不含金银珠宝
    "k8h": ["食品", "饮料烟酒", "服装鞋帽", "家用电器及音像器材", "日用品", "中西药品及医疗保健用品",
            "书报杂志及电子出版物", "燃料"],                                           # 黄赜琳、姚婷婷（2020）
    "k12l": [g for g in ALL16 if g not in ("金银珠宝", "文化办公用品", "体育娱乐用品", "家具")],  # 吕越、张昊天（2021）
    "k9w": ["纺织品", "服装鞋帽", "化妆品", "家用电器及音像器材", "建筑材料及五金电料", "食品",
            "书报杂志及电子出版物", "饮料烟酒", "中西药品及医疗保健用品"],                   # 吴华强等（2022），缺粮食子项
    "k13": [g for g in ALL16 if g not in ("金银珠宝", "燃料", "中西药品及医疗保健用品")],     # 作者设想，无文献依据，只作对照
}
pan = pd.read_csv(OUT / "零售价格分类指数_省份年份.csv")
assert set(pan.good) == set(ALL16)
for k, gs in SUB.items():
    assert set(gs) <= set(ALL16)
    sub = pan[pan.good.isin(gs)]
    assert sub.good.nunique() == len(gs)
    sub.to_csv(OUT / f"零售价格_{k}.csv", index=False)
    print(k, len(gs), "类：", "、".join(gs))
