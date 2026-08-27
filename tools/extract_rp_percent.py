"""Extract summary-row Performance % Complete values from two P6 RP PDFs."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from pypdf import PdfReader

DATE_RE = re.compile(r"\s\d{2}-[A-Z][a-z]{2}-\d{2}(?:\s|\*)")
PCT_RE = re.compile(r"(\d+(?:\.\d+)?)%\s*$")


def undupe_name(value: str) -> str:
    value = value.strip()
    for pos in range(1, len(value)):
        if value[pos] != " ":
            continue
        left, right = value[:pos].strip(), value[pos:].strip()
        if left == right:
            return left
    return value


def extract(path: Path) -> dict[str, float]:
    rows: dict[str, float] = {}
    area, level = "ALL", "ALL"
    for page in PdfReader(str(path)).pages:
        for raw in (page.extract_text() or "").splitlines():
            line = raw.strip()
            if not line[:1].isdigit() or "P1_" in line:
                continue
            pct = PCT_RE.search(line)
            date = DATE_RE.search(line)
            if not pct or not date:
                continue
            prefix = re.sub(r"^\d+\s+", "", line[: date.start()]).strip()
            name = undupe_name(prefix)
            if name in {"Existing Basement", "New Basement", "Marine"}:
                area, level = {"Existing Basement": "EB", "New Basement": "NB", "Marine": "MA"}[name], "ALL"
            elif name == "Basement 2":
                level = "B2"
            elif name == "Basement 1":
                level = "B1"
            elif name == "Marine Deck":
                level = "L1"
            elif re.fullmatch(r"Level [1-5](?: Transfer)?", name):
                level = "L" + re.search(r"[1-5]", name).group(0)
            rows[f"{area}|{level}|{name}"] = float(pct.group(1))
    return rows


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_rp_percent.py JUN.pdf SEP.pdf")
    june, sept = extract(Path(sys.argv[1])), extract(Path(sys.argv[2]))
    common = sorted(set(june) & set(sept))
    result = {
        name: {
            "jun": june[name],
            "sep": sept[name],
            "aug": round(max(0, min(100, june[name] + (sept[name] - june[name]) * 2 / 3)), 1),
        }
        for name in common
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
