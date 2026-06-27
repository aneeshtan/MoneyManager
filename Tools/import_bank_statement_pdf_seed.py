#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import tempfile
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Optional


TRANSACTION_RE = re.compile(r"^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(CR|DR)\s+([\d,]+(?:\.\d+)?)$")
CURRENCY_HEADER_RE = re.compile(r"\bAmount\s+in\s+([A-Z]{3})\b", re.IGNORECASE)
PDF_SOURCE_NAME = "PDF Import"
DEFAULT_ACCOUNT = "Credit Card"

LOCATION_SUFFIXES = (
    "DUBAI ARE",
    "DUBAI AE",
    "DUBAI",
    "ABU DHABI ARE",
    "ABU DHABI AE",
    "ABU DHABI",
    "RAS AL KHAIMA",
    "RAS AL-KHAIMA",
    "AJMAN",
    "SHARJAH",
    "UAE",
    "AE",
)

FALLBACK_RULES = (
    ("CAREEM HALA", "Transportation", "Taxi"),
    ("CAREEM RIDE", "Transportation", "Taxi"),
    ("CAREEM DELIVERIES", "Food", "Eating out"),
    ("CAREEM FOOD", "Food", "Eating out"),
    ("CAREEM QUIK", "Food", None),
    ("CAREEM PLUS", "Transportation", None),
    ("NATIONAL TAXI", "Transportation", "Taxi"),
    ("DUBAI TAXI", "Transportation", "Taxi"),
    ("DUBAI BOLT", "Transportation", "Taxi"),
    ("RTA-DUBAI METRO", "Transportation", "Subway"),
    ("DOTT SCOOTER", "Transportation", "Scooter"),
    ("DOTT PASS", "Transportation", "Scooter"),
    ("AMAZON GROCERY", "Food", None),
    ("AMAZON NOW", "Food", None),
    ("ALL DAY MARKET", "Food", None),
    ("WEST ZONE", "Food", None),
    ("VIVA", "Food", None),
    ("UNION COOP", "Food", None),
    ("AL MAYA", "Food", None),
    ("CARREFOUR", "Food", None),
    ("CHOITHRAM", "Food", None),
    ("SPINNEYS", "Food", None),
    ("HALAL MINI MART", "Food", None),
    ("AL BONDOQ", "Food", "Fruit"),
    ("NOON FOOD", "Food", "Eating out"),
    ("AFRINA SWEETS", "Food", "Eating out"),
    ("TIM HORTONS", "Food", "Eating out"),
    ("COTTI COFFEE", "Food", "Eating out"),
    ("HUNGRY JACKS", "Food", "Eating out"),
    ("THE VILLA RESTAURANT", "Food", "Eating out"),
    ("LAUNDRY", "Apparel", "Laundry"),
    ("AGODA", "Travel", None),
    ("BOOKING", "Travel", None),
    ("ROVE", "Travel", None),
    ("ADNOC", "Car", "Petrol"),
    ("EMARAT", "Car", "Petrol"),
    ("SALIK", "Car", "Salik"),
    ("SMART DUBAI GOVERNMENT", "Car", "Salik"),
    ("IKEA", "Household", None),
    ("JUSTLIFE", "Household", None),
    ("DAY TO DAY", "Household", None),
    ("AVENUE BY DAY TO DAY", "Household", None),
    ("NOON.COM", "Household", None),
    ("AMAZON.AE", "Household", None),
    ("TEMU", "Household", None),
    ("GIFTS VILLAGE", "Gift", None),
    ("GROUPON", "Entertainment", None),
    ("VOX CINEMAS", "Entertainment", "Movie"),
    ("MATOVI DIGITAL", "Internet", "Subscription"),
    ("AMAZON PRIME", "Entertainment", "Subscription"),
    ("TABBY", "to return shopping", None),
    ("THE BALLET CENTRE", "Academy", "Classes"),
    ("YO FIT", "Academy", "Yoga"),
)


