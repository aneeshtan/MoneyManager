# Android Planning Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build iOS-parity planning tools for scheduled transactions, day-before reminder plans, savings goals with contribution history, debt payoff plans, and derived subscription detection.

**Architecture:** Model planning records as local-first immutable domain objects in `:core:model`, pure calculators in `:core:domain`, Room persistence through the existing repository, and compact Compose panels in the current `More` destination. Actual Android notification posting remains a later platform integration; this slice creates deterministic reminder plans and visible disabled/permission states without requesting notification permissions.

**Tech Stack:** Kotlin, Room, coroutines/Flow, Jetpack Compose Material 3, JUnit, Truth, AndroidX Compose UI tests.

---

## File Structure

- Create `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/PlanningModels.kt`: schedule, reminder plan, savings goal, contribution, debt payoff plan, subscription candidate domain types.
- Modify `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`: add schedule, goal, contribution, and debt-plan IDs.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/PlanningCalculators.kt`: next occurrence, post-now transaction factory, reminder plan, savings progress, debt amortization, subscription detection.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`: add Room entities for schedules, savings goals, goal contributions, and debt payoff plans.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`: register planning entities and increment schema version.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`: add observe/upsert/archive/delete DAO methods and clear-workspace coverage.
- Modify `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`: expose planning repository methods.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`: map planning entities and save posted scheduled transactions transactionally.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: expose planning state/actions.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: add Schedule, Goals, Debt Payoff, and Subscriptions panels under More.
- Modify `android/parity/ios-feature-parity.yaml`: mark verified planning entries.

## Tasks

### Task 1: Schedule and Reminder Domain

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/PlanningModelsTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/ScheduleCalculatorTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/PlanningModels.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/PlanningCalculators.kt`

- [ ] **Step 1: Write failing tests**

Cover schedule validation, weekly/biweekly/monthly/quarterly/yearly next occurrence, pause/resume state, day-before 09:00 reminder plan in a selected zone, and posting a scheduled expense now with source metadata while advancing the next date.

- [ ] **Step 2: Run red tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
```

Expected: fail on missing planning models/calculators.

- [ ] **Step 3: Implement schedule models and calculators**

Create `ScheduleFrequency`, `ScheduleStatus`, `ScheduledTransaction`, `ReminderPlan`, `NotificationAvailability`, and `ScheduleCalculator`. Keep money exact and support expense/income/transfer schedule kinds; transfer posting can produce one user-facing scheduled transaction in this slice and balanced transfer expansion remains through existing transfer code when UI adds full transfer editing.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
git add android/core/model android/core/domain
git commit -m "feat(android): model scheduled planning"
```

### Task 2: Savings Goals Domain

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/SavingsGoalTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/SavingsGoalCalculatorTest.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/PlanningModels.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/PlanningCalculators.kt`

- [ ] **Step 1: Write failing tests**

Cover goal validation, progress, remaining amount, completion state, archive/restore fields, contribution and withdrawal history, and current amount compatibility with contribution audit trail.

- [ ] **Step 2: Run red tests**

Expected: fail on missing savings goal APIs.

- [ ] **Step 3: Implement savings goal models/calculators**

Use `SavingsGoal`, `SavingsGoalContribution`, `SavingsGoalProgress`, and `SavingsGoalCalculator.applyContribution`. Withdrawals clamp at zero and contributions require matching currency.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
git add android/core/model android/core/domain
git commit -m "feat(android): model savings goals"
```

### Task 3: Debt Payoff and Subscription Detection Domain

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/DebtPayoffTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/PlanningDetectionTest.kt`
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/PlanningModels.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/PlanningCalculators.kt`

- [ ] **Step 1: Write failing tests**

Cover debt plan validation, snowball/avalanche labels, monthly payment, percentage paid, estimated months remaining, non-amortizing payment guard, subscription candidates from two or more charge months, next expected charge, sample count, and price increase detection.

- [ ] **Step 2: Run red tests**

Expected: fail on missing debt/subscription APIs.

- [ ] **Step 3: Implement debt and subscription services**

Use `DebtPayoffPlan`, `DebtPayoffSummary`, `DebtPayoffStrategy`, `SubscriptionCandidate`, and `SubscriptionDetector`. Debt calculations may use `Double` for rate math but persisted money remains `Money`; invalid plans return explanatory summary instead of crashing.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
git add android/core/model android/core/domain
git commit -m "feat(android): model debt and subscriptions"
```

### Task 4: Planning Persistence

**Files:**
- Test: `android/core/database/src/test/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabaseTest.kt`
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/PlanningRepositoryTest.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`
- Modify: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`

- [ ] **Step 1: Write failing persistence tests**

Verify schedule, savings goal, contribution, and debt plan upsert/observe/archive/delete behavior; clearWorkspace deletes planning tables; posting a scheduled item saves a transaction and advances schedule state transactionally.

- [ ] **Step 2: Run red tests**

Expected: fail on missing Room entities and repository methods.

- [ ] **Step 3: Implement persistence**

Increment Room schema version, add auto-migration for new tables, map all planning models, and use database transactions for contribution and schedule-post operations.

- [ ] **Step 4: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:database:testDebugUnitTest :core:data:testDebugUnitTest
git add android/core/database android/core/domain android/core/data
git commit -m "feat(android): persist planning tools"
```

### Task 5: Planning UI

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/PlanningToolsTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing UI test**

Verify More exposes Schedule, Goals, Debt Payoff, and Subscriptions; sample actions add one schedule/goal/debt plan; subscription detection lists a repeated merchant from transaction history; paused/upcoming and reminder-disabled states are visible.

- [ ] **Step 2: Run red UI test**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
```

- [ ] **Step 3: Implement planning UI**

Use compact panels under More, consistent with the existing app shell. Do not request notification permission in this slice; display reminder plans and disabled/permission status only.

- [ ] **Step 4: Run green UI test and commit**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
git add android/app
git commit -m "feat(android): show planning tools"
```

### Task 6: Parity Ledger and Full Verification

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Update parity ledger**

Add verified entries for scheduled transactions/reminder plans, savings goals/contribution history, debt payoff plans, and subscription detection.

- [ ] **Step 2: Run full verification**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
"$HOME/Library/Android/sdk/build-tools/37.0.0/aapt2" dump permissions app/build/outputs/apk/debug/app-debug.apk
```

Expected: Gradle build succeeds and permissions still omit `android.permission.INTERNET`.

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify planning parity"
```

## Self-Review

- Spec coverage: Covers approved design sections 7.10 through 7.13. Notification scheduling is represented as deterministic reminder plans and visible disabled/permission state; actual Android notification scheduling/actions remain Stage C per the approved spec.
- Placeholder scan: No TBD/TODO/placeholders remain; every task has concrete files, behaviors, commands, and commit scopes.
- Type consistency: IDs, models, calculators, repository methods, database entities, and UI panels are introduced before use.
