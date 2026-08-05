# Android Parity Repair — Import, Localization, and Regional Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Android's placeholder PDF, language, and currency claims with complete user workflows matching the approved iOS parity design.

**Architecture:** Keep file access behind an injectable Android document reader, feed extracted text into the existing pure import parser, and retain review-first saving. Store the selected language, base currency, country, and timezone in regional settings; use AndroidX per-app locales plus Android string resources so Compose updates after language changes. Treat parity as verified only when a user-facing test covers the complete workflow.

**Tech Stack:** Kotlin, Jetpack Compose Material 3, Activity Result APIs, Storage Access Framework, AndroidX AppCompat locales, DataStore, coroutines, PDFBox-Android, JUnit, Robolectric, and Compose instrumented tests.

---

## File structure

- `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/importing/ImportDocumentReader.kt`: detect a selected document, extract searchable PDF or UTF-8 text content off the main thread, and return typed metadata.
- `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/importing/ImportDocument.kt`: immutable intake result and typed import failures.
- `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ImportScreen.kt`: file picker, account/source selection, progress, counts, and review list.
- `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/RegionalSettingsScreen.kt`: language, base-currency, country, and timezone controls shared by onboarding and settings.
- `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppLocaleController.kt`: AndroidX locale bridge kept out of domain state.
- `android/app/src/main/res/values*/strings.xml`: complete default resources and translations for English, Spanish, Arabic, Hindi, Persian, German, French, and Portuguese.
- `android/app/src/test/...`: document reader and locale/controller JVM tests.
- `android/app/src/androidTest/...`: end-to-end import, onboarding, locale, RTL, and regional-setting UI tests.
- `android/core/model/.../PrivacySettings.kt`: regional settings gain validated base currency.
- `android/core/data/.../SettingsDataStore.kt`: persist base currency with the existing language, region, and timezone.
- `android/parity/ios-feature-parity.yaml`: record honest end-to-end acceptance and evidence.

### Task 1: Make the parity ledger truthful

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`

- [ ] **Step 1: Downgrade incomplete user workflows**

Change `import.statement-parsing`, `import.review-ui`, and `localization.regional-settings-foundation` from `verified` to `in_progress`. Add separate entries for `import.document-picker`, `import.searchable-pdf`, `localization.runtime-language-switch`, `localization.translated-resources`, and `regional.base-currency-country-timezone`, all initially `in_progress`.

- [ ] **Step 2: Tighten acceptance criteria**

Require user-selected files, extracted PDF text, eight translated resource sets, observable LTR/RTL switching, and persisted editable regional values. Model-only tests or placeholder labels are insufficient evidence.

- [ ] **Step 3: Verify no remaining entry claims a URI placeholder is a parsed document**

Run:

```bash
rg -n "import\.|localization\.|regional\." android/parity/ios-feature-parity.yaml
```

Expected: each user workflow has its own acceptance criterion and an `in_progress` status.

### Task 2: Add a tested document reader

**Files:**
- Modify: `android/gradle/libs.versions.toml`
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/importing/ImportDocument.kt`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/importing/ImportDocumentReader.kt`
- Create: `android/app/src/test/java/com/farshadghanzanfari/promoneymanager/importing/ImportDocumentReaderTest.kt`

- [ ] **Step 1: Write failing document reader tests**

Tests must prove that a generated searchable PDF returns its text, a UTF-8 CSV returns exact content, an empty PDF produces `ImportDocumentFailure.EmptyDocument`, and an unsupported MIME type produces `ImportDocumentFailure.UnsupportedFormat`.

```kotlin
@Test fun extractsTextFromSearchablePdf() = runTest {
    val uri = fixturePdf("Transaction Date Description Amount", "10/06/2026 CAREEM 58.00")
    val result = reader.read(uri, "application/pdf", "statement.pdf")
    assertThat(result.format).isEqualTo(ImportFormat.PDF)
    assertThat(result.text).contains("CAREEM 58.00")
}
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```bash
cd android
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:testDebugUnitTest --tests '*ImportDocumentReaderTest'
```

Expected: compilation fails because the reader types do not exist.

- [ ] **Step 3: Add pinned dependencies**

Add AndroidX AppCompat, Robolectric test support, and `com.tom-roush:pdfbox-android:2.0.27.0`. Do not add storage or network permissions.

