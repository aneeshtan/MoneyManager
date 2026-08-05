# Pro Money Manager Android Delivery Roadmap

This roadmap decomposes the approved Android design into independently executable plans. Each plan ends in working, testable software and updates the parity ledger. Plans are executed inline in order without additional approval pauses, as requested by the user.

## Execution order

| Order | Plan | Working outcome | Design coverage |
| --- | --- | --- | --- |
| 1 | `2026-07-10-android-foundation-accounting-core.md` | Buildable native app shell, exact money model, balanced postings, Room foundation, local profile | Sections 5, 6, 8, 9 |
| 2 | `2026-07-10-android-transactions-accounts-categories.md` | Account/category/transaction CRUD, tags, receipts, filters, duplicate review, splits, transfers | Sections 7.4–7.6, 7.14 |
| 3 | `2026-07-10-android-import-categorization.md` | PDF/CSV/text/XLSX/SMS-paste review-first import and smart local rules | Sections 7.7–7.8, 10 |
| 4 | `2026-07-10-android-dashboard-insights.md` | Dashboard, budgets, safe-to-spend, drill-down, search, calendar, trends | Sections 7.3, 7.9 |
| 5 | `2026-07-10-android-planning-tools.md` | Schedules, reminders, savings goals, debt payoff, subscriptions | Sections 7.10–7.13 |
| 6 | `2026-07-10-android-privacy-portability-localization.md` | Backup/restore, CSV/legacy JSON, app lock, deletion, eight languages, RTL/Persian dates | Sections 7.1, 7.15–7.16, 11–12 |
| 7 | `2026-07-10-android-adaptive-parity-release.md` | Adaptive polish, accessibility, performance, complete parity ledger, release AAB | Sections 7.2, 13, 15–17 |
| 8 | `2026-07-11-android-native-enhancements.md` | Share target, widgets, shortcuts, notification actions, OCR, policy-isolated SMS path | Section 14 |

## Plan lifecycle

1. Write the next detailed plan against the code produced by the preceding plan.
2. Self-review it against the approved design and current parity ledger.
3. Execute it with `executing-plans`, using TDD for every behavior change.
4. Run the plan’s full verification suite.
5. Commit only the plan’s scoped files and evidence.
6. Continue immediately with the next plan.

## Global completion rule

The program is complete only after all eight plans pass, every required entry in `android/parity/ios-feature-parity.yaml` is `verified`, the release AAB and backup round-trip are verified, and the Android-native enhancement plan is implemented without weakening the parity result.
