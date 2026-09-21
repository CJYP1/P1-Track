#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build fixed/zone-activity/L5.csv from the approved L5 monthly schedule.

The monthly rows and Zone ownership come from data-csv/work/L5.csv.  Quantities
and activity dates come from the original detailed schedule workbook.  This
keeps the website's L5 report aligned with the same source used for L3/L4 while
avoiding old L2/L3 slab stages that also happen to be labelled as level L5 in
the source workbook.
"""
from __future__ import annotations

import calendar
import csv
import math
import re
from collections import defaultdict
from datetime import date
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "data-csv" / "work" / "L5.csv"
OUT = ROOT / "data-csv" / "fixed" / "zone-activity" / "L5.csv"
SOURCE = next((ROOT / "data-csv" / "source").glob("*.xlsx"))

FIELDS = ["楼层", "分区", "活动", "活动名称(参考)", "月份", "计划量", "完成量", "活动开始", "活动结束"]
MONTHS = {
    "January": "Jan", "February": "Feb", "March": "Mar", "April": "Apr",
    "May": "May", "June": "Jun", "July": "Jul", "August": "Aug",
    "September": "Sep", "October": "Oct", "November": "Nov", "December": "Dec",
}
MONTH_NUM = {name: i for i, name in enumerate(MONTHS, 1)}
LABELS = {
    "col": "Column", "act_colcorbel": "Column Corbel", "mbeam": "Steel Main Beam",
    "cbeam": "Cast Steel Main Beam", "act_corewall": "Core Wall",
    "ls": "Lift/Stair Wall", "slab": "Slab",
}


def zone_norm(value: object) -> str:
    s = str(value or "").strip().upper().replace("POD", "").replace("P-", "")
    return s.replace("CIS-T", "CIST").replace("-T", "T").replace(" ", "")


def activity_id(trade: str, name: str) -> str | None:
    if trade == "COL":
        return "act_colcorbel" if "cobel" in name.lower() else "col"
    return {"STB": "mbeam", "MBR": "cbeam", "CRW": "act_corewall", "WAL": "ls", "SLB": "slab"}.get(trade)


def work_activity(name: str) -> str | None:
    if "Corbel" in name: return "act_colcorbel"
    if "Core Wall" in name: return "act_corewall"
    if "Lift/Stair" in name: return "ls"
    if "Columns" in name: return "col"
    if "Steel Beam" in name: return "mbeam"
    if "Main Beam" in name: return "cbeam"
    if "Slab" in name: return "slab"
    return None


def month_key(label: str) -> tuple[int, int, str]:
    name, year = label.split()
    y, m = int(year), MONTH_NUM[name]
    return y, m, f"{MONTHS[name]}'{str(y)[2:]}"


def parse_quantity(value: object) -> float | None:
    m = re.search(r"([\d,.]+)\s*(?:m²|㎡|nos)", str(value or ""))
    return float(m.group(1).replace(",", "")) if m else None


def as_date(value: object) -> date | None:
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value or "").strip()[:10])
    except ValueError:
        return None


def month_overlap(start: date, finish: date, year: int, month: int) -> int:
    a = max(start, date(year, month, 1))
    b = min(finish, date(year, month, calendar.monthrange(year, month)[1]))
    return max(0, (b - a).days + 1)


def main() -> None:
    with open(WORK, encoding="utf-8-sig") as f:
        work_rows = list(csv.DictReader(f))

    requested: dict[tuple[str, str, str], list[tuple[int, int, str]]] = defaultdict(list)
    for row in work_rows:
        aid = work_activity(row["工作项"])
        if not aid:
            raise SystemExit(f"Unknown L5 work item: {row['工作项']}")
        y, m, mon = month_key(row["月份"])
        requested[(row["大区"], zone_norm(row["小区"]), aid)].append((y, m, mon))

    wb = openpyxl.load_workbook(SOURCE, data_only=True, read_only=True)
    source_rows: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    sheets = [("3_EB_逐条", "EB"), ("4_NB_逐条", "NB"), ("5_MA_逐条", "MA")]
    eb_l5_zone = {
        "P1_CN_12170": "4.2T", "P1_CN_12200": "4.2", "P1_CN_12330": "4.3",
        "P1_CN_12290": "4.4", "P1_CN_12260": "4.1CIS", "P1_CN_12230": "4.1CIST",
        "P1_CN_12220": "4.1", "P1_CN_12210": "4.1",
    }
    for sheet_name, area in sheets:
        for values in wb[sheet_name].iter_rows(min_row=4, values_only=True):
            level, zone, trade, item_id, name, qty, start, finish = (list(values) + [None] * 8)[:8]
            level, trade, name = str(level or "").strip(), str(trade or "").strip(), str(name or "")
            use_transition = level == "L4" and trade in {"COL", "STB", "MBR", "CRW", "WAL"}
            use_l5 = level == "L5" and "at L5 Zone" in name
            start, finish = as_date(start), as_date(finish)
            if not (use_transition or use_l5) or start is None or finish is None:
                continue
            aid = activity_id(trade, name)
            if not aid:
                continue
            z = zone_norm(zone)
            if use_l5 and area == "EB":
                z = eb_l5_zone.get(str(item_id), z)
            key = (area, z, aid)
            if key not in requested:
                continue
            source_rows[key].append({"qty": parse_quantity(qty), "start": start, "finish": finish})

    missing = sorted(set(requested) - set(source_rows))
    if missing:
        raise SystemExit("No source schedule match for: " + ", ".join("/".join(x) for x in missing))

    allocated: dict[tuple[str, str, str, str], float | None] = {}
    dates: dict[tuple[str, str, str, str], tuple[date, date]] = {}
    for key, months in requested.items():
        months = sorted(set(months))
        for y, m, mon in months:
            hits = [r for r in source_rows[key] if month_overlap(r["start"], r["finish"], y, m)]
            if hits:
                dates[key + (mon,)] = (min(r["start"] for r in hits), max(r["finish"] for r in hits))
        month_values = {mon: 0.0 for _, _, mon in months}
        month_known = {mon: False for _, _, mon in months}
        for src in source_rows[key]:
            q = src["qty"]
            overlaps = [(mon, month_overlap(src["start"], src["finish"], y, m)) for y, m, mon in months]
            overlaps = [(mon, days) for mon, days in overlaps if days]
            if q is None or not overlaps:
                continue
            total_days = sum(days for _, days in overlaps)
            raw = [(mon, q * days / total_days) for mon, days in overlaps]
            if float(q).is_integer():
                base = {mon: math.floor(v) for mon, v in raw}
                remain = int(round(q - sum(base.values())))
                for mon, _ in sorted(raw, key=lambda x: (-(x[1] - math.floor(x[1])), months.index(next(t for t in months if t[2] == x[0]))))[:remain]:
                    base[mon] += 1
                raw = list(base.items())
            for mon, value in raw:
                month_values[mon] += value
                month_known[mon] = True
        for _, _, mon in months:
            allocated[key + (mon,)] = round(month_values[mon], 2) if month_known[mon] else None

    output = []
    for row in work_rows:
        aid = work_activity(row["工作项"])
        _, _, mon = month_key(row["月份"])
        key = (row["大区"], zone_norm(row["小区"]), aid)
        qty = allocated.get(key + (mon,))
        if qty is not None and float(qty).is_integer(): qty = int(qty)
        d = dates.get(key + (mon,))
        if not d:
            all_src = source_rows[key]
            d = (min(x["start"] for x in all_src), max(x["finish"] for x in all_src))
        output.append({
            "楼层": "L5", "分区": f"L5|{key[1]}", "活动": aid,
            "活动名称(参考)": LABELS[aid], "月份": mon,
            "计划量": "" if qty is None else qty, "完成量": "",
            "活动开始": d[0].isoformat(), "活动结束": d[1].isoformat(),
        })

    with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader(); writer.writerows(output)
    print(f"L5 activity schedule: {len(output)} rows -> {OUT}")


if __name__ == "__main__":
    main()
