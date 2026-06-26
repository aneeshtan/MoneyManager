# AI Money Manager

Native SwiftUI personal finance app for replacing SMS-based Money Manager tracking with review-first ADCB PDF statement imports.

## What is implemented

- SwiftUI iOS app with SwiftData local persistence.
- Seeded accounts, categories, and merchant rules generated from the local Money Manager backup and Excel export.
- ADCB credit-card PDF import with PDFKit parsing.
- Import review screen with duplicate detection, review-only defaults for payments/cashback/fees, category editing, and bulk save.
- Transaction list/editor, dashboard, accounts, category/rule browser, and CSV/JSON export.

## Regenerate seed data

Raw bank files should stay outside the repo. Regenerate sanitized seed data with:

```bash
python3 Tools/generate_seed_data.py \
  --backup /Users/farshad.ghanzanfari/Downloads/20260610_214641_AD.mmbak \
  --xlsx /Users/farshad.ghanzanfari/Downloads/2026-06-10.xlsx \
  --output MManger/Resources/SeedData.json
```

## Testing

Open `MManger.xcodeproj` in Xcode and run the `MMangerTests` scheme. To validate the full provided PDF fixture, set the unit test environment variable:

```bash
ADCB_PDF_PATH=/Users/farshad.ghanzanfari/Downloads/credit_card_transactions.pdf
```

Useful command-line checks:

```bash
xcodebuild build -project MManger.xcodeproj -target MManger -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
xcodebuild build -project MManger.xcodeproj -target MMangerTests -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
```

Simulator test execution requires an installed iOS runtime that matches the active Xcode platform. In this environment, compile/build works with the iOS Simulator 26.5 SDK, but `xcodebuild test` cannot run because the available simulator runtimes are 26.0/26.1 while Xcode asks for iOS 26.5.
