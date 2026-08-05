# Pro Money Manager for Android — Product and Technical Design

**Status:** Approved on 2026-07-10

**Product:** Pro Money Manager

**Platforms:** Android phones, tablets, foldables, and resizable desktop windows

**Repository layout:** Existing iOS app remains at the repository root; the Android project will live in `android/`

**Android application ID:** `com.farshadghanzanfari.promoneymanager`

## 1. Objective

Build a native Android version of Pro Money Manager that:

1. reaches behavioral parity with every verified feature in the current iOS app;
2. fixes correctness, data-integrity, portability, and platform-fit gaps found during the iOS audit;
3. passes an explicit parity and quality gate; and
4. only then adds Android-native advantages such as share-target imports, widgets, shortcuts, actionable notifications, receipt OCR, and optional policy-approved SMS ingestion.

The Android app is a first-class native product, not a SwiftUI visual clone, cross-platform wrapper, or reduced companion. It preserves the Pro Money Manager brand and product model while following Android interaction, accessibility, lifecycle, navigation, storage, and distribution conventions.

## 2. Evidence and baseline

The feature baseline comes from the current repository, especially:

- `MManger/Models/FinanceModels.swift`
- `MManger/Services/`
- `MManger/Views/`
- `MMangerTests/`
- `AppStore/VersionChanges.md`
- `AppStore/Marketing/AppStoreListing.md`
- the six App Store screenshot compositions

The source code is authoritative when product copy and implementation disagree. Examples found during the audit:

- iOS marketing mentions Excel import, but the current importer rejects `.xlsx` and `.xls` files;
- the iOS “full backup” includes accounts, categories, merchant rules, and transactions but omits other persisted models, preferences, and receipt files;
- account deletion omits savings goals, schedules, tags, and debt plans;
- split application keeps the original full transaction amount and creates additional transaction amounts, causing double counting;
- transfers have only one account field and therefore do not model balanced source and destination legs;
- several relationships are stored by mutable names instead of stable identifiers; and
- multi-currency reports can add raw values from different currencies.

Android parity means preserving intended user capabilities and compatible data, not reproducing known defects.

## 3. Product principles

### 3.1 Local-first and private

- All core functions work without a network connection.
- Phase-one builds do not request the Android `INTERNET` permission.
- No analytics, advertising, tracking, or bank-sync SDK is included.
- Finance records and receipts remain in app-private storage unless the user explicitly exports them.
- A local profile is the default identity model. Google sign-in is not shown until it provides a real cloud function.
- App lock uses Android biometrics or device credentials and never substitutes for device encryption.

### 3.2 Accurate before clever

- Monetary values never use floating-point storage or arithmetic.
- Different currencies are never silently summed.
- Transfers, splits, duplicate handling, backup, restore, and deletion are transactional and testable.
- “AI” or smart categorization remains explainable, local, rule-based behavior unless a later design explicitly introduces another model.

### 3.3 Branded and Android-native

- Preserve the lavender, violet, teal, coral, gold, mint, rose, rounded typography, soft gradient, and elevated glass-surface identity.
- Use Material 3 component behavior, touch feedback, system bars, predictive back, keyboard handling, accessibility semantics, and adaptive navigation.
- Branded colors are the default. Material You dynamic color is optional.
- Light, dark, high-contrast, RTL, large-font, keyboard, mouse, and screen-reader use are designed rather than patched later.

### 3.4 Parity is a gate

Android-only features may be developed behind flags after the foundation exists, but they cannot delay, replace, or be counted as completion of iOS parity. The parity ledger must show every capability as verified before the Android enhancement milestone can ship.

## 4. Scope and delivery stages

### Stage A — Foundation and parity contract

- Create the Android build, module boundaries, design system, database, navigation shell, dependency injection, test fixtures, and CI checks.
- Create `android/parity/ios-feature-parity.yaml`, with one entry per iOS capability, its Android destination, implementation state, and proof.
- Import sanitized seed data and shared parser fixtures without including private bank files.

### Stage B — Complete iOS feature parity

- Implement all capabilities in Section 7.
- Implement the correctness requirements in Sections 8–12 as part of parity quality.
- Run every automated and manual parity check in Section 16.

### Stage C — Android-native advantages

- Ship the first set of Android enhancements in Section 14 only after Stage B passes.
- Keep sensitive SMS ingestion isolated from the base application and disabled unless Google Play approval and the privacy requirements are satisfied.

## 5. Android platform baseline

