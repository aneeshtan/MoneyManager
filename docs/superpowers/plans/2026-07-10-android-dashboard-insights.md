# Android Dashboard and Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build iOS-parity dashboard, monthly analytics, budgets, search, calendar summaries, and trend ranges on top of the verified local transaction/account/category repository.

**Architecture:** Keep calculations as pure JVM domain services first, add budget persistence in Room through the existing repository, then expose a compact Compose UI in the current shell. Dashboard values never sum different currencies; mixed-currency data is reported as separate totals instead of silently combined.

**Tech Stack:** Kotlin, Room, coroutines/Flow, Jetpack Compose Material 3, JUnit, Truth, AndroidX Compose UI tests.

---

## File Structure

- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/DashboardAnalytics.kt`: monthly income/expense/net totals, ranked category totals, notes, insight cards, recurring merchant detection, and safe-to-spend calculations.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/SearchAndCalendar.kt`: global transaction/account/category search, uncategorized suggestions, daily calendar summaries, and month trend buckets.
- Modify `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`: add `BudgetId`.
- Create `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/BudgetModels.kt`: budget domain model, budget progress, and budget rollover policy.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`: add Room `BudgetEntity`.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`: register `BudgetEntity` and increment schema version.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`: add budget upsert/archive/observe/delete methods.
- Modify `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`: expose budget methods.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`: map budgets and save/archive them.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: expose dashboard, search, calendar, trends, and budget UI state/actions.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: implement Stats dashboard cards plus More entries for Search, Calendar, Trends, and Budgets.
- Modify `android/parity/ios-feature-parity.yaml`: mark verified dashboard/insights/budget/search/calendar/trend entries.

## Tasks

### Task 1: Pure Monthly Dashboard Analytics

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/DashboardAnalyticsTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/DashboardAnalytics.kt`

- [ ] **Step 1: Write failing tests**

Cover:
- selected-month income, expense, and net totals;
- mixed-currency totals stay separate;
- ranked category totals include subcategories;
- notes from selected-month transactions are collected;
- insight cards identify dominant category, uncategorized count, spending increase, and exact duplicate count.

Use transactions with AED and USD to prove no cross-currency summing.

- [ ] **Step 2: Run red tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
```

Expected: fail on missing `DashboardAnalytics`.

- [ ] **Step 3: Implement analytics**

Create value objects:
- `MonthlyDashboardSummary`
- `CurrencyPeriodTotal`
- `CategorySpendTotal`
- `DashboardInsight`

Implementation must use `YearMonth`, integer `Money`, and existing `DuplicateReviewService`.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
git add android/core/domain
git commit -m "feat(android): calculate dashboard analytics"
```

### Task 2: Budget Domain and Progress

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/BudgetModelsTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/BudgetProgressTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/BudgetModels.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/DashboardAnalytics.kt`

- [ ] **Step 1: Write failing tests**

Cover category/subcategory monthly budgets, remaining amount, fraction used, overspent state, and rollover from prior-month unused budget.

- [ ] **Step 2: Run red tests**

Expected: fail on missing budget model/progress APIs.

- [ ] **Step 3: Implement budget models and progress**

`Budget` includes stable ID, category, optional subcategory, month, amount, rollover flag, archived flag, and validation that subcategory requires category.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
git add android/core/model android/core/domain
git commit -m "feat(android): calculate budget progress"
```

### Task 3: Budget Persistence

**Files:**
- Test: `android/core/database/src/test/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabaseTest.kt`
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/BudgetRepositoryTest.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`

- [ ] **Step 1: Write failing persistence tests**

Verify budget upsert, archive/restore, observe order by month/category, and clearWorkspace deletes budgets.

- [ ] **Step 2: Run red tests**

Expected: fail on missing `BudgetEntity` and repository methods.

- [ ] **Step 3: Implement Room and repository mapping**

Use ISO `YYYY-MM` for months. Persist amount as minor units plus currency code. Use Room transaction where budget save is grouped with validation-sensitive operations.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:database:testDebugUnitTest :core:data:testDebugUnitTest
git add android/core/database android/core/domain android/core/data
git commit -m "feat(android): persist monthly budgets"
```

### Task 4: Search, Calendar, and Trends

**Files:**
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/SearchAndCalendarTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/SearchAndCalendar.kt`

- [ ] **Step 1: Write failing tests**

Cover global search across merchants, notes, accounts, and categories; saved filter value objects; uncategorized suggestions; daily income/expense calendar summaries; and six-, twelve-, and twenty-four-month trend buckets.

- [ ] **Step 2: Run red tests**

Expected: fail on missing `SearchAndCalendar`.

- [ ] **Step 3: Implement pure services**

Create:
- `SearchQuery`
- `SearchResult`
- `SavedSearchFilter`
- `DailyCalendarSummary`
- `TrendRange`
- `TrendBucket`

Do not add persistence for saved searches in this slice; represent the value object and expose it in UI memory only.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
git add android/core/domain
git commit -m "feat(android): add search calendar trends"
```

### Task 5: Dashboard and Insights UI

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/DashboardInsightsTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing UI test**

Create state with transactions and budgets; verify Stats shows monthly income/expense/net, safe-to-spend, budget progress, ranked categories, notes, and insights. Verify More can open Search, Calendar, and Trends panels.

- [ ] **Step 2: Run red UI test**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
```

- [ ] **Step 3: Implement UI**

Keep the current single-file app shell for now; extract feature files only if the implementation becomes unsafe to reason about. UI copy must avoid “AI” language and state that insights are local.

- [ ] **Step 4: Run green UI test and commit**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
git add android/app
git commit -m "feat(android): show dashboard insights"
```

### Task 6: Parity Ledger and Full Verification

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Update parity ledger**

Add verified entries for dashboard monthly totals, mixed-currency handling, safe-to-spend, category ranking, insights, budget progress, search, calendar summaries, and trends.

- [ ] **Step 2: Run full verification**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
"$HOME/Library/Android/sdk/build-tools/37.0.0/aapt2" dump permissions app/build/outputs/apk/debug/app-debug.apk
```

Expected: Gradle build succeeds and permissions still omit `android.permission.INTERNET`.

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify dashboard insights parity"
```

## Self-Review

- Spec coverage: Covers approved design sections 7.3 and 7.9 plus budget parts of 7.6. Recurring obligations from schedules are not included until the next planning-tools plan creates schedule models; safe-to-spend accepts obligations as inputs so the integration point is ready.
- Placeholder scan: No TBD/TODO/placeholders remain; every task has concrete files, behaviors, commands, and commit scopes.
- Type consistency: Budget, dashboard, search, calendar, and trend types are introduced before repository/UI usage.
