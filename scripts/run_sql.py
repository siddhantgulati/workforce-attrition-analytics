"""
Runs the SQL scripts in sql/ against a local SQLite copy of the data and
saves every named query result to outputs/ as CSV.

This is the quick way to reproduce the analysis without installing MySQL.
The queries are written to run unchanged on MySQL 8 as well (use
sql/00_load_mysql.sql to load the data there).

Usage:  python scripts/run_sql.py
"""

import csv
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "ibm_hr_attrition.csv"
SQL_DIR = ROOT / "sql"
OUT_DIR = ROOT / "outputs"
SCRIPTS = ["01_schema.sql", "02_data_checks.sql", "03_headcount.sql",
           "04_attrition_drivers.sql", "05_flight_risk.sql"]


def load_staging(con: sqlite3.Connection) -> int:
    with open(DATA, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    header, body = rows[0], rows[1:]
    cols = ", ".join(f'"{c}"' for c in header)
    con.execute("DROP TABLE IF EXISTS hr_raw")
    con.execute(f"CREATE TABLE hr_raw ({cols})")
    placeholders = ", ".join("?" for _ in header)
    # store numbers as numbers so comparisons and averages behave like MySQL
    typed = [[int(v) if v.lstrip("-").isdigit() else v for v in r] for r in body]
    con.executemany(f"INSERT INTO hr_raw VALUES ({placeholders})", typed)
    return len(body)


def statements(sql: str):
    """Yield (name, statement) pairs. Named queries start with '-- name: x'."""
    # Drop full-line comments first (they can contain semicolons), but keep
    # the query names as markers
    lines = []
    for line in sql.splitlines():
        m = re.match(r"\s*--\s*name:\s*(\w+)", line)
        if m:
            lines.append(f"@@{m.group(1)}")
        elif not line.strip().startswith("--"):
            lines.append(line)
    for chunk in "\n".join(lines).split(";"):
        m = re.search(r"@@(\w+)", chunk)
        code = re.sub(r"@@\w+", "", chunk).strip()
        if code:
            yield (m.group(1) if m else None), code


def main():
    OUT_DIR.mkdir(exist_ok=True)
    con = sqlite3.connect(":memory:")
    print(f"loaded {load_staging(con)} rows into hr_raw")

    for script in SCRIPTS:
        print(f"\n== {script}")
        for name, stmt in statements((SQL_DIR / script).read_text(encoding="utf-8")):
            cur = con.execute(stmt)
            if name is None:
                continue
            headers = [d[0] for d in cur.description]
            rows = cur.fetchall()
            with open(OUT_DIR / f"{script[:2]}_{name}.csv", "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(headers)
                w.writerows(rows)
            print(f"   {name:<34} {len(rows):>4} rows")
    con.commit()


if __name__ == "__main__":
    main()