- Language: Kotlin
- UI: Jetpack Compose and Material 3
- Minimum SDK: Android 8.0 / API 26
- Compile SDK: Android 16 / API 36
- Target SDK: Android 16 / API 36, raised if Google Play requires a newer level before release
- Build scripts: Gradle Kotlin DSL with a version catalog
- App architecture: single activity, Navigation 3, unidirectional data flow, screen-level ViewModels, repositories, use cases, coroutines, and Flow
- Persistence: Room for structured finance data; DataStore for preferences
- Dependency injection: Hilt with constructor injection
- Background work: WorkManager for deferrable work; alarm/notification scheduling selected according to timing guarantees and current Android policy
- File access: ContentResolver, Activity Result APIs, Photo Picker, and Storage Access Framework
- Widgets: Jetpack Glance
- Security: Android Keystore for device-bound secrets; passphrase-derived keys for portable encrypted backups

Dependency versions will be pinned to mutually compatible stable releases when implementation starts. Pre-release dependencies are allowed only when a required platform capability has no stable equivalent and the implementation plan documents the containment and upgrade path.

## 6. Architecture and module boundaries

The project uses focused Gradle modules. Features may begin consolidated when build cost justifies it, but dependency direction must match this design.

### 6.1 Application and shared modules

| Module | Responsibility |
| --- | --- |
| `:app` | Application, activity, root navigation, Hilt entry point, global lifecycle |
| `:core:model` | Immutable domain models, value objects, enums, validation results |
| `:core:database` | Room entities, DAOs, migrations, transactional database operations |
| `:core:data` | Repository implementations, preference storage, seed import, file storage |
| `:core:domain` | Reusable use cases, calculations, categorization, duplicate detection, schedules |
| `:core:import` | Format detection, parser strategies, normalization, review drafts, fixtures |
| `:core:backup` | CSV, legacy iOS JSON, complete backup package, encryption, restore preview |
| `:core:designsystem` | Theme, tokens, branded Material components, charts, adaptive primitives |
| `:core:notifications` | Permission state, reminder plans, scheduling, notification actions |
| `:core:testing` | Fakes, builders, fixtures, clocks, locale helpers, test database support |

### 6.2 Feature modules

| Module | Responsibility |
| --- | --- |
| `:feature:onboarding` | Language, region, currency, local profile, privacy explanation |
| `:feature:dashboard` | Monthly stats, safe-to-spend, insights, budgets, recurring bills, layout editor |
| `:feature:transactions` | List, editor, splits, transfers, filters, duplicates, tags, receipts |
| `:feature:import` | Source selection, parsing progress, review, editing, merge, save |
| `:feature:accounts` | Accounts, balances, health, archive, detail |
| `:feature:categories` | Category tree, budgets, rules, smart categorization |
| `:feature:planning` | Schedules, savings goals, debt payoff, subscriptions |
| `:feature:insights` | Search, calendar, trends, category drill-down |
| `:feature:settings` | Profile, language, regional settings, notifications, lock, backup, deletion |
| `:feature:widgets` | Glance widgets and widget configuration |

### 6.3 Dependency rules

- Feature modules depend on public core contracts, not on other feature internals.
- Compose UI never talks directly to Room, DataStore, ContentResolver, or WorkManager.
- ViewModels expose immutable `StateFlow` UI state and accept explicit user actions.
- Repositories expose domain models, not Room entities.
- Platform APIs are behind interfaces so domain tests run on the JVM.
- Imports, backup, and deletion use database transactions and do not leave partial state.
- No service locator or mutable global finance state is permitted.

## 7. iOS parity contract

### 7.1 Onboarding, profile, and regional behavior

- Branded onboarding with privacy explanation.
- Continue with a local workspace.
- Local display name and profile record.
- Base currency, preferred currencies, country/region, and time-zone selection.
- Language selection for English, Spanish, Arabic, Hindi, Persian, German, French, and Portuguese.
- RTL layout for Arabic and Persian.
- Gregorian calendar for all supported languages except Persian, which preserves Persian-calendar display and date behavior where the iOS app does.
- Sign out without deleting finance data.
- Explicit destructive deletion of the profile and all associated local data.
- Versioned, idempotent first-run seeding from the sanitized repository baseline: four generic account templates in the selected base currency, the existing category/rule templates, and no initial transactions.

The iOS optional Apple login does not create a server account or sync data. Android replaces it with an honest local profile and optional device lock. Google sign-in is not required for behavioral parity.

### 7.2 Navigation and adaptive destinations

Compact windows use four top-level destinations:

1. Stats
2. Transactions
3. Import
4. More

More exposes Calendar, Search, Trends, Accounts, Categories, Goals, Scheduled, Backup, Profile, App Lock, Tags, Debt Payoff, and Subscriptions.

Medium and expanded windows use an adaptive navigation rail or drawer. Expanded transaction, account, category, search, and import-review flows use list-detail or supporting-pane layouts. Resizing, rotation, folding, and split-screen changes preserve the selected destination, filters, scroll position, editor drafts, and review state.

### 7.3 Dashboard and analytics

