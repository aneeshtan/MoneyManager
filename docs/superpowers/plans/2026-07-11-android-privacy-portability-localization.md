# Android Privacy, Portability, and Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the approved parity slice for backup/restore/export, destructive deletion coverage, privacy lock state, notification-permission settings, and localization/accessibility foundations.

**Architecture:** Keep all sensitive data local. Model backup packages in pure Kotlin first, persist settings through the existing repository boundary, and expose compact Settings tools under the current More destination. Full Android document-provider UX and encrypted backup file pickers can be layered after the deterministic core package and restore preview are verified.

**Tech Stack:** Kotlin, kotlinx.serialization or plain deterministic JSON where already available, Room transactions, Jetpack Compose Material 3, JUnit, Truth, AndroidX Compose UI tests.

---

## File Structure

- Create `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/BackupModels.kt`: backup manifest, export compatibility report, restore preview, privacy settings, notification settings, localization settings.
- Create `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/BackupEngine.kt`: complete backup snapshot, legacy export compatibility report, restore preview validation, deterministic round-trip helpers.
- Modify `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`: enumerate table counts for deletion completeness and expose one transaction-safe workspace snapshot boundary if needed.
- Modify `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`: expose backup snapshot/restore preview, privacy settings, notification settings, localization settings, and complete deletion helpers.
- Modify `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`: map complete local snapshot, clear all tables, save settings, and restore transactionally.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: expose settings state/actions.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: add Settings panels for backup, privacy lock, notifications, deletion, and language/region.
- Modify `android/parity/ios-feature-parity.yaml`: add verified privacy/portability/localization entries.

## Tasks

### Task 1: Backup and Export Domain

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/BackupModelsTest.kt`
- Test: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/BackupEngineTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/BackupModels.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/BackupEngine.kt`

- [ ] **Step 1: Write failing tests**

Cover manifest versioning, complete backup inclusion counts for all current persisted record types, legacy iOS JSON incompatibility counts, and restore preview warnings for unsupported/future versions.

- [ ] **Step 2: Run red tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
```

- [ ] **Step 3: Implement backup/export models and pure engine**

Use deterministic model snapshots first. Full ZIP/encrypted envelope file IO remains a later subtask after the pure package contract is verified.

- [ ] **Step 4: Run green tests and commit**

```bash
git add android/core/model android/core/domain
git commit -m "feat(android): model backup portability"
```

### Task 2: Backup Persistence and Restore Preview

**Files:**
- Test: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/BackupRepositoryTest.kt`
- Modify: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`

- [ ] **Step 1: Write failing repository tests**

Verify complete snapshot includes accounts, categories, tags, rules, budgets, schedules, goals, contributions, debt plans, and transactions; restore preview reports counts; restore applies transactionally.

- [ ] **Step 2: Implement repository snapshot/preview/restore**

Keep restore all-or-nothing and reuse existing model validation.

- [ ] **Step 3: Run green data tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:data:testDebugUnitTest
git add android/core/domain android/core/data
git commit -m "feat(android): persist backup restore"
```

### Task 3: Deletion Completeness and Privacy Settings

**Files:**
- Test: `android/core/database/src/test/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabaseTest.kt`
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/PrivacySettingsTest.kt`
- Modify/Create model, DAO, repository settings files as needed.

- [ ] **Step 1: Write failing tests**

Add a deletion completeness guard that fails when any Room table count is omitted. Cover app-lock enabled state, lock timeout, secure-screen redaction, and no telemetry/privacy-support strings.

- [ ] **Step 2: Implement deletion guard and settings models**

Settings can be repository-backed in-memory/data-store-ready for this slice if the interface and UI behavior are deterministic.

- [ ] **Step 3: Run green tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:database:testDebugUnitTest :core:data:testDebugUnitTest
git add android/core/model android/core/database android/core/domain android/core/data
git commit -m "feat(android): verify deletion and privacy settings"
```

### Task 4: Notification and Localization Settings UI

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/SettingsPrivacyPortabilityTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing UI tests**

Verify More exposes Backup, Restore preview, Privacy lock, Notifications, Delete workspace, Language/region settings, and visible disabled/permission explanation without requesting notification permission in this slice.

- [ ] **Step 2: Implement settings UI**

Use compact panels under More. Do not add network, SMS, contacts, notification, or storage permissions.

- [ ] **Step 3: Run green UI tests and commit**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
git add android/app
git commit -m "feat(android): show privacy portability settings"
```

### Task 5: Full Verification and Parity Ledger

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Update ledger**

Add verified entries for complete backup, legacy export compatibility reporting, restore preview, deletion completeness, privacy lock settings, notification settings, and localization/regional settings foundations.

- [ ] **Step 2: Run full verification**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
"$HOME/Library/Android/sdk/build-tools/37.0.0/aapt2" dump permissions app/build/outputs/apk/debug/app-debug.apk
```

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify privacy portability parity"
```

## Self-Review

- Spec coverage: Covers approved sections 7.1, 7.15, 7.16, 8.3, 11, and the localization foundation from 12.
- Permission discipline: No Internet, SMS, contacts, storage, notification, or biometric permissions are introduced in this slice unless a later Android-specific task explicitly justifies them.
- Data safety: Every backup, restore, import, and deletion behavior is deterministic and transaction-tested before UI wiring.
