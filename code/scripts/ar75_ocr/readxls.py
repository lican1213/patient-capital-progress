"""按省名读取年鉴 xls（分地区商品零售价格分类指数），输出 32 行 × 24 列（列 1—24 同 parse.py）。
用法：python3 -I readxls.py <xls> <out.csv>"""
import re, sys
import pandas as pd
exec(open(__file__.replace("readxls.py","parse_rows.py")).read())

x = pd.read_excel(sys.argv[1], header=None)
lab = x[0].astype(str).str.replace(r"\s+", "", regex=True)
rows = {}
for i, s in lab.items():
    for r in ROWS:
        if s == r and r not in rows:
            rows[r] = i
miss = [r for r in ROWS if r not in rows]
if miss:
    sys.exit(f"缺行 {miss}")
tab = x.loc[[rows[r] for r in ROWS], 1:24].apply(pd.to_numeric, errors="coerce")
tab.index = ROWS
tab.to_csv(sys.argv[2])
print(sys.argv[1], "缺格", int(tab.isna().sum().sum()))