- Select and move between months.
- Display monthly income, expense, and net values.
- Calculate safe-to-spend from current resources, planned budgets, and scheduled obligations.
- Category share chart and ranked category totals.
- Category detail with subcategory breakdown and transaction drill-down.
- Monthly summary.
- Local smart insights for spending change, dominant category, uncategorized items, and possible duplicates.
- Budget progress, remaining amounts, over-budget state, and budget editing.
- Budget rollover to the next month.
- Recurring-charge detection and next expected date.
- Notes collected from the selected month.
- Reorder and hide dashboard cards, with preferences persisted.
- Dashboard shortcuts to planning and analysis tools.

### 7.4 Transactions

- Create, read, edit, and delete expense, income, and transfer transactions.
- Date, exact amount, currency, merchant, note, account, category, and subcategory editing.
- Category choices constrained by transaction kind.
- Group transaction rows by day and show summary totals.
- Swipe/delete interaction with confirmation appropriate to Android.
- Filter by start date, end date, type, account, category, uncategorized status, minimum amount, and maximum amount.
- Preserve imported source metadata and show it in transaction detail.
- Attach a receipt image through Photo Picker or a document through the system picker.
- List and remove attachments.
- Assign multiple color-coded tags.
- Split one transaction across two or more category allocations.
- Detect exact and likely duplicate groups and keep the selected/newest record.
- Learn or update a merchant rule from an edited classification.

### 7.5 Accounts

- Account types: cash, bank, credit card, liability, investment, and other.
- Name, currency, opening balance, type, archive state, sort order, and creation date.
- Infer a sensible default type from the name while allowing edits.
- Calculate current value from opening balance and transactions.
- Edit the opening balance from a target current value.
- Account health summary and transaction count.
- Account detail with linked transactions.
- Archive and restore accounts without breaking historical transactions.

### 7.6 Categories, budgets, and rules

- Expense, income, and transfer category kinds.
- Parent and subcategory hierarchy.
- Add, edit, archive, and restore categories.
- Category detail with current-month budget, subcategories, rules, and transactions.
- Monthly budget per category or subcategory.
- Budget amount, currency, spent, remaining, fraction used, and overspent state.
- Add, edit, enable, disable, and inspect merchant rules.
- Rule match types: exact and contains.
- Rule conditions: merchant pattern, transaction kind, account, note pattern, minimum amount, maximum amount, and priority.
- Rule metadata: confidence, sample count, enabled state, auto-generated state, and creation date.
- Rule preview and matched-transaction detail.

### 7.7 Smart categorization

- Normalize merchant text deterministically.
- Apply enabled merchant rules by priority and specificity.
- Suggest a historical category based on previously classified transactions.
- Learn candidate rules from repeated categorized merchant/account patterns.
- Preview learned rules and affected uncategorized transactions.
- Apply suggestions in bulk only after user review.
- Save learned rules and classification updates atomically.
- Show confidence without implying a remote or generative AI service.

### 7.8 Import center

Sources:

- searchable PDF statements;
- CSV;
- text exports;
- pasted bank/SMS messages; and
- real `.xlsx` workbooks on Android, correcting the iOS implementation gap.

Format detection and parser coverage must preserve the current adapters for:

- Chase
- Bank of America
- Wells Fargo
- Barclays
- HSBC
- Santander
- DBS
- OCBC
- Commonwealth
- HDFC
- ICICI
- SBI
- Emirates NBD
- First Abu Dhabi Bank
- generic CSV
- generic plain text
- SMS notification text

The import experience includes:

- account selection and currency fallback;
- user-selected documents with no broad storage permission;
- cancellable background parsing;
- progressive result delivery for large files;
- parsed, selected, duplicate, and review-only counts;
- category and subcategory suggestions with confidence;
- editing each review row before save;
- review-only defaults for payments received, cashback, foreign transaction fees, and VAT-on-foreign rows;
- “select clean” behavior;
- duplicate merge/replace behavior;
- merchant-rule creation or update from reviewed rows;
- automatic creation of missing imported account/category metadata after review;
- batched but atomic save semantics;
- import batch audit history; and
- clear unsupported, corrupt, empty, permission, and cancellation states.

Scanned-image PDFs are not required for strict iOS parity. Local OCR for scanned statements and receipts is an Android enhancement.

### 7.9 Search, calendar, and trends

- Global search across transactions, accounts, categories, and import history.
- Saved search filters and uncategorized suggestions.
- Apply a suggested category directly from search.
- Monthly calendar with daily income/expense summaries and transaction drill-down.
- Six-, twelve-, and twenty-four-month trend ranges.
- Income versus expense line/area chart.
- Monthly net bar chart.
- Cumulative net-worth chart.
- Total income, expense, average monthly expense, and net-savings summaries.
- Lowest- and highest-spend month highlights.
- Category breakdown across the selected period.

### 7.10 Scheduled transactions and reminders

