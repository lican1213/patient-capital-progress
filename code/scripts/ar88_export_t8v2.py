"""ar88_export_t8v2.py — 第四十七轮：新表8（导师清单版）所需变量，供交付。

规则见本 exploration README 第四十七轮。只合并已有中间数据：
  seg_m3l：20_表8时变变量.dta（ar85）；rd_t：目的省研发资源_逐年.dta（ar81）；d_cent、lngdpr：目的省逐年变量_ar86.dta（ar86）；
  mkt_t：市场化总指数当年值（同 mkt0 来源）。
输出（不入版控）：data/derived/advisor_send_20261008/21_表8新版变量.dta
运行：python3 explorations/advisor_revision_20261005/scripts/ar88_export_t8v2.py（项目根目录）
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
D = ROOT / "data/derived/advisor_send_20261008"
P16 = ROOT / "deliverables/advisor_package_20261007/稳健性异质性去向_20261009/16_主面板3_企业目的省年份.dta"
K = ["stkcd", "dest_id", "year"]
ints = lambda d: d.assign(**{c: d[c].astype(int) for c in K if c in d})
k = ints(pd.read_stata(P16, columns=K + ["dest"]))
v20 = ints(pd.read_stata(D / "20_表8时变变量.dta", columns=K + ["seg_m3l"]))
v86 = ints(pd.read_stata(D / "目的省逐年变量_ar86.dta", columns=K + ["d_cent", "lngdpr"]))
rd = pd.read_stata(D / "目的省研发资源_逐年.dta", columns=["dest", "year", "rd_t"]); rd["year"] = rd.year.astype(int)
mk = pd.read_stata("data/raw/price_index/1997-2024年市场化指数和各分项指数.dta", columns=["province_in", "year", "market"])
mk["year"] = mk.year.round().astype(int); mk = mk.rename(columns={"province_in": "dest", "market": "mkt_t"})
out = (k.merge(v20, on=K, how="left", validate="1:1").merge(v86, on=K, how="left", validate="1:1")
        .merge(rd, on=["dest", "year"], how="left", validate="m:1").merge(mk, on=["dest", "year"], how="left", validate="m:1"))
assert len(out) == len(k)
print("2015 年起缺失率", out[out.year >= 2015][["seg_m3l", "mkt_t", "rd_t", "d_cent", "lngdpr"]].isna().mean().round(4).to_dict())
out = out[K + ["seg_m3l", "mkt_t", "rd_t", "d_cent", "lngdpr"]]
out.to_stata(D / "21_表8新版变量.dta", write_index=False, version=118, variable_labels={
    "seg_m3l": "市场分割前三年均值（导师城市对指数，首年总部城市，省内等权，t-3至t-1）",
    "mkt_t": "目的省当年市场化总指数", "rd_t": "目的省当年研发资源 ln(1+上市公司发明专利申请量合计)",
    "d_cent": "目的省是否中部（国家统计局东中西三分）", "lngdpr": "ln(目的省当年GDP/母公司所在省当年GDP)"})
print(len(out), D / "21_表8新版变量.dta")
