# Android Native Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first Android-native advantage slice after parity: share-target imports, app shortcuts, privacy-aware widget snapshots, scheduled-transaction notification actions, OCR review intake models, and a disabled SMS policy gate.

**Architecture:** Keep all financial and privacy decisions in pure Kotlin models first, then wire only low-risk Android platform surfaces in the app module. The first slice must not add `INTERNET`, SMS, contacts, location, microphone, call-log, broad media, broad storage, or notification permissions. Platform entry points must route data into the existing review-first import and planning workflows rather than silently saving money data.

**Tech Stack:** Kotlin, Jetpack Compose, Android intent filters, Android app shortcuts, AndroidX Core, JUnit, Truth, Compose UI tests, `aapt2` permission audit.

---

## File Structure

- Create `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModels.kt`: pure models for share targets, shortcut specs, widget snapshots, notification actions, OCR drafts, and SMS policy gating.
- Create `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModelsTest.kt`: pure tests for accepted MIME types, privacy redaction, shortcuts, notification actions, OCR review, and SMS disabled defaults.
- Modify `android/app/src/main/AndroidManifest.xml`: add review-first share intent filters to `MainActivity` without adding permissions.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`: read inbound `ACTION_SEND` text/URI metadata and pass it to app content.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`: accept shared text and OCR drafts into the existing import draft state.
- Modify `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`: expose Android Enhancements under More, show share/shortcut/widget/notification/OCR/SMS status, and keep all review-first copy visible to tests.
- Create `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AndroidNativeEnhancementsTest.kt`: Compose tests for share intake, More status, privacy-aware widgets, notification actions, and SMS disabled disclosure.
- Modify `android/parity/ios-feature-parity.yaml`: add Android-native enhancement evidence entries after verification.

## Tasks

### Task 1: Pure Android Enhancement Models