- Add, edit, delete, pause, and resume schedules.
- Frequencies: weekly, biweekly, monthly, quarterly, and yearly.
- Expense, income, and transfer schedule types.
- Merchant, amount, currency, account, classification, note, next date, and last-run date.
- Post a scheduled item now and advance its next occurrence.
- Show upcoming and paused schedules.
- Optional local notification at 09:00 in the selected time zone on the day before a due item.
- Detected recurring-bill reminders follow the same day-before behavior.
- Notification permission and disabled states are visible and recoverable through system settings.

Android notification actions add post, skip, and open behavior only in Stage C.

### 7.11 Savings goals

- Add, edit, archive, restore, and delete a goal.
- Name, target amount, current amount, currency, target date, sort order, and completion state.
- Progress and remaining amount.
- Add a contribution.
- Android persists contribution history so the displayed current amount remains compatible while becoming auditable.

### 7.12 Debt payoff

- Add, edit, archive, restore, and delete a debt plan.
- Name, linked liability account, total debt, minimum payment, extra payment, annual interest rate, and strategy.
- Snowball and avalanche strategy labels.
- Monthly payment, percentage paid, and estimated months remaining.
- Guard invalid payment/rate combinations and explain plans that cannot amortize.

Portfolio-level ordering across multiple debts is reserved for Stage C; iOS parity retains individual plans.

### 7.13 Subscriptions

- Detect subscription candidates from repeated expense merchants.
- Require transactions in at least two months.
- Show merchant, typical amount, currency, last charge, next expected charge, and sample count.
- Detect and highlight likely price increases.
- Avoid creating a second source of truth: subscriptions remain derived from transactions unless a later design adds explicit subscription records.

### 7.14 Tags

- Add, edit, recolor, and delete tags.
- Assign multiple tags to a transaction.
- Show transaction count and total per tag.
- Open tag detail to see related transactions.
- Deleting a tag removes join rows but never deletes transactions.

### 7.15 Backup, restore, export, and import history

- Export transactions as CSV with deterministic headers and escaping.
- Export the iOS-compatible subset as legacy JSON, with a mandatory compatibility report for data the iOS schema cannot represent.
- Restore legacy iOS JSON with duplicate review and name-to-ID mapping.
- Export and restore the complete Android backup described in Section 11.
- Share/save through Android’s system document interfaces.
- Show recent import batches with saved/ignored counts and date.

### 7.16 Security, profile, and deletion

- Enable or disable app lock.
- Unlock with Android biometric or device credential.
- Re-lock after backgrounding according to the saved timeout policy.
- Do not lose finance data when signing out of the local profile.
- Delete every database row, receipt file, temporary import file, DataStore preference, pending job, reminder, widget snapshot, and cryptographic key when deleting local data.
- Show a count of locally allocated accounts, categories, transactions, and rules.
- Provide privacy and support information without telemetry.

## 8. Accounting-safe data model

### 8.1 Money

`Money` is a domain value object composed of:

- ISO 4217 currency code;
- checked signed integer minor units for calculations; and
- validated currency scale metadata.

Storage uses integer minor units. Persisted transaction, budget, goal, schedule, and rule amounts are non-negative magnitudes; transaction kind and transfer-leg direction provide their accounting sign. Derived balances and net values may be negative. Calculations use checked integer arithmetic and explicit rounding rules. Parsing may use `BigDecimal`, but values must be converted to validated minor units at the boundary. Floating-point types are forbidden for persisted money, balances, budgets, exchange calculations, and equality checks.

If a source contains precision beyond the currency’s supported scale, the review row shows the issue and requires an explicit rounding choice. Raw source text remains available for audit.

### 8.2 Core Room entities

- `ProfileEntity`
- `AccountEntity`
- `CategoryEntity` with nullable `parentCategoryId`
- `TransactionEntity`
- `TransactionSplitEntity`
- `TransferLinkEntity`
- `MerchantRuleEntity`
- `TransactionAttachmentEntity`
- `ImportBatchEntity`
- `BudgetEntity`
- `SavingsGoalEntity`
- `SavingsContributionEntity`
- `ScheduledTransactionEntity`
- `TagEntity`
- `TransactionTagCrossRef`
- `DebtPayoffPlanEntity`

All IDs are UUID strings. Imported iOS UUIDs are retained when present. New Android UUIDs use lowercase canonical strings.

### 8.3 Relationships and deletion behavior

- Profile owns all finance records.
- Category parent links use foreign keys, not names.
- Transactions reference account/category IDs and retain display-name snapshots only in legacy source metadata.
- Merchant rules and budgets reference category IDs; schedules and debt plans reference account IDs.
- Tags use a many-to-many join table.
- Attachments cascade when a transaction is permanently deleted.
- Archives use explicit flags; normal historical references are never cascaded because an account/category is archived.
- Permanent workspace deletion explicitly enumerates every entity and file type and has an integration test that fails when a new persisted type is not included.

