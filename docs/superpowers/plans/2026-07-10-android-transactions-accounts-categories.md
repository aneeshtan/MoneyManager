# Android Transactions, Accounts, Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Android parity slice for account/category/transaction CRUD, tags, attachments metadata, filters, duplicate review, splits, and transfers.

**Architecture:** Extend the existing core modules first so money, relationships, and persistence are correct before UI. Room stores stable IDs rather than mutable iOS names; repository APIs expose domain models and transactional commands; Compose screens consume immutable state from `AppViewModel` until feature modules are split later.

**Tech Stack:** Kotlin, Room, Hilt, coroutines/Flow, Jetpack Compose, Material 3, JUnit, Truth, Robolectric, AndroidX Compose UI tests.

---

## File Structure

- Modify `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`: add IDs for rule, attachment, tag, budget, and import batch.
- Modify `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceModels.kt`: add category, tag, attachment metadata, merchant rule, duplicate candidate, transaction source metadata, transaction filters, and richer transaction fields.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/AccountTypeInferer.kt`: Android parity for iOS `AccountType.inferred(from:)`.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/MerchantNormalizer.kt`: deterministic merchant normalization.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/DuplicateReviewService.kt`: exact and likely duplicate grouping.
- Modify `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`: add CRUD and query commands.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`: add Room tables for categories, tags, transaction tags, attachments, merchant rules, and richer transaction columns.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`: add scoped queries, upserts, deletes, archive/restore, filter queries, and transactions.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`: bump schema version and register new entities.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/DefaultWorkspaceSeeder.kt`: seed iOS-equivalent category/rule templates idempotently.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`: map all new models and implement CRUD transactionally.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: expose transaction/account/category/tag state and user actions.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: replace placeholder tabs with usable account, transaction, category, and tag screens.
- Modify `android/parity/ios-feature-parity.yaml`: add verified entries as each behavior lands.

## Tasks

### Task 1: Account Type Inference and Category/Tag Models

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/AccountTypeInfererTest.kt`
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceModelValidationTest.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceModels.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/AccountTypeInferer.kt`

- [ ] **Step 1: Write failing tests**

Test account type inference for cash, savings/current/bank/ADIB, credit/card, tabby/loan/debt, invest/crypto/stock, and fallback other. Test that categories require non-empty names, subcategories have a different parent, and tags require non-empty names plus six-character hex colors.

- [ ] **Step 2: Run red tests**

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest :core:model:testDebugUnitTest
```

Expected: fail because `AccountTypeInferer`, `Category`, and `Tag` do not exist yet.

- [ ] **Step 3: Implement minimal models and inferer**

Add immutable domain types and validation only. Do not touch Room in this task.

- [ ] **Step 4: Run green tests and commit**

Run the same command. Expected: pass. Commit:

```bash
git add android/core/model android/core/domain
git commit -m "feat(android): model categories and tags"
```

### Task 2: Rich Transaction Domain Model

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/TransactionValidationTest.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceModels.kt`

- [ ] **Step 1: Write failing tests**

Cover required account/date/positive amount, optional category/subcategory, source metadata preservation, tag ID list, attachment metadata list, transfer invariant, and split allocation list.

- [ ] **Step 2: Run red test**

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest
```

Expected: fail on missing richer constructor/properties.

- [ ] **Step 3: Implement richer transaction values**

Preserve the existing transfer helpers and add defaults so existing foundation tests keep compiling.

- [ ] **Step 4: Run green tests and commit**

Run model/domain unit tests, then commit:

```bash
git add android/core/model android/core/domain
git commit -m "feat(android): enrich transaction records"
```

### Task 3: Duplicate Detection and Merchant Normalization

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/MerchantNormalizerTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/DuplicateReviewServiceTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/MerchantNormalizer.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/DuplicateReviewService.kt`

- [ ] **Step 1: Write failing tests**

