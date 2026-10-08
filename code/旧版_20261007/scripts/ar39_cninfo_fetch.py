"""ar39_cninfo_fetch.py — 从巨潮资讯下载样本企业的年度报告 PDF（LMDA 自建第一步）。

计划：quality_reports/plans/2026-10-07_lmda_build.md
样本：导师主面板的 stkcd × year（2014—2024），第 t 年对应 t 年度报告（t+1 年披露）。
规则：标题含“{t}年”与“年度报告”；剔除摘要、英文版、已取消、半年度；同一年度有多份时取最后披露的一份（更正或修订版）。
输出：data/raw/annual_reports/{stkcd6}_{year}.pdf；清单 data/raw/annual_reports/_manifest.csv（每个企业-年的状态，可断点续跑）。
运行：python3 explorations/advisor_revision_20261005/scripts/ar39_cninfo_fetch.py [--limit N] [--workers 4]（项目根目录）
"""
import argparse
import csv
import random
import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[3]
PANEL = Path("data/mentor_panel/主面板_含区位熵_地理IV_创新指标.dta")
OUT = ROOT / "data/raw/annual_reports"
MAN = OUT / "_manifest.csv"
API = "http://www.cninfo.com.cn/new/hisAnnouncement/query"
SEARCH = "http://www.cninfo.com.cn/new/information/topSearch/query"
STATIC = "http://static.cninfo.com.cn/"
HDR = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36",
       "Accept": "application/json, text/plain, */*", "X-Requested-With": "XMLHttpRequest"}
BAD = re.compile(r"摘要|英文|English|已取消|取消|半年度|季度|说明|提示|公告|问询|回复|更正说明|补充说明")
lock = threading.Lock()


def post(url, data, tries=4):
    for k in range(tries):
        try:
            r = requests.post(url, data=data, headers=HDR, timeout=30)
            r.raise_for_status()
            return r.json()
        except Exception:
            time.sleep(2 + 3 * k + random.random())
    return None


def org_id(code):
    js = post(SEARCH, {"keyWord": code, "maxNum": 5}) or []
    for it in js:
        if it.get("code") == code and it.get("category") == "A股":
            return it.get("orgId"), it.get("type")
    return (js[0].get("orgId"), js[0].get("type")) if js else (None, None)


def reports(code, oid, years):
    """一次取该股票全部年度报告公告，返回 {年度: (标题, 地址, 披露时间)}。"""
    col = "sse" if code.startswith("6") else "bj" if code[0] in "48" else "szse"
    lo, hi = min(years) + 1, max(years) + 2
    found, page = {}, 1
    while True:
        js = post(API, {"stock": f"{code},{oid}", "tabName": "fulltext", "pageSize": 30, "pageNum": page,
                        "column": col, "category": "category_ndbg_szsh", "seDate": f"{lo}-01-01~{hi}-12-31",
                        "isHLtitle": "true"})
        if not js:
            return None
        for a in js.get("announcements") or []:
            title = re.sub(r"<.*?>", "", a.get("announcementTitle", ""))
            m = re.search(r"(20\d\d)\s*年", title)
            if not m or "年度报告" not in title or BAD.search(title.replace("年度报告", "")):
                continue
            y = int(m.group(1))
            if y in years:
                t = a.get("announcementTime", 0)
                if y not in found or t > found[y][2]:
                    found[y] = (title, a.get("adjunctUrl"), t)
        if not js.get("hasMore"):
            break
        page += 1
        time.sleep(0.3)
    return found


def write_rows(rows):
    with lock:
        new = not MAN.exists()
        with MAN.open("a", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["stkcd", "year", "status", "title", "url", "bytes"])
            w.writerows(rows)


def one_firm(code, years, done):
    todo = [y for y in years if (code, y) not in done]
    if not todo:
        return
    oid, _ = org_id(code)
    if not oid:
        write_rows([[code, y, "no_orgid", "", "", 0] for y in todo])
        return
    found = reports(code, oid, set(todo))
    if found is None:
        write_rows([[code, y, "query_failed", "", "", 0] for y in todo])
        return
    rows = []
    for y in todo:
        if y not in found:
            rows.append([code, y, "not_found", "", "", 0])
            continue
        title, url, _ = found[y]
        dest = OUT / f"{code}_{y}.pdf"
        ok = dest.exists() and dest.stat().st_size > 10000
        for k in range(4):
            if ok:
                break
            try:
                r = requests.get(STATIC + url, headers=HDR, timeout=120)
                r.raise_for_status()
                dest.write_bytes(r.content)
                ok = r.content[:4] == b"%PDF"
            except Exception:
                time.sleep(3 + 3 * k)
        rows.append([code, y, "ok" if ok else "download_failed", title, url, dest.stat().st_size if dest.exists() else 0])
        time.sleep(0.4 + random.random() * 0.4)
    write_rows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="只跑前 N 家企业（试跑）")
    ap.add_argument("--workers", type=int, default=4)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    p = pd.read_stata(PANEL, columns=["stkcd", "year"]).dropna()
    p["code"] = p.stkcd.astype(int).map(lambda x: f"{x:06d}")
    p["year"] = p.year.astype(int)
    firms = p.groupby("code").year.apply(lambda s: sorted(set(s))).to_dict()
    codes = sorted(firms)[: a.limit] if a.limit else sorted(firms)
    done = set()
    if MAN.exists():
        m = pd.read_csv(MAN, dtype={"stkcd": str})
        done = {(c, int(y)) for c, y, s in zip(m.stkcd, m.year, m.status) if s == "ok"}
    print(f"企业 {len(codes)}，已完成企业-年 {len(done)}", flush=True)
    t0 = time.time()
    with ThreadPoolExecutor(a.workers) as ex:
        futs = {ex.submit(one_firm, c, firms[c], done): c for c in codes}
        for i, f in enumerate(as_completed(futs), 1):
            f.result()
            if i % 50 == 0 or i == len(codes):
                print(f"{i}/{len(codes)} 家，用时 {time.time() - t0:.0f} 秒", flush=True)


if __name__ == "__main__":
    main()