### 8.4 Splits

- One parent transaction owns zero or more split allocations.
- The parent controls account balance, date, merchant, currency, and total amount.
- Category reporting uses splits when they exist and the parent category otherwise.
- Split currency must equal the parent currency.
- Split minor-unit totals must equal the parent amount exactly before commit.
- A split update and all reporting-visible changes commit in one Room transaction.

### 8.5 Transfers

- A transfer has linked source and destination legs.
- Same-currency transfers require equal absolute source and destination amounts.
- Cross-currency transfers preserve source amount/currency, destination amount/currency, derived or user-entered rate, and optional fee.
- Deleting or editing one leg updates the linked transfer atomically.
- Transfers do not count as income or expense unless an explicit fee transaction does.

### 8.6 Multi-currency rules

- Account balances display in the account currency.
- Reports group values by currency by default.
- Base-currency totals require explicit stored conversion rates and show the rate date/source.
- The offline parity release does not fetch exchange rates.
- Existing iOS data that mixed currencies remains visible but is never silently collapsed into a false total.

### 8.7 Time and calendars

- Persist instants as UTC epoch milliseconds where an instant is intended.
- Persist calendar dates as ISO local dates where time-of-day is not intended.
- Store the profile time-zone ID and calculate month/day boundaries in that zone.
- Preserve Persian-calendar presentation and conversion while keeping stable storage representations.
- Reminder rescheduling handles daylight-saving changes and time-zone edits.
- Tests use injected `Clock`, time zone, locale, and calendar abstractions.

## 9. Data flow and concurrency

Normal write flow:

```text
Compose action
  -> screen ViewModel
  -> validated use case
  -> repository contract
  -> atomic Room transaction
  -> DAO Flow invalidation
  -> repository domain mapping
  -> immutable UI state
  -> Compose rendering
```

Rules:

- No disk, PDF, spreadsheet, JSON, image, or cryptographic work runs on the main thread.
- ViewModels survive configuration changes and preserve in-progress state through `SavedStateHandle` where appropriate.
- Long-running imports expose progress, cancellation, and terminal status.
- Process recreation can restore document URI, chosen account, source type, filters, and review draft state when safe.
- One-shot effects use durable state or explicit UI consumption semantics; ViewModels do not emit lossy fire-and-forget navigation/error events.

## 10. Import architecture

### 10.1 Pipeline

```text
Open document / receive share / paste text
  -> validate URI, MIME type, extension, and size
  -> copy to scoped temporary storage when random access is required
  -> extract text or worksheet rows
  -> detect format
  -> run matching parser strategy
  -> normalize merchant, date, amount, currency, and kind
  -> apply rules and duplicate index
  -> emit review drafts progressively
  -> user edits/selects/merges
  -> validate the full selected set
  -> commit batch, metadata, rules, and transactions atomically
```

### 10.2 Parser interfaces

- Parsers consume streams or bounded temporary files and never rely on global mutable state.
- Parser outputs use a common `ImportDraft` model with raw source provenance and typed warnings.
- Format detection reports its confidence and selected adapter.
- Generic parsers are a fallback, not a silent substitute for a failed strict adapter.
- XLSX support reads workbook cell values and date formats without executing formulas or macros.
- File size, page count, worksheet row count, and decompression limits prevent resource exhaustion.
- Password-protected, scanned, malformed, or unsupported documents return specific reviewable errors.

### 10.3 Duplicate identity

The parity identity key uses account, local transaction date, exact amount, currency, and normalized merchant. The Android engine also computes a likely-duplicate score using date distance and merchant similarity, but likely matches are never silently deleted or skipped.

### 10.4 Save semantics

- Duplicate replacement, new transaction insertion, import batch counts, metadata creation, and learned-rule updates commit in one transaction.
- Cancellation before commit writes nothing.
- A database or storage failure rolls back all database changes and cleans temporary files.
- Successful completion retains the audit batch and removes temporary source copies unless the user attached the original file.

## 11. Backup, restore, and interoperability

### 11.1 Export formats

1. **Transactions CSV:** human-readable spreadsheet export.
2. **Legacy JSON:** compatible with the current iOS backup schema for manual movement of the subset that schema can represent.
3. **Complete `.pmmbackup`:** versioned Android backup containing a manifest, normalized JSON records, preferences, and receipt files.

### 11.2 Complete backup package

The package includes:

- schema and application version;
- export timestamp and source platform;
- profile and regional settings;
- all entities and relationships;
- dashboard, theme, language, notification, and lock preferences that are portable;
- attachment metadata and receipt files;
- a per-entry checksum and package-level integrity manifest; and
- no device-bound biometric secret.

