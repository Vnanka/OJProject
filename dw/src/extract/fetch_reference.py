"""
fetch_reference.py — download the real reference data for the OJ demo warehouse.

Saves each API response to dw/raw/api/ exactly as received (no changes):
    fx_rates.json        ECB daily reference rates via the Frankfurter API (no key needed)
    bank_holidays.json   UK bank holidays from gov.uk

The FX range starts at the CRM go-live (1 Oct 2022), so every invoice has a rate.

Standard library only.

Usage:
    python dw/src/extract/fetch_reference.py
"""

import json
from pathlib import Path
from urllib.request import Request, urlopen

DW_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = DW_ROOT / "raw" / "api"

FX_START, FX_END = "2022-10-01", "2026-09-12"
FX_CURRENCIES = ["EUR", "USD", "CHF", "HKD", "SGD", "MYR"]

SOURCES = {
    "fx_rates.json": (
        f"https://api.frankfurter.dev/v1/{FX_START}..{FX_END}"
        f"?base=GBP&symbols={','.join(FX_CURRENCIES)}"
    ),
    "bank_holidays.json": "https://www.gov.uk/bank-holidays.json",
}


def fetch(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "oj-demo-dw/1.0"})
    with urlopen(request, timeout=60) as response:
        return response.read()


def fetch_reference(out_dir: Path = OUT_DIR) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for filename, url in SOURCES.items():
        body = fetch(url)
        json.loads(body)  # fail loudly if the API did not return JSON
        (out_dir / filename).write_bytes(body)
        print(f"  [ok] {filename:<20} {len(body):>9,} bytes  <- {url}")


if __name__ == "__main__":
    fetch_reference()