def extract_pdf_text(pdf_path: Path) -> str:
    swift = f"""
import Foundation
import PDFKit
let url = URL(fileURLWithPath: {json.dumps(str(pdf_path))})
guard let doc = PDFDocument(url: url) else {{ fatalError("unreadable pdf") }}
for i in 0..<doc.pageCount {{
    if let text = doc.page(at: i)?.string {{
        print(text)
    }}
}}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as script:
        script.write(swift)
        script_path = Path(script.name)
    try:
        result = subprocess.run(["swift", str(script_path)], check=True, capture_output=True, text=True)
        return result.stdout
    finally:
        script_path.unlink(missing_ok=True)


def normalize_merchant(value: str) -> str:
    text = re.sub(r"\s+", " ", str(value or "")).strip().upper()
    text = re.sub(r"CR\.?CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*", "", text)
    text = re.sub(r"CARD\s*XXX\d+\s*USED\s*FOR\s*[A-Z]{3}[\d,.]+\s*AT\s*", "", text)
    text = re.sub(r"CRCARDXXX\d+USED", "", text)
    text = re.sub(r"CARDXXX\d+USED", "", text)
    text = re.sub(r"\(\+\d+(?:\.\d+)?%[^)]*\)", "", text)
    text = re.sub(r"AVL\.?\s*CR\.?\s*LIMIT(?:\s*IS)?\s*[A-Z]{3}[\d,.]+", "", text)
    text = re.sub(r"AVLCRLIMIT(?:IS)?[A-Z]{3}[\d,.]+", "", text)
    text = re.sub(r"[^A-Z0-9&%+./ -]", " ", text)
    text = re.sub(r"\s+", " ", text).strip(" -,.")
    changed = True
    while changed:
        changed = False
        for suffix in LOCATION_SUFFIXES:
            if text.endswith(" " + suffix):
                text = text[: -len(suffix)].strip(" -,.")
                changed = True
            if text.endswith("-" + suffix):
                text = text[: -len(suffix)].strip(" -,.")
                changed = True
    return text


def category_match(normalized: str, rules: list[dict], fallback_kind: str) -> tuple[str, Optional[str], str]:
    normalized = normalize_merchant(normalized)
    sorted_rules = sorted(rules, key=lambda item: (-int(item.get("sampleCount") or 0), -len(item.get("pattern") or "")))
    for rule in sorted_rules:
        pattern = normalize_merchant(rule.get("pattern", ""))
        if not pattern:
            continue
        if normalized == pattern or normalized in pattern or pattern in normalized:
            return rule.get("category") or "", rule.get("subcategory"), rule.get("kind") or fallback_kind

    for pattern, category, subcategory in FALLBACK_RULES:
        if pattern in normalized:
            return category, subcategory, fallback_kind
    return "", None, fallback_kind


def is_review_only(normalized: str) -> bool:
    return any(
        marker in normalized
        for marker in (
            "PAYMENT RECEIVED",
            "CASHBACK",
            "FOREIGN TRANSACTION FEE",
            "VAT ON FOREIGN",
        )
    )


def parse_pdf_transactions(text: str, rules: list[dict]) -> list[dict]:
    currency_match = CURRENCY_HEADER_RE.search(text)
    currency = currency_match.group(1).upper() if currency_match else "USD"
    rows = []
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        match = TRANSACTION_RE.match(line)
        if not match:
            continue

        date_text, description, direction, amount_text = match.groups()
        date = datetime.strptime(date_text, "%d/%m/%Y")
        amount = Decimal(amount_text.replace(",", ""))
        kind = "income" if direction == "CR" else "expense"
        normalized = normalize_merchant(description)
        category, subcategory, matched_kind = category_match(normalized, rules, kind)

        rows.append(
            {
                "sourceName": PDF_SOURCE_NAME,
                "sourceRow": line_number,
                "date": date.isoformat(),
                "periodSerial": "",
                "account": DEFAULT_ACCOUNT,
                "category": category,
                "subcategory": subcategory,
                "note": description,
                "aed": str(amount),
                "incomeExpense": "Income" if matched_kind == "income" else "Exp.",
                "description": description,
                "amount": str(amount),
                "currency": currency,
                "accountsTrailing": "",
                "kind": matched_kind,
                "merchant": description,
                "normalizedMerchant": normalized,
                "_reviewOnly": is_review_only(normalized),
            }
        )
    return rows


def dedupe_seed_transactions(seed: dict, parsed_rows: list[dict]) -> tuple[list[dict], int, int, int]:
    existing_keys = set()
    existing_pdf_rows = 0
    for transaction in seed.get("initialTransactions", []):
        if transaction.get("sourceName") == PDF_SOURCE_NAME:
            existing_pdf_rows += 1
            continue
        key = (
            transaction.get("account") or DEFAULT_ACCOUNT,
            (transaction.get("date") or "")[:10],
            str(Decimal(str(transaction.get("amount") or transaction.get("aed") or "0"))),
            transaction.get("normalizedMerchant") or normalize_merchant(transaction.get("merchant") or transaction.get("note") or ""),
        )
        existing_keys.add(key)

    imported = []
    skipped_duplicates = 0
    skipped_review_only = 0
    seen_pdf_keys = set()
    for transaction in parsed_rows:
        if transaction.get("_reviewOnly"):
            skipped_review_only += 1
            continue
        key = (
            transaction.get("account") or DEFAULT_ACCOUNT,
            transaction["date"][:10],
            str(Decimal(transaction["amount"])),
            transaction["normalizedMerchant"],
        )
        if key in existing_keys or key in seen_pdf_keys:
            skipped_duplicates += 1
            continue
        seen_pdf_keys.add(key)
        transaction.pop("_reviewOnly", None)
        imported.append(transaction)

    seed["initialTransactions"] = [
        transaction
        for transaction in seed.get("initialTransactions", [])
        if transaction.get("sourceName") != PDF_SOURCE_NAME
    ] + imported
    return imported, skipped_duplicates, skipped_review_only, existing_pdf_rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", required=True, type=Path)
    parser.add_argument("--seed", required=True, type=Path)
    args = parser.parse_args()

    seed = json.loads(args.seed.read_text())
    text = extract_pdf_text(args.pdf)
    parsed = parse_pdf_transactions(text, seed.get("merchantRules", []))
    review_only = sum(1 for row in parsed if row.get("_reviewOnly"))
    imported, skipped_duplicates, skipped_review_only, replaced_pdf_rows = dedupe_seed_transactions(seed, parsed)
    args.seed.write_text(json.dumps(seed, ensure_ascii=False, indent=2) + "\n")

    uncategorized = sum(1 for row in imported if not row.get("category"))
    print(f"Parsed {len(parsed)} PDF transactions")
    print(f"Replaced {replaced_pdf_rows} previous PDF seed transactions")
    print(f"Imported {len(imported)} new PDF transactions into {args.seed}")
    print(f"Skipped {skipped_duplicates} duplicates already present in seed data")
    print(f"Skipped {skipped_review_only} review-only rows from the seeded import")
    print(f"Review-only rows in PDF: {review_only}")
    print(f"Imported uncategorized rows: {uncategorized}")


if __name__ == "__main__":
    main()
