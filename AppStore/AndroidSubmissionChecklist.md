# Pro Money Manager — Android App Store Submission Checklist

Pre-submission verification for Google Play Store release.

---

## App Privacy & Compliance

- [ ] **No data collection**: App does not collect personal data
- [ ] **No analytics**: No Firebase Analytics, Mixpanel, or similar SDKs
- [ ] **No tracking**: No Google Analytics, Amplitude, or ad tracking pixels
- [ ] **No advertising SDKs**: No Google Mobile Ads, Facebook Ads, or similar
- [ ] **No crash reporting**: No Crashlytics or remote crash logging (local-only)
- [ ] **No third-party authentication**: Only local workspace (future: Sign in with Google optional)
- [ ] **All data local**: All transactions stored in Room database on device only
- [ ] **No network transmission**: No sync, no cloud storage, no backend calls

## Permissions

### Declared in AndroidManifest.xml
- [ ] `android.permission.POST_NOTIFICATIONS` — for reminders/alerts
- [ ] All other permissions removed or justified

### NOT Requested
- [ ] No camera access
- [ ] No microphone access
- [ ] No location access
- [ ] No contacts access
- [ ] No calendar access
- [ ] No file system full access (scoped storage used)

## Dependencies Review

- [ ] PDFBox (PDF parsing) — no data collection
- [ ] Hilt (dependency injection) — compile-time only
- [ ] Compose (UI framework) — no telemetry in personal use
- [ ] Room (database) — local only
- [ ] DataStore (preferences) — local only
- [ ] WorkManager (scheduled tasks) — local only
- [ ] No unexpected transitive dependencies added (review `gradle dependencies`)

## Build Configuration

- [ ] Minimum SDK: 26 (Android 8.0)
- [ ] Target SDK: 36 or higher
- [ ] Compile SDK: 37 (or latest stable)
- [ ] R8 code shrinking enabled: `isMinifyEnabled = true`
- [ ] ProGuard rules configured: `proguard-rules.pro`
- [ ] Shrink resources enabled: `isShrinkResources = true`

## Signing & Security

- [ ] Signing key created (upload key)
- [ ] Keystore file stored securely outside repository
- [ ] Keystore credentials in local `gradle.properties` (gitignored)
- [ ] Release bundle signed: `./gradlew bundleRelease`
- [ ] Bundle verified: `bundletool validate --bundle-path=app-release.aab`
- [ ] Signing key backup saved in secure location (separate from repo)

## Testing

- [ ] **Unit tests pass**: `./gradlew test`
- [ ] **Lint passes**: `./gradlew lint` (no critical issues)
- [ ] **Compose preview issues resolved**: No render issues in Compose Previews
- [ ] **Tested on physical devices**:
  - [ ] Android 8.0 (minSdk 26)
  - [ ] Android 11 (API 30)
  - [ ] Android 13+ (latest available)
- [ ] **No crashes on launch**
- [ ] **Import flow tested**: PDF, CSV, SMS import all work
- [ ] **Large import tested**: 1000+ transactions import without crash
- [ ] **Export tested**: CSV and JSON export work
- [ ] **Notifications tested**: Reminders and alerts display correctly
- [ ] **Database upgrade tested**: No migration issues
- [ ] **No ANRs (Application Not Responding)** detected during testing

## Localization

- [ ] All UI strings localized in `values/strings.xml`
- [ ] Supporting languages match iOS version:
  - [ ] English (en)
  - [ ] Spanish (es)
  - [ ] French (fr)
  - [ ] German (de)
  - [ ] Portuguese (pt)
  - [ ] Chinese Simplified (zh-rCN)
  - [ ] Japanese (ja)
- [ ] App name, category, and format strings localized
- [ ] Number and currency formatting locale-aware

## Google Play Store Listing

### App Name & Category
- [ ] App name: **Pro Money Manager**
- [ ] Category: **Finance**
- [ ] Content rating: **4+** (expected after questionnaire)
- [ ] Free or paid: **Free**

### Store Listing Text
- [ ] **Short description**: ≤80 characters, concise and compelling
- [ ] **Full description**: ≤4000 characters, formatted with bullet points
- [ ] **Promotional text**: ≤80 characters (optional but recommended)
- [ ] Language-specific versions: All text localized for supported languages

### Assets
- [ ] **App icon**: 512×512 PNG, matches iOS icon
- [ ] **Feature graphic**: 1024×500 PNG, highlights key features
- [ ] **Screenshots**: 4–8 screenshots at 1080×1920 pixels
  - [ ] Dashboard view
  - [ ] Import flow
  - [ ] Review/categorization
  - [ ] Category insights
  - [ ] Privacy/export