The complete backup is a ZIP payload containing the manifest, normalized JSON records, and attachments. An encrypted backup wraps that payload in a binary envelope containing the `PMMB` magic value, envelope version, KDF parameters, a random 16-byte salt, and a random 12-byte nonce. Argon2id derives a 256-bit key from the passphrase using an initial profile of 64 MiB memory, three iterations, and parallelism one. AES-256-GCM encrypts and authenticates the entire ZIP payload, with the envelope header as associated data. KDF parameters are versioned in the header so future releases can raise them; implementation benchmarks must verify the profile on the minimum supported device class. The package never stores the passphrase or raw key. Device-bound Keystore keys are not used for portable encryption because they cannot restore on another device.

Legacy JSON is intentionally not called a full backup. Before export, Android shows a compatibility report. Split parents are flattened into child rows whose values total the parent and whose notes contain a stable split-group marker. Linked transfers, receipts, tags, budgets, goals, schedules, debt plans, rule conditions absent from the iOS schema, and Android-only preferences cannot be represented faithfully. They are excluded only after the user explicitly confirms the listed counts; otherwise export is cancelled and the complete `.pmmbackup` format is offered. No incompatible record is silently converted or discarded.

### 11.3 Restore flow

1. Select the file through the system picker.
2. Identify format and decrypt if required.
3. Validate size, schema, checksums, IDs, relationships, currency values, and attachment paths.
4. Migrate older schema versions in memory.
5. Show counts, conflicts, missing references, and the chosen replace/merge mode.
6. Require explicit confirmation.
7. Stage files and commit records atomically.
8. Move staged files into final private storage.
9. Rebuild reminders, derived summaries, widgets, and search indexes.

A failure leaves the pre-restore workspace unchanged. Restore is idempotent for the same IDs and detects legacy iOS duplicates before insertion.

## 12. Privacy and security

- The phase-one manifest omits `INTERNET`, contacts, location, microphone, call log, SMS, broad media, and broad storage permissions.
- Photo Picker and Storage Access Framework replace broad storage access.
- The database and receipts live in app-private storage protected by Android file-based/device encryption.
- Sensitive database content is excluded from automatic cloud backup to preserve the stated no-server model. Manual complete backup is user initiated.
- Temporary import/export files have bounded lifetimes and are deleted after success, cancellation, failure, sign-out cleanup where applicable, or workspace deletion.
- Exported unencrypted CSV/JSON displays a clear warning that the destination controls security.
- App lock uses `BiometricPrompt` with allowed device credentials. Lock state is not presented as encryption.
- Screens containing finance data use secure-screen behavior as a user preference, not an irreversible default.
- Release builds enable R8 optimization, resource shrinking, and safe log removal.
- Logs never include transaction text, merchant names, amounts, document content, receipt paths, keys, passphrases, or email addresses.
- Dependency review rejects advertising, analytics, unnecessary networking, and abandoned libraries.
- The privacy policy and Google Play Data Safety form must match the actual manifest and behavior.

## 13. UI and interaction design

### 13.1 Theme

- Material 3 color roles are derived from the existing violet, lavender, teal, coral, gold, mint, and rose brand palette.
- Light and dark palettes meet contrast requirements.
- Glass surfaces are implemented as performant tonal/elevated containers with restrained blur; scrolling lists do not stack expensive real-time blur layers.
- Rounded cards, capsules, charts, gradients, and app artwork remain recognizable as Pro Money Manager.
- Motion uses short Material transitions and respects system reduced-motion/animator settings.

### 13.2 Adaptive layout

- Compact: bottom navigation, single-pane navigation, modal sheets where appropriate.
- Medium: navigation rail and wider content constraints.
- Expanded: rail/drawer plus list-detail or supporting panes.
- Foldable posture and hinge data prevent controls/content from straddling an occluding fold.
- Desktop-window and tablet layouts support keyboard traversal, shortcuts for common actions, mouse/trackpad hover where useful, and resizable panes.

### 13.3 Accessibility

- Every interactive control has a meaningful role, label, state, and action.
- Custom charts expose textual summaries and navigable data points.
- Status never relies on color alone.
- Text supports system font scaling without clipping or lost actions.
- Touch targets meet Android accessibility sizing guidance.
- Traversal order follows visual reading order in LTR and RTL.
- TalkBack, Switch Access, keyboard navigation, contrast, and automated accessibility checks are release gates.

### 13.4 Empty, loading, and failure states

- Empty states explain what is missing and offer the next relevant action.
- Loading states show determinate progress when counts are known and cancellable progress for imports/restores.
- Inline field validation keeps user input intact.
- Full-screen blocking errors are reserved for unusable workspace/database failures.
- Destructive actions state exactly what will be removed and require confirmation.

## 14. Android-native advantages after parity

### 14.1 First Android enhancement release