- [ ] **Step 4: Implement minimal document reading**

`ImportDocumentReader.read` must use `ContentResolver.openInputStream`, `PDFBoxResourceLoader.init`, `PDDocument.load`, and `PDFTextStripper().getText`. Execute the work on `Dispatchers.IO`, close all streams/documents with `use`, reject blank output as empty/scanned, and cap input size before parsing.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: all `ImportDocumentReaderTest` cases pass.

### Task 3: Connect the system document picker to review-first import

**Files:**
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ImportScreen.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AndroidShareImportIntake.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`
- Modify: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/ImportReviewTest.kt`

- [ ] **Step 1: Write failing Compose tests**

Add tests that assert `Choose PDF or file`, account selector, source counts, `Select clean`, parse progress, and a document error state are visible and actionable. Add a callback seam so the test can provide a fixture URI without automating the system picker.

- [ ] **Step 2: Run the import UI test and verify RED**

Run:

```bash
cd android
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.farshadghanzanfari.promoneymanager.ImportReviewTest
```

Expected: assertions fail because Android only exposes pasted text.

- [ ] **Step 3: Implement document import state**

Add selected account, source name/format, parsing state, progress label, parsed/selected/duplicate/review counts, and typed error text to `AppUiState`. `AppViewModel.importDocument(uri, mimeType, displayName)` reads on IO, passes the detected format and chosen account/currency to `UniversalImportParser`, and never saves until `saveReviewedImport`.

- [ ] **Step 4: Extract and implement `ImportScreen`**

Use `rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument())` with PDF, CSV, plain text, and XLSX MIME types. Preserve paste import. Match the iOS hierarchy: source/account header, document action, metrics, error/progress surface, select-clean action, editable review rows, then save.

- [ ] **Step 5: Parse shared URIs instead of placeholder sentences**

Pass `Intent.EXTRA_STREAM` URI and MIME metadata to the same reader. Keep image shares in explicit OCR-review state and never auto-save.

- [ ] **Step 6: Run import unit and UI tests**

Expected: reader tests and `ImportReviewTest` pass; a selected searchable PDF reaches review rows.

### Task 4: Model and persist complete regional settings

**Files:**
- Modify: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/PrivacySettings.kt`
- Modify: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/PrivacySettingsTest.kt`
- Modify: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/SettingsDataStore.kt`
- Modify: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/SettingsDataStoreTest.kt`
- Modify: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/SettingsRepositoryTest.kt`

- [ ] **Step 1: Write failing model and persistence tests**

```kotlin
@Test fun regionalSettingsPreserveBaseCurrency() {
    val settings = RegionalSettings(baseCurrency = CurrencyCode.of("EUR"), countryCode = "DE", timeZoneId = "Europe/Berlin")
    assertThat(settings.baseCurrency.value).isEqualTo("EUR")
}
```

Persist and recreate `SettingsDataStore`; assert language, base currency, country, and timezone all round-trip and reset to defaults on workspace deletion.

- [ ] **Step 2: Run focused model/data tests and verify RED**

Expected: compilation fails because `baseCurrency` is not part of regional settings.

- [ ] **Step 3: Add validated base currency and DataStore key**

Default to `AED`, store the ISO code, and recover corrupt/unknown values to the default without crashing startup.

- [ ] **Step 4: Run focused tests and verify GREEN**

Expected: all regional settings tests pass.

### Task 5: Add working onboarding and settings selectors

**Files:**
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/RegionalSettingsScreen.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`
- Modify: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/OnboardingTest.kt`
- Modify: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/SettingsPrivacyPortabilityTest.kt`

- [ ] **Step 1: Write failing onboarding/settings tests**

Assert the onboarding displays language, searchable currency, region, and timezone before workspace creation; choosing EUR creates four EUR accounts. Assert More > Language lets an existing user update and persist all four settings without rewriting historical account currencies.

- [ ] **Step 2: Run tests and verify RED**

Expected: selectors are missing and onboarding always creates AED accounts.

- [ ] **Step 3: Implement shared regional selectors**

Provide the iOS currency list, searchable by code/name, region options derived from `Locale`, and timezone options from `ZoneId`. Labels sit above controls, touch targets are at least 48dp, selection state is not color-only, and keyboard/RTL layout remains usable.

- [ ] **Step 4: Wire onboarding and settings persistence**

