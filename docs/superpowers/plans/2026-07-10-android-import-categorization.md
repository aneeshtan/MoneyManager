# Android Import and Categorization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build review-first import and local smart categorization parity for PDF-extracted text, CSV, plain text, pasted bank messages, duplicate detection, and merchant rules.

**Architecture:** Keep parsing and categorization pure JVM code in `:core:domain` first, then persist review batches through `:core:data`, and finally expose an Android Import screen. Android will not parse binary Excel directly in this parity phase; it will match the iOS behavior by rejecting `.xlsx/.xls` with a clear CSV-export message.

**Tech Stack:** Kotlin, coroutines/Flow, Room, Compose, JUnit, Truth, AndroidX Compose UI tests.

---

## File Structure

- Create `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/ImportModels.kt`: import format, parsed transaction, review draft, save result, categorization suggestion, and merchant rule domain types.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/CategoryMatcher.kt`: local rule matcher with exact/contains, priority, specificity, note/account/amount constraints, and fallback merchant mappings.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/ImportParsers.kt`: strict statement text parser, CSV parser, generic plain text parser, pasted message parser, and spreadsheet rejection.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/SmartCategorizationService.kt`: rule learning, preview, and bulk-apply planning.
- Modify `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`: add merchant rule and import-save commands.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`: map merchant rules and save selected import drafts transactionally.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: expose import paste/review/save state.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: implement Import tab review UI.
- Modify `android/parity/ios-feature-parity.yaml`: mark verified import/categorization items.

## Tasks

### Task 1: Merchant Rule Domain and Category Matching

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/CategoryMatcherTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/ImportModels.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/CategoryMatcher.kt`

- [ ] **Step 1: Write failing tests**

Cover rules beating fallbacks, exact vs contains, disabled rules ignored, priority/sample-count/pattern-length sorting, account/note/min/max amount constraints, and hard-coded fallbacks for CAREEM HALA, DUBAI TAXI, AMAZON GROCERY, AGODA/BOOKING, and MATOVI DIGITAL.

- [ ] **Step 2: Run red tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
```

Expected: fail on missing `MerchantRule`, `MatchType`, `CategorySuggestion`, and `CategoryMatcher`.

- [ ] **Step 3: Implement matcher**

Keep it deterministic and local. Use existing `MerchantNormalizer.normalize`.

- [ ] **Step 4: Run green tests and commit**

```bash
git add android/core/model android/core/domain
git commit -m "feat(android): match local merchant rules"
```

### Task 2: Strict Statement and CSV Parsers

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/ImportParsersTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/ImportParsers.kt`

- [ ] **Step 1: Write failing tests**

Use iOS parity lines:

```text
Transaction Date Description Cr/Dr Amount in AED
10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
10/06/2026 Amazon.ae DR 265.90
10/06/2026 5% CASHBACK - GROCERY MAY-26 CR 208.21
09/06/2026 AGODA.COM DR 1,161.00
```

Also test USD header detection, page-number rejection, CSV headers, fallback currency, duplicate flagging, and `.xlsx` rejection.

- [ ] **Step 2: Run red tests**

Run domain tests. Expected: fail on missing parsers.

- [ ] **Step 3: Implement parsers**

Represent money in integer minor units via existing `Money`. Use `LocalDate` and review flags; do not save rows in parsers.

- [ ] **Step 4: Run green tests and commit**

```bash
git add android/core/domain android/core/model
git commit -m "feat(android): parse import review drafts"
```

### Task 3: Smart Categorization Preview and Learning

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/SmartCategorizationServiceTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/SmartCategorizationService.kt`

- [ ] **Step 1: Write failing tests**

Verify repeated categorized merchants learn candidate rules, existing manual rules are not duplicated, preview only affects uncategorized transactions, and bulk apply produces an atomic plan.

- [ ] **Step 2: Run red tests**

Run domain tests.

- [ ] **Step 3: Implement service**

Return value objects; repository performs persistence in the next task.

- [ ] **Step 4: Run green tests and commit**

```bash
git add android/core/domain
git commit -m "feat(android): preview smart categorization"
```

### Task 4: Repository Import Save and Rule Persistence

**Files:**
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/ImportRepositoryTest.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`

- [ ] **Step 1: Write failing repository tests**

Verify selected review rows save as transactions with source metadata, duplicate/unselected rows are ignored, merchant rules can be added/disabled, and import save is transactional.

- [ ] **Step 2: Run red tests**

Run data tests.

- [ ] **Step 3: Implement repository methods**

Use Room transactions and existing stable IDs.

- [ ] **Step 4: Run green tests and commit**

```bash
git add android/core/domain android/core/data
git commit -m "feat(android): save reviewed imports"
```

### Task 5: Import Tab Review UI

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/ImportReviewTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing UI test**

Paste statement text, parse rows, deselect one duplicate/review-only row, save selected rows, and verify the transaction appears on the Transactions tab with source metadata text.

- [ ] **Step 2: Run red UI test**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
```

- [ ] **Step 3: Implement UI**

Use review-first language and visible confidence/duplicate state without implying remote AI.

- [ ] **Step 4: Run green UI test and commit**

```bash
git add android/app
git commit -m "feat(android): add import review flow"
```

### Task 6: Parity Ledger and Full Verification

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Update parity ledger**

Add verified entries for strict statement parsing, CSV/plain text/pasted message parsing, spreadsheet rejection, duplicate import review, rule matching, smart categorization preview, and reviewed import save.

- [ ] **Step 2: Run full verification**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
```

Verify APK permissions still omit `android.permission.INTERNET`.

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify import parity"
```

## Self-Review

- Spec coverage: Covers sections 7.7, 7.8, and the rule-learning part of 7.4/7.6. OCR, share target, and policy-isolated SMS ingestion remain Android-native enhancement work, not parity gate work.
- Placeholder scan: Each task lists concrete files, behaviors, commands, and commit scopes.
- Type consistency: Import models live in `core:model`; parser/matcher/services live in `core:domain`; persistence remains in `core:data`.