- Receive PDFs, CSV, XLSX, and text through Android share targets from Files, Drive, email, messaging, and compatible bank apps.
- Responsive Glance widgets for safe-to-spend, month totals, budget progress, and upcoming bills.
- Dynamic and pinned app shortcuts for Add expense, Import statement, Search, and Upcoming bills.
- Actionable scheduled-transaction notifications: Post, Skip, and Open.
- Receipt camera capture and local OCR with review before field application.
- Optional Material You dynamic color.
- Polished foldable/tablet list-detail layouts beyond minimum parity.
- Encrypted backup to any user-selected document provider.

Widgets show redacted placeholders while app lock or secure-display policy requires privacy. Widget configuration lets the user choose exactly which values can appear on the launcher.

### 14.2 Later opt-in enhancements

- Scanned-statement OCR with page review.
- Wear OS balance/upcoming-bill companion and quick expense entry.
- Portfolio-level debt snowball/avalanche scenarios.
- User-created automation rules with dry-run previews.
- Optional on-device SMS transaction detection.

SMS support is a separate, disabled-by-default capability. It may ship only if:

- Google Play approves the SMS-based money-management permission declaration;
- the feature is a documented core use case in the listing and privacy policy;
- a prominent disclosure and granular consent precede the permission prompt;
- messages are processed on device;
- only financial candidates are retained;
- no SMS content is transmitted;
- every candidate enters the review queue rather than saving silently; and
- a build without SMS permissions remains available if policy or distribution requires it.

Notification-listener access is not used as a policy workaround.

## 15. Error model

All lower layers return typed failures mapped to localized, actionable UI states.

Primary categories:

- validation;
- unsupported format or bank;
- password-protected or scanned document;
- corrupt or empty file;
- permission/access revoked;
- insufficient storage;
- duplicate/conflict;
- database/migration;
- backup authentication/integrity;
- cancellation; and
- unexpected internal failure.

Requirements:

- Preserve user drafts after recoverable failures.
- Never display raw stack traces or sensitive source content.
- Offer retry only when the action is safe and meaningful.
- A retry of an import/restore cannot duplicate committed data.
- Record privacy-safe diagnostic codes for support without telemetry.

## 16. Testing and verification

### 16.1 Parity ledger

Each Section 7 item receives:

- stable ID;
- iOS source reference;
- Android destination;
- acceptance criteria;
- automated test reference where feasible;
- manual evidence for visual/platform behavior; and
- status: not started, in progress, implemented, or verified.

Parity is complete only when every required ledger entry is verified.

### 16.2 JVM unit tests

- Money parsing, rounding, overflow, formatting, and currency grouping.
- Account balances.
- Split invariants and reporting.
- Same- and cross-currency transfer invariants.
- Budget progress, rollover, and safe-to-spend.
- Duplicate identity and likely-duplicate scoring.
- Merchant normalization, rule ordering, learning, and preview.
- Recurring bill and subscription detection.
- Schedule recurrence across month ends, leap years, DST, and time zones.
- Savings contributions.
- Debt amortization and invalid-plan handling.
- Persian/Gregorian calendar boundaries.
- CSV escaping and legacy JSON mapping.

### 16.3 Parser golden tests

- Sanitized fixtures for every named bank adapter and generic format.
- PDF, CSV, text, pasted SMS, and XLSX.
- Locale-specific dates, decimal separators, currencies, credits/debits, and noisy headers/footers.
- Duplicate and review-only classification.
- Empty, malformed, password-protected, oversized, and adversarial files.
- Golden output comparison using normalized domain drafts.

### 16.4 Room and repository tests

- Fresh database creation.
- Every schema migration from the earliest released Android version.
- Foreign keys, indexes, archive behavior, and cascade rules.
- Atomic import, split, transfer, restore, and deletion operations.
- Process restart and Flow observation.
- A deletion completeness test that enumerates all Room tables and private receipt/import directories.

### 16.5 Backup tests

- Android complete backup round-trip for every entity, preference, and attachment.
- Legacy iOS JSON import.
- Encrypted and unencrypted packages.
- Wrong passphrase, tampered manifest, corrupt attachment, unknown optional field, and unsupported required field.
- Merge, replace, duplicate, rollback, and idempotency behavior.

### 16.6 Compose and instrumented tests

- Onboarding to dashboard.
- Add/edit/delete transaction.
- Split and transfer flows.
- Filter and duplicate review.
- Import review and commit.
- Budget, schedule, goal, debt, tags, backup, restore, lock, and deletion.
- Navigation restoration after rotation, resize, folding, and process recreation.
- Notification permission and settings recovery.
- Screenshot matrices for phone, tablet, foldable, compact/expanded windows, light, dark, increased font, English LTR, Arabic RTL, and Persian calendar.
- Automated accessibility checks and manual TalkBack/Switch Access passes.

### 16.7 Performance and reliability