Use iOS parity examples: normalized merchant collapses punctuation/spacing/case; exact duplicate uses account, local day, amount, currency, and normalized merchant; likely duplicate groups three-day buckets and merchant roots while ignoring all-numeric tokens.

- [ ] **Step 2: Run red tests**

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
```

- [ ] **Step 3: Implement services**

Keep these pure JVM services with no Android dependencies.

- [ ] **Step 4: Run green tests and commit**

Run domain tests, then commit:

```bash
git add android/core/domain
git commit -m "feat(android): detect duplicate transactions"
```

### Task 4: Room Schema for Categories, Tags, Rules, Attachments, and Rich Transactions

**Files:**
- Test: `android/core/database/src/test/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabaseTest.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`

- [ ] **Step 1: Write failing database tests**

Verify category hierarchy, account archive/restore, transaction tag joins, attachment metadata, merchant rule persistence, filtered transaction query, and `clearWorkspace()` deleting all new tables.

- [ ] **Step 2: Run red tests**

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:database:testDebugUnitTest
```

- [ ] **Step 3: Implement Room schema and DAO**

Bump the database version and regenerate Room schema JSON. Stable foreign keys must use IDs.

- [ ] **Step 4: Run green tests and commit**

Run database tests, then commit:

```bash
git add android/core/database
git commit -m "feat(android): persist transaction parity data"
```

### Task 5: Repository CRUD and Idempotent Seeds

**Files:**
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/DefaultWorkspaceSeederTest.kt`
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepositoryCrudTest.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/DefaultWorkspaceSeeder.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`

- [ ] **Step 1: Write failing repository tests**

Verify create/update/delete transactions, archive/restore accounts and categories, create/edit/delete tags, attach/remove attachment metadata, save/delete merchant rules, and seed default iOS-equivalent categories/rules exactly once.

- [ ] **Step 2: Run red tests**

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:data:testDebugUnitTest
```

- [ ] **Step 3: Implement repository commands**

Use Room transactions for multi-table writes and preserve existing local workspace behavior.

- [ ] **Step 4: Run green tests and commit**

Run data/database tests, then commit:

```bash
git add android/core/domain android/core/data android/core/database
git commit -m "feat(android): add workspace crud repository"
```

### Task 6: Compose CRUD Screens

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/CrudFlowTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing UI test**

After local workspace creation, navigate to Accounts, add an account, open Transactions, add an expense with category and tag, edit it, filter by uncategorized/tag/account, and verify it appears in day grouping.

- [ ] **Step 2: Run red UI test**

Run:

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
```

- [ ] **Step 3: Implement UI**

Use Material 3 forms, compact cards with 8dp radius or less, icon buttons for edit/delete/filter, stable semantics for tests, and no landing-page copy.

- [ ] **Step 4: Run green UI test and commit**

Run app connected tests, then commit:

```bash
git add android/app
git commit -m "feat(android): add transaction management screens"
```

### Task 7: Parity Ledger and Full Verification

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`
- Modify: `android/README.md` if verification commands or device notes change.

- [ ] **Step 1: Update parity ledger**

Add entries for account CRUD, archive/restore, category CRUD, tag CRUD, transaction CRUD, filters, attachments metadata, duplicate review, splits, and transfers.

- [ ] **Step 2: Run full verification**

Run:

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
```

Also verify APK permissions have no `android.permission.INTERNET`.

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml android/README.md
git commit -m "test(android): verify transaction parity"
```

## Self-Review

- Spec coverage: This plan covers approved design sections 7.4, 7.5, 7.6, and the duplicate/split/transfer parts of 7.14. Budgets are modeled here only where category detail needs metadata; dashboard budget UX stays in the dashboard plan.
- Placeholder scan: No task uses TBD/TODO/fill-in wording. Each task has concrete files, commands, expected red/green behavior, and commit scope.
- Type consistency: IDs are introduced in `FinanceIds.kt`, values in `FinanceModels.kt`, persistence in `FinanceEntities.kt`, and repository APIs in `WorkspaceRepository.kt`; later tasks depend on those names.
