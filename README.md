# Pro Money Manager

Native SwiftUI personal finance app for replacing SMS-based tracking with review-first bank statement imports.

## What is implemented

- SwiftUI iOS app with SwiftData local persistence.
- Seeded accounts, categories, and merchant rules generated from the local Money Manager backup and Excel export.
- Universal bank statement import with PDFKit parsing for searchable PDFs, CSV files, and pasted bank messages.
- Import review screen with duplicate detection, review-only defaults for payments/cashback/fees, category editing, and bulk save.
- Transaction list/editor, dashboard, accounts, category/rule browser, and CSV/JSON export.

## Store submission

Reference docs kept for future releases on both stores:

- `AppStore/PrivacyPolicy.md` - Source text for the published privacy policy
- `AppStore/SubmissionChecklist.md` - App Store submission requirements
- `AppStore/CompleteSubmissionGuide.md` - App Store Connect listing copy and steps
- `AppStore/GooglePlaySubmissionGuide.md` - Google Play Console listing copy and steps
- `AppStore/AndroidSubmissionChecklist.md` - Play Store submission requirements
- `CHANGELOG.md` - Release notes, copied into "What's New" for each submission

Marketing screenshots and store graphics are uploaded directly in App Store Connect
and Google Play Console; they are not kept in this repo.

`docs/index.html` is the GitHub Pages site that serves the support and privacy policy
URLs registered with both stores. Do not delete it while the apps are published.

## Regenerate seed data

Raw bank files should stay outside the repo. Regenerate sanitized seed data with:

```bash
python3 Tools/generate_seed_data.py \
  --backup /path/to/backup.mmbak \
  --xlsx /path/to/export.xlsx \
  --output MManger/Resources/SeedData.json
```

## Testing

Open `ProMoneyManager.xcodeproj` in Xcode and run the `MMangerTests` scheme. To validate the full provided PDF fixture, set the unit test environment variable:

```bash
BANK_STATEMENT_PDF_PATH=/path/to/credit_card_transactions.pdf
```

Useful command-line checks:

```bash
xcodebuild build -project ProMoneyManager.xcodeproj -target MManger -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
xcodebuild build -project ProMoneyManager.xcodeproj -target MMangerTests -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
```

Simulator test execution requires an installed iOS runtime that matches the active Xcode platform. In this environment, compile/build works with the iOS Simulator 26.5 SDK, but `xcodebuild test` cannot run because the available simulator runtimes are 26.0/26.1 while Xcode asks for iOS 26.5.
