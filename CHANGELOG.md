# Changelog

All notable user-facing changes, written so entries can be copied into the App Store "What's New" text.

## Unreleased

### Smarter importing
- **New-merchant review during import** — when an imported statement contains merchants the app hasn't seen before, they're grouped into a "New merchants" card. Pick a category once per merchant and it's applied to every matching row and remembered for all future imports.
- **Learns from your edits** — when you categorize a transaction by hand, the app offers to apply the same category to all similar uncategorized transactions from that merchant, and remembers the choice.
- **Fuzzy merchant matching** — branch and store variants (e.g. "STARBUCKS 3391" vs "STARBUCKS MALL") now map to the same category automatically, so far fewer imported transactions land as "Uncategorized".
- **Bigger built-in merchant dictionary** — expanded the offline auto-categorization list with ~130 additional common restaurant, coffee, grocery, fuel, utility, clothing, health, hotel, and retail chains, plus recognition of cashback and foreign-transaction-fee lines that many bank statements include.
- **Categorizes unknown businesses by type** — a local shop the app has never seen is now categorized from the business-type word in its name ("SARDE RESTAURANT LLC" → Food, "AQIQ GENTS SALON" → Shopping, "MEDICINA PHARMACY" → Health), covering around 85% of merchants that previously needed a manual pick.
- **Shorter review list** — the "New merchants" card now groups branch variants of the same merchant into one decision, shows the busiest merchants first with a count of how much of the import they cover, and adds a "Set all remaining" action so the long tail of one-off shops can be handled in a single tap instead of one by one.

### Privacy
- **Hide amounts** — tap the eye icon on the Stats or Transactions screen to mask every amount in the app. Great for using the app in public. Your choice is remembered.
- **App switcher protection** — the app's preview in the iOS app switcher is now blurred, so your finances are never visible when flipping between apps.

### Onboarding
- **Straight to Import after setup** — a brand-new install now goes straight to the Import screen right after finishing setup, instead of landing on an empty Dashboard, so you can bring your transactions in immediately.

### Fixed
- **Crash when saving a large import** — saving a big statement (around 1,300+ transactions) could crash the app just as the import finished. The review list was reading rows by position while the list was being cleared at the end of the save. Imports of any size now complete cleanly.
- **Wrong currency symbol in a few places** — the Trends screen, budget progress text on Categories, and recurring-bill notifications could show a `$` sign instead of your selected currency. All amounts now consistently use your chosen currency.

### Safety
- **Undo an import** — every import batch in Import history (More → Export & Backup) now has a Revert button that removes exactly the transactions that import created. Manually added transactions are never touched.

### Performance
- Every screen was reworked to load only the data it displays. Calendar and Trends now fetch just the visible date range, and all screens compute their summaries in a single pass.
- Dashboard, Calendar, Transactions, Accounts, Trends, Search, Subscriptions, Tags, and Debt Payoff are significantly faster with large transaction histories.
- Search on the Transactions and Search screens now waits until you pause typing, keeping the keyboard responsive.
- Duplicate and recurring-charge detection in Search is dramatically faster on large datasets.
- Faster app launch.

---

<!-- Template for future releases:
## X.Y.Z — YYYY-MM-DD
### Section
- Change
-->