- Macrobenchmarks for cold/warm startup, dashboard display, transaction scrolling, global search, and import review.
- Baseline Profile generated from critical user journeys and verified against a no-profile build.
- Test datasets at 10,000 and 100,000 transactions.
- Large import cancellation and memory-pressure tests.
- StrictMode or equivalent debug checks for main-thread I/O and leaked resources.
- No application-not-responding condition during parsing, backup, restore, or deletion.

Performance thresholds will be recorded against named reference devices in the implementation plan and enforced as regression budgets, not asserted from developer-machine timing.

## 17. Release gates

### 17.1 Parity gate

- Every parity-ledger item verified.
- Legacy iOS JSON imports correctly.
- All eight languages present; Arabic/Persian RTL verified.
- Phone, tablet, foldable, and resizable-window critical flows pass.
- No known data-loss, accounting, privacy, security, accessibility, or release-blocking issue.

### 17.2 Quality gate

- Unit, parser, Room, backup, Compose, accessibility, and macrobenchmark suites pass.
- Release AAB builds with R8 and resource shrinking.
- Baseline Profile is packaged and measured.
- Database migration and complete-backup restore are verified on a release candidate.
- Manifest permission audit matches the local-first design.
- Privacy policy and Play Data Safety answers match the binary.

### 17.3 Distribution gate

- Application ID and signing key are final.
- App icon, store listing, screenshots, feature graphic, support URL, privacy URL, and deletion disclosure are ready.
- Target SDK meets the current Google Play requirement.
- Sensitive permissions have approval before inclusion.
- Internal/closed testing validates upgrade, reinstall, device transfer, notification, widget, and backup behavior on representative OEM devices.

## 18. Implementation milestones

1. **Build and architecture foundation** — Gradle project, modules, CI, design system, navigation, Room, DataStore, Hilt, test infrastructure.
2. **Accounting core** — money, profile, accounts, categories, transactions, splits, transfers, tags, receipts, seed data.
3. **Import and categorization** — parser port, XLSX, review center, duplicate engine, merchant rules, smart categorization, import history.
4. **Dashboard and insights** — monthly stats, safe-to-spend, budgets, recurring bills, customization, search, calendar, trends.
5. **Planning** — schedules, notifications, savings, debt, subscriptions.
6. **Privacy and portability** — lock, preferences, complete deletion, CSV, legacy JSON, encrypted full backup/restore.
7. **Localization and adaptive polish** — eight languages, RTL, Persian calendar, dark mode, tablet/foldable/desktop-window UX, accessibility.
8. **Parity verification and release candidate** — full ledger, performance, migrations, store artifacts, AAB.
9. **Android advantages** — share target, widgets, shortcuts, notification actions, OCR, optional approved SMS path.

Each milestone must finish with passing tests and updated parity evidence. A milestone is not considered complete because screens exist; its data, error, accessibility, recovery, and migration behavior must also pass.

## 19. Explicit non-goals for the parity release

- Live bank API synchronization.
- Server accounts or automatic cross-platform cloud sync.
- Advertising, analytics, social feeds, or transaction-data monetization.
- Cryptocurrency trading, payments, money movement, or lending.
- Automatic exchange-rate networking.
- Silent SMS, notification, email, or bank-app surveillance.
- Generative AI that sends finance data off device.
- Wear OS, Android Auto, or web clients before parity.
- Refactoring the existing iOS app into Kotlin Multiplatform.

These non-goals do not prohibit later approved designs. They protect the first objective: a complete, correct, native Android version of the existing product.

## 20. Success definition

The design objective is satisfied only when current evidence proves all of the following:

1. the Android app builds as a signed release candidate and runs on the supported Android range;
2. every verified iOS capability in the parity ledger works on Android;
3. Android corrects the identified split, transfer, backup, deletion, relationship, and multi-currency risks;
4. finance data remains local unless the user explicitly exports it;
5. migration, backup, restore, deletion, localization, accessibility, adaptive layout, and performance gates pass; and
6. Android-only enhancements are additive and do not substitute for any missing parity feature.

## 21. Reference guidance

- Android architecture recommendations: <https://developer.android.com/topic/architecture/recommendations>
- Adaptive apps: <https://developer.android.com/develop/adaptive-apps/guides/get-started-with-adaptive-apps>
- Material 3 in Compose: <https://developer.android.com/develop/ui/compose/designsystems/material3>
- Compose accessibility: <https://developer.android.com/develop/ui/compose/accessibility>
- Storage Access Framework: <https://developer.android.com/training/data-storage/shared/documents-files>
- Backup security: <https://developer.android.com/privacy-and-security/risks/backup-best-practices>
- Glance widgets: <https://developer.android.com/develop/ui/compose/glance>
- Baseline Profiles: <https://developer.android.com/topic/performance/baselineprofiles/overview>
- Google Play target API requirements: <https://developer.android.com/google/play/requirements/target-sdk>
- Google Play SMS and Call Log policy: <https://support.google.com/googleplay/android-developer/answer/10208820>
