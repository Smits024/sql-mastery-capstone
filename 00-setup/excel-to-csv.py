"""Convert the two Excel-sourced datasets into CSV.

The UCI Online Retail file and Tableau's Superstore sample both ship as Excel
workbooks, which are awkward to bulk-load into SQL. This flattens them to CSV.
Superstore has three sheets, so it produces three files.

    pip install pandas openpyxl xlrd
    python 00-setup/excel-to-csv.py
"""

from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / "data"


def convert_online_retail() -> None:
    src = DATA / "online-retail" / "Online Retail.xlsx"
    if not src.exists():
        print(f"skip  {src.name} not found, run fetch-data.ps1 first")
        return
    df = pd.read_excel(src, engine="openpyxl")
    out = DATA / "online-retail" / "online-retail.csv"
    df.to_csv(out, index=False, encoding="utf-8")
    print(f"wrote {out.name}  {len(df):,} rows")


def convert_superstore() -> None:
    src = DATA / "superstore" / "sample-superstore.xls"
    if not src.exists():
        print(f"skip  {src.name} not found, run fetch-data.ps1 first")
        return
    for name, sheet in pd.read_excel(src, sheet_name=None, engine="xlrd").items():
        slug = name.strip().lower().replace(" ", "-")
        out = DATA / "superstore" / f"superstore-{slug}.csv"
        sheet.to_csv(out, index=False, encoding="utf-8")
        print(f"wrote {out.name}  {len(sheet):,} rows")


if __name__ == "__main__":
    convert_online_retail()
    convert_superstore()