- [ ] **Screenshots have captions**: Each screenshot has descriptive text

### Store Listing Metadata
- [ ] **Privacy policy URL**: Public, accessible, comprehensive
- [ ] **Support email**: Your support email verified as active
- [ ] **Website URL** (optional): Set if domain available
- [ ] **Contact email**: Valid and monitored

## Privacy & Security Declarations

### Google Play Privacy Forms
- [ ] **Data collection**: "Does not collect personal data"
- [ ] **Data sharing**: "Does not share personal data"
- [ ] **Data retention**: "Data deleted on uninstall"
- [ ] **Encryption**: "Data encrypted in transit (no network calls)"
- [ ] **Security practices**: "Local-only storage, no remote servers"

### Content Rating Questionnaire
- [ ] **Violence**: None
- [ ] **Adult content**: None
- [ ] **Finance**: Yes (personal finance management)
- [ ] **Alcohol/tobacco**: None
- [ ] **Gambling**: None
- [ ] **Other restrictions**: None

## Release Notes & Documentation

- [ ] **CHANGELOG.md updated** with new features for v1.0.0
- [ ] **Release notes drafted** for Google Play Store
- [ ] **Review notes prepared** explaining local-first architecture:
  ```
  Pro Money Manager is a local-first personal finance app. 
  It imports user-selected PDF/CSV files or pasted bank messages, 
  parses content on-device, and stores records locally using Room database. 
  No data is transmitted to any server. The app does not use analytics, 
  does not use advertising, does not track users, and all data remains 
  completely private on the user's device.
  ```

## Version Management

- [ ] **Version code**: Set to appropriate number (1 for first release)
- [ ] **Version name**: Set to semantic version (e.g., "1.0.0")
- [ ] **Version consistent with iOS**: Coordinate with iOS release if simultaneous
- [ ] **BuildConfig version strings**: Verified in app

## Before Uploading to Google Play Console

- [ ] App builds successfully: `./gradlew bundleRelease`
- [ ] Bundle file exists: `android/app/build/outputs/bundle/release/app-release.aab`
- [ ] Bundle file size reasonable: 15–30 MB typical
- [ ] No sensitive data in bundle (check with `bundletool inspect`)
- [ ] All local.gradle.properties secrets properly gitignored
- [ ] No debug symbols or test code in release build
- [ ] Icons and graphics at correct resolution and format
- [ ] Screenshots match actual app appearance on latest Android

## First Submission Specific

- [ ] Google Play Developer Account created
- [ ] $25 registration fee paid
- [ ] Account verified with phone number
- [ ] 2-factor authentication enabled
- [ ] Create app in Google Play Console completed
- [ ] Internal testing track created and tested (minimum 1 tester)
- [ ] Feedback from internal testers addressed
- [ ] Ready for production release

## After Submission

- [ ] Set up monitoring: Check Google Play Console daily
- [ ] Monitor dashboard:
  - [ ] **Ratings & reviews**: Respond to feedback
  - [ ] **Crashes & ANRs**: Address critical issues immediately
  - [ ] **Statistics**: Track installs, uninstalls, retention
- [ ] Plan response strategy for negative reviews
- [ ] Document any critical bugs found in production
- [ ] Plan minor updates or patches if needed

---

## Critical Reminders

⚠️ **DO NOT LOSE SIGNING KEY**
- The upload key controls all future versions of this app
- If lost, you cannot update the app — you must create a new listing
- Keep keystore file backup in a secure, separate location
- Back up keystore password, key alias, and key password separately

⚠️ **Version Code Must Increment**
- Every new release requires a higher `versionCode`
- Cannot decrease or reuse version codes
- Google Play enforces this strictly

⚠️ **Privacy First**
- Ensure privacy policy is published and URL is correct
- Any changes to permissions or data handling require privacy policy update
- Google Play reviews your privacy declarations carefully

---

## Submission Status

Use this checklist to track progress:

1. **Pre-build phase** — [ ] Verify all code changes and dependencies
2. **Build phase** — [ ] Build and test release bundle locally
3. **Assets phase** — [ ] Prepare store listing text, screenshots, icon
4. **Legal phase** — [ ] Privacy policy, review notes, disclaimers
5. **Console setup** — [ ] Create app in Google Play Console, fill metadata
6. **Testing phase** — [ ] Internal testing track, fix reported issues
7. **Final phase** — [ ] Create production release, submit for review
8. **Launch phase** — [ ] Monitor review progress, handle review feedback
9. **Post-launch** — [ ] Monitor ratings, crashes, user feedback

---

*Last updated: 2026-07-26*

Ready for submission when all items above are checked.