**Files:**
- Test: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModelsTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModels.kt`

- [ ] **Step 1: Write failing model tests**

Create tests with these cases:

```kotlin
package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class NativeEnhancementModelsTest {
    @Test
    fun shareTargetAcceptsReviewableFinanceInputsOnly() {
        val accepted = listOf("application/pdf", "text/csv", "text/plain", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        val rejected = listOf("image/png", "video/mp4", "application/zip")

        assertThat(accepted.all(ShareTargetSpec::acceptsMimeType)).isTrue()
        assertThat(rejected.none(ShareTargetSpec::acceptsMimeType)).isTrue()
    }

    @Test
    fun shareTargetRoutesEverythingToImportReview() {
        val intake = SharedImportIntake(
            sourceLabel = "Gmail",
            mimeType = "text/plain",
            textPreview = "AED 42.00 CAREEM",
            uriCount = 0,
        )

        assertThat(intake.destination).isEqualTo(AndroidEnhancementDestination.IMPORT_REVIEW)
        assertThat(intake.isReviewRequired).isTrue()
    }

    @Test
    fun widgetSnapshotRedactsMoneyWhenPrivacyRequiresIt() {
        val snapshot = WidgetSnapshot(
            safeToSpend = "AED 800.00",
            monthIncome = "AED 5000.00",
            monthExpense = "AED 4200.00",
            upcomingBill = "Rent tomorrow",
            privacyMode = WidgetPrivacyMode.REDACTED,
        )

        val redacted = snapshot.display()

        assertThat(redacted.safeToSpend).isEqualTo("Hidden")
        assertThat(redacted.monthIncome).isEqualTo("Hidden")
        assertThat(redacted.monthExpense).isEqualTo("Hidden")
        assertThat(redacted.upcomingBill).isEqualTo("Open app")
    }

    @Test
    fun shortcutsExposeExpectedAndroidActions() {
        assertThat(AppShortcutSpec.defaults().map { it.id }).containsExactly(
            "add_expense",
            "import_statement",
            "search",
            "upcoming_bills",
        ).inOrder()
    }

    @Test
    fun scheduledNotificationActionsAreReviewableAndLocal() {
        val actions = ScheduledNotificationAction.defaults()

        assertThat(actions.map { it.id }).containsExactly("post", "skip", "open").inOrder()
        assertThat(actions.all { it.requiresNetwork.not() }).isTrue()
    }

    @Test
    fun ocrDraftRequiresReviewBeforeApplyingFields() {
        val draft = OcrReviewDraft(
            sourceLabel = "Receipt camera",
            recognizedText = "Coffee AED 18.50",
            confidence = OcrConfidence.LOW,
        )

        assertThat(draft.destination).isEqualTo(AndroidEnhancementDestination.IMPORT_REVIEW)
        assertThat(draft.canAutoSave).isFalse()
    }

    @Test
    fun smsCapabilityIsDisabledUntilPolicyApproval() {
        val policy = SmsIngestionPolicy()

        assertThat(policy.isEnabled).isFalse()
        assertThat(policy.requiredConditions).contains("Google Play SMS permission approval")
        assertThat(policy.requiresSeparateBuildWithoutSmsPermission).isTrue()
    }
}
```

- [ ] **Step 2: Run red model tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest --tests com.farshadghanzanfari.promoneymanager.core.model.NativeEnhancementModelsTest
```

Expected: compile failure for missing native enhancement model classes.

- [ ] **Step 3: Implement minimal models**

Create `NativeEnhancementModels.kt` with the enums, data classes, and helpers required by the tests. `ShareTargetSpec.acceptsMimeType` must accept exact PDF, CSV, plain text, and XLSX MIME types plus `text/*`, and reject image/video/zip by default. `WidgetSnapshot.display()` must return hidden values in `REDACTED` mode and original values in `VISIBLE` mode. `SmsIngestionPolicy` must default to disabled.

- [ ] **Step 4: Run green model tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest --tests com.farshadghanzanfari.promoneymanager.core.model.NativeEnhancementModelsTest
git add android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModels.kt android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/NativeEnhancementModelsTest.kt
git commit -m "feat(android): model native enhancement gates"
```

### Task 2: Share Target Intake

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AndroidNativeEnhancementsTest.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`

- [ ] **Step 1: Write failing connected share-intake test**

Add a test that launches `ProMoneyManagerContent` with shared statement text, asserts the Import destination is selected, asserts the shared text appears in `Paste statement text`, and asserts parsing remains review-first with the existing `Parse` button.

- [ ] **Step 2: Run red connected test**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.farshadghanzanfari.promoneymanager.AndroidNativeEnhancementsTest
```

Expected: missing test hooks or missing share intake behavior.

- [ ] **Step 3: Implement manifest and intake wiring**

Add `ACTION_SEND` intent filters for `application/pdf`, `text/csv`, `text/plain`, and XLSX to `MainActivity`. In `MainActivity`, read `Intent.EXTRA_TEXT` and MIME type from `ACTION_SEND`, then seed the import draft through `AppViewModel`. URI imports must show review metadata but must not read broad storage directly in this slice.

- [ ] **Step 4: Run green connected share test and commit**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.farshadghanzanfari.promoneymanager.AndroidNativeEnhancementsTest
git add android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AndroidNativeEnhancementsTest.kt android/app/src/main/AndroidManifest.xml android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt
git commit -m "feat(android): add review-first share intake"
```

### Task 3: Shortcuts, Widgets, Notification Actions, OCR, and SMS Status UI

**Files:**
- Test: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AndroidNativeEnhancementsTest.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`
- Modify: `android/app/src/main/res/values/strings.xml`

- [ ] **Step 1: Add failing UI status tests**

Extend `AndroidNativeEnhancementsTest` to open `More`, select `Android`, and assert visible text:

- `Share target imports`
- `Add expense shortcut`
- `Import statement shortcut`
- `Widget values hidden while privacy lock is active`
- `Notification actions: Post, Skip, Open`
- `Receipt OCR drafts require review`
- `SMS import disabled until Play policy approval`

- [ ] **Step 2: Run red connected status test**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.farshadghanzanfari.promoneymanager.AndroidNativeEnhancementsTest
```

Expected: Android panel/status text is missing.

- [ ] **Step 3: Implement More Android panel**

Add `MorePanel.ANDROID` and a compact `AndroidEnhancementsPanel` that renders the pure model status. Do not add runtime permission requests. Keep SMS disabled and explicit. Keep OCR as review-draft status only.

- [ ] **Step 4: Run green connected status test and commit**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.farshadghanzanfari.promoneymanager.AndroidNativeEnhancementsTest
git add android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/AndroidNativeEnhancementsTest.kt android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt android/app/src/main/res/values/strings.xml
git commit -m "feat(android): show native enhancement status"
```

### Task 4: Parity Ledger and Release Gates

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Add Android-native ledger entries**

Add verified entries after tests pass:

- `android.share-target-imports`
- `android.dynamic-shortcuts`
- `android.privacy-aware-widget-snapshots`
- `android.notification-actions`
- `android.ocr-review-intake`
- `android.sms-policy-gate`

- [ ] **Step 2: Run full verification**

```bash
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug bundleRelease connectedDebugAndroidTest
"$HOME/Library/Android/sdk/build-tools/37.0.0/aapt2" dump permissions app/build/outputs/apk/debug/app-debug.apk
test -f app/build/outputs/bundle/release/app-release.aab
```

Expected: Gradle succeeds, connected tests pass, AAB exists, and permission audit contains no Internet, SMS, contacts, location, microphone, call-log, broad media, broad storage, or notification permissions.

- [ ] **Step 3: Commit evidence**

```bash
git add android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify native enhancement gates"
```

## Verification

- Focused model tests prove behavior before platform wiring.
- Connected tests prove the user-facing Android panel and review-first share intake.
- Full verification must pass before ledger entries become `verified`.
- Permission audit must remain clean. SMS stays disabled unless a later separate policy-approved plan adds the permission path and a no-SMS build variant.

## Scope Limits

This first enhancement plan does not implement live SMS ingestion, notification-listener access, broad file scanning, network OCR, cloud backup, or Wear OS. It establishes the Android-native entry points and policy gates needed to add deeper implementations without compromising the parity release.