Change `continueOnDevice` to accept `RegionalSettings`, save them, and seed the workspace with the selected base currency. Add `saveRegionalSettings` to `AppViewModel` for post-onboarding edits.

- [ ] **Step 5: Run tests and verify GREEN**

Expected: onboarding and settings tests pass with AED and EUR cases.

### Task 6: Implement real app-language switching and translations

**Files:**
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppLocaleController.kt`
- Modify: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values-es/strings.xml`
- Create: `android/app/src/main/res/values-ar/strings.xml`
- Create: `android/app/src/main/res/values-hi/strings.xml`
- Create: `android/app/src/main/res/values-fa/strings.xml`
- Create: `android/app/src/main/res/values-de/strings.xml`
- Create: `android/app/src/main/res/values-fr/strings.xml`
- Create: `android/app/src/main/res/values-pt/strings.xml`
- Modify: Android Compose source files containing user-visible hardcoded strings.
- Create: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/LocalizationParityTest.kt`

- [ ] **Step 1: Write failing locale UI tests**

Select Spanish and assert `Importar`; select Arabic and assert translated navigation plus `LayoutDirection.Rtl`; select Persian and assert Persian resources plus persisted Persian-calendar mode. Relaunch and assert the chosen language remains active.

- [ ] **Step 2: Run locale tests and verify RED**

Expected: language controls are read-only and all UI remains English/LTR.

- [ ] **Step 3: Add AndroidX app locale support**

Make `MainActivity` extend `AppCompatActivity`. `AppLocaleController.apply(language)` calls `AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(language.languageTag))` on the main thread. Enable AppCompat locale auto-storage for API 26–32 and automatic locale config generation for Android 13+.

- [ ] **Step 4: Replace hardcoded user copy with resources**

Every string used by onboarding, navigation, Stats, Transactions, Import, More, editors, privacy, planning, empty/loading/error states, shortcuts, widgets, and notifications must resolve through resources. Seed translations from the existing iOS `.lproj/Localizable.strings`, then review Android-specific copy manually.

- [ ] **Step 5: Add all eight complete resource sets**

Each localized file must define every app-owned string key. Arabic and Persian use native translations and automatically mirror layout through `supportsRtl`; no concatenated English sentence may remain in localized UI.

- [ ] **Step 6: Run locale tests and verify GREEN**

Expected: English, Spanish, Arabic RTL, Hindi, Persian RTL, German, French, and Portuguese critical flows render without missing-resource fallback.

### Task 7: Verify and update evidence

**Files:**
- Modify: `android/parity/ios-feature-parity.yaml`
- Modify: `android/README.md`

- [ ] **Step 1: Run the full Android gate**

```bash
cd android
ANDROID_SERIAL=emulator-5554 JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew clean testDebugUnitTest lintDebug assembleDebug bundleRelease connectedDebugAndroidTest
```

Expected: unit, lint, debug APK, release AAB, and connected tests all pass.

- [ ] **Step 2: Audit permissions**

```bash
$HOME/Library/Android/sdk/build-tools/37.0.0/aapt2 dump permissions app/build/outputs/apk/debug/app-debug.apk
```

Expected: no Internet, broad storage, SMS, contacts, location, microphone, or notification-listener permission.

- [ ] **Step 3: Promote only proven entries to verified**

Update the five new ledger entries with exact test/command evidence. Leave any partial workflow `in_progress`.

- [ ] **Step 4: Continue the full parity repair**

Use the same end-to-end evidence rule to audit Transactions, Accounts, Categories/rules, Dashboard customization/drill-down, Search/Calendar/Trends, Planning details, Backup/restore/export, profile, notification settings, attachments, splits, transfers, duplicate merge, and adaptive list-detail flows. Create one focused implementation plan per independent subsystem before changing it.

## Self-review

- Spec coverage: phase one covers the user's reported PDF, multilingual, and currency/regional gaps and establishes the evidence rule required for the broader audit.
- Scope: PDF import and regional/localization are implemented as separate tested boundaries while sharing only app state and Compose navigation.
- Permission discipline: selected documents use the Storage Access Framework; no broad storage or network permission is introduced.
- Data safety: parsing remains review-first and regional changes never rewrite historical transaction/account currencies.
- Placeholder scan: no TBD, TODO, or unspecified error/testing step remains.
