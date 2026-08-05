# Android App Lock Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce a persistent biometric/device-credential app lock and secure-screen boundary without exposing finance data before authentication.

**Architecture:** Persist immutable setting models through one injected Preferences DataStore. Put a deterministic session-timeout policy in the model layer and a fail-closed biometric gate above all workspace UI, with window security applied by the activity.

**Tech Stack:** Kotlin, Jetpack Compose, AndroidX Biometric, Preferences DataStore, Hilt, Coroutines/Flow, JUnit, Robolectric, Compose UI tests.

---

### Task 1: Persist settings

**Files:**
- Create: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/SettingsDataStore.kt`
- Create: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/SettingsDataStoreTest.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`
- Modify: `android/core/data/build.gradle.kts`

- [ ] Write a failing persistence and reset test.
- [ ] Run the focused test and confirm the missing implementation failure.
- [ ] Implement the singleton DataStore source and repository delegation.
- [ ] Run the focused data tests and confirm they pass.
- [ ] Commit the settings persistence change.

### Task 2: Model lock session policy

**Files:**
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/AppLockSessionPolicy.kt`
- Create: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/AppLockSessionPolicyTest.kt`

- [ ] Write failing boundary tests for immediate and delayed relock.
- [ ] Run the focused model test and confirm failure.
- [ ] Implement the pure policy.
- [ ] Run the focused model tests and confirm they pass.
- [ ] Commit the session policy.

### Task 3: Enforce authentication and secure-window behavior

**Files:**
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppLockGate.kt`
- Create: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AppLockSecurityTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/gradle/libs.versions.toml`

- [ ] Write failing UI/platform tests that require a fail-closed lock surface and secure window.
- [ ] Run the focused connected test and confirm failure.
- [ ] Add stable AndroidX Biometric and implement authenticator availability, prompt callbacks, retry, lifecycle timeout, and secure-window policy.
- [ ] Require successful authentication before enabling the setting.
- [ ] Run focused connected tests and lint.
- [ ] Commit the enforced app-lock change.

### Task 4: Release verification and evidence

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] Run all unit tests, lint, debug assembly, and release bundle generation.
- [ ] Run all connected Android tests.
- [ ] Audit APK permissions and confirm no new sensitive permission.
- [ ] Update the parity ledger with exact evidence.
- [ ] Commit the verified milestone.
