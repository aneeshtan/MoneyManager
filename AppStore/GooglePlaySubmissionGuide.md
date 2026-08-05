# Pro Money Manager — Google Play Store Submission Guide

Complete step-by-step guide for publishing the Android app to Google Play Store.

---

## 1. PRE-SUBMISSION CHECKLIST

### Development & Build
- [ ] Android app built with `gradle assembleRelease` or `bundleRelease`
- [ ] Minimum SDK: 26 (API 26)
- [ ] Target SDK: 36 or higher
- [ ] App version code incremented (currently at 1 in build.gradle.kts)
- [ ] Version name set (e.g., "1.0.0")
- [ ] All lint warnings resolved (`./gradlew lint`)
- [ ] Test build on actual devices (minimum Android 8.0)

### Signing & Security
- [ ] Signing key pair created and stored securely (separate from version control)
- [ ] Upload key and signing credentials saved in `local.gradle.properties` (gitignored)
- [ ] Release build signed and verified: `./gradlew bundleRelease`
- [ ] Keep signing key backup file (.keystore or .jks) safe — losing it means you can never update this app

### Privacy & Compliance
- [ ] Privacy policy written and published at public URL
- [ ] App manifest reviewed for declared permissions:
  - `android.permission.POST_NOTIFICATIONS` — required for reminders/alerts
  - No camera, location, contacts, or unnecessary permissions
- [ ] Verify no tracking SDKs or analytics in dependencies
- [ ] Review third-party libraries for compliance (PDFBox, Hilt, etc.)

### Localization
- [ ] All UI strings localized (supported languages match iOS app)
- [ ] App name and description localized for supported markets
- [ ] String resources reviewed: `android/app/src/main/res/values/strings.xml`

### Store Listing Assets
- [ ] App icon: 512×512 PNG (high-res icon for Google Play)
- [ ] Feature graphic: 1024×500 PNG (banner for store listing)
- [ ] Screenshots: 4–8 screenshots (1080×1920 for phones, optional tablet sizes)
- [ ] Short description: ≤80 characters
- [ ] Full description: ≤4000 characters
- [ ] Promotional text (optional): ≤80 characters

---

## 2. CREATE/VERIFY GOOGLE PLAY DEVELOPER ACCOUNT

### Setup (one-time)
1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your Google Account (your developer account email)
3. Register as a developer:
   - Pay the one-time $25 registration fee
   - Accept Google Play Developer Program Policies
   - Provide developer/business information

### Account Security
- [ ] Enable 2-factor authentication on Google Account
- [ ] Add trusted devices to Google Play Console
- [ ] Create and save API keys if using Play Console API (optional)

---

## 3. CREATE APP IN GOOGLE PLAY CONSOLE

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Enter app details:
   - **App name**: `Pro Money Manager`
   - **Default language**: English
   - **App or game**: Select **App**
   - **Category**: **Finance**
   - **Type**: Select **Free**
4. Fill in required declarations:
   - Confirm app does not target children (COPPA): No
   - Confirm app does not collect restricted data: Yes

---

## 4. STORE LISTING

### Basic Info
Navigate to **Store listing** in Google Play Console.

#### Short Description (≤80 characters)
```
Secure local-first money manager for bank imports
```

#### Full Description (≤4000 characters)
```
Pro Money Manager is a secure, local-first personal finance app. Your data stays on your Android device — no cloud, no sync, no tracking.

Import bank PDFs, CSV files, or pasted SMS messages, review smart category suggestions, and manage your accounts with full control.

Why Pro Money Manager is different:
• Totally free — no subscriptions, no in-app purchases, no paywalls
• 100% secure — all data stored locally on your device, nothing ever leaves your phone
• No ads — no interruptions, no tracking, no data collection of any kind
• No cloud sync — you own your data completely
• Smart import — PDF, CSV, Excel, or pasted bank SMS messages
• Smart categorization — learns from your history to categorize transactions automatically
• Accounts & insights — track balances, spending trends, and recurring charges
• Export & backup — CSV or JSON export whenever you choose
• Full privacy control — no permissions requested beyond what the app needs
```

#### Promotional Text (optional, ≤80 characters)
```
Local-first finance app. Import, categorize, manage. Your data stays private.
```

### Category
- **App category**: **Finance**
- **Content rating**: Suitable for all ages

### Screenshots
Upload 4–8 screenshots (2–3 recommended for efficient store listing):

**Required dimensions**: 1080×1920 pixels (portrait)

#### Screenshot Captions:
1. **Dashboard** — "See income, expenses, safe-to-spend, and category totals."
2. **Import** — "Import PDF, CSV, Excel, or pasted SMS transactions."
3. **Review** — "Review smart category suggestions before saving."
4. **Categories** — "Drill into category totals and edit transactions."
5. **Privacy** — "Keep finance data local and export only when you choose."

### Feature Graphic
- **Dimensions**: 1024×500 pixels
- Should highlight key value proposition: "Local-first, private, secure"

### App Icon
- **Dimensions**: 512×512 pixels (Google Play requires high-resolution icon)
- Use the same icon as iOS version for consistency
- Can include Android asset studio variations in `android/app/src/main/res/`

### Contact Information
- **Email for support**: Your support email address
- **Website**: Your project website (if available)
- **Privacy policy**: Your public privacy policy URL (if available)

---

## 5. APP PRIVACY & SECURITY

### Privacy Policy
1. Publish privacy policy at a public URL (same as iOS if possible)
2. In Google Play Console, **Privacy** section:
   - Paste URL to privacy policy
3. Confirm data practices:
   - [ ] No personal data collected
   - [ ] No location data
   - [ ] No analytics or crash reporting sent to servers
   - [ ] No third-party SDKs that collect user data

### Data Safety Section
In **Data safety** (Google Play Console):
- **Data collection**: Select **Does not collect or share personal data**
- **Encryption in transit**: Check **Data is encrypted in transit**
- **Security practices**: Describe local-only storage with no network transmission

### Content Rating
1. Go to **Content ratings** in Google Play Console
2. Complete questionnaire:
   - Violence: None
   - Adult content: None
   - Finance-related: Finance (for budget tracking)
   - Alcohol/tobacco: None
   - Gambling: None
3. Receive content rating (usually 4+)

---

## 6. APP SIGNING & RELEASE

### Create Signing Key (First Release Only)

If this is your first release:

1. Generate upload key:
   ```bash
   keytool -genkey -v -keystore ProMoneyManager.keystore \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```
2. Save keystore password, key alias, and key password securely
3. Do **NOT** check keystore file into version control
4. Add to `.gitignore` if not already there

### Configure gradle.properties (local, gitignored)

Add to `android/local.gradle.properties`:
```properties
PROMONEY_UPLOAD_STORE_FILE=/path/to/ProMoneyManager.keystore
PROMONEY_UPLOAD_STORE_PASSWORD=your_keystore_password
PROMONEY_UPLOAD_KEY_ALIAS=upload
PROMONEY_UPLOAD_KEY_PASSWORD=your_key_password
```

This is already referenced in `android/app/build.gradle.kts` signingConfigs.

### Build Release Bundle

```bash
cd android
./gradlew bundleRelease
```

The signed AAB (Android App Bundle) will be generated at:
```
android/app/build/outputs/bundle/release/app-release.aab
```

### Verify Release Build

- [ ] AAB file created successfully
- [ ] File size is reasonable (~15–30 MB is typical)
- [ ] No warnings in gradle output

---

## 7. TESTING BEFORE RELEASE

### Internal Testing Track (Recommended)
1. In Google Play Console, go to **Testing** → **Internal testing**
2. Click **Create new release**
3. Upload app bundle: `app-release.aab`
4. Fill in release notes (from CHANGELOG.md)
5. Add internal testers (emails)
6. Testers receive email link to download from Play Store

### Closed Testing Track (Optional, for beta)
- Same process, but with a larger audience
- Users can opt into beta version
- Useful for wider testing before full release

### Test On Actual Devices
- Install from internal testing track
- Test on Android 8.0 (minSdk 26) through Android 15+
- Verify:
  - App launches and functions
  - PDF/CSV import works
  - All screens render correctly
  - Notifications display properly
  - No crashes or ANRs (Application Not Responding)

---

## 8. CREATE PRODUCTION RELEASE

### Upload Release
1. In Google Play Console, go to **Release** → **Production**
2. Click **Create new release**
3. Upload app bundle: `app-release.aab`
4. Fill in release notes:
   ```
   (Copy from CHANGELOG.md "Unreleased" section)
   ```
5. Set rollout:
   - Start with **25%** rollout (safer)
   - Monitor crash reports for 24 hours
   - Increase to 50%, then 100% if stable

### Review Notes (Optional but Recommended)
Add notes for Google Play reviewers:
```
Pro Money Manager is a local-first personal finance app. It imports user-selected PDF/CSV files or pasted bank notification text, parses the content on device, and stores the resulting records locally using Room database. The app does not use analytics, does not use advertising, does not track users, and does not transmit financial data to any server. Export and backup files are only created when the user explicitly chooses to export.

No background services, no location tracking, and no unnecessary permissions are requested.
```

### Submit for Review
1. Review all information is complete
2. Click **Submit release**
3. Google Play begins review (usually 2–4 hours, sometimes up to 24 hours)

---

## 9. AFTER LAUNCH

### Monitor Release
- [ ] Check Google Play Console **Ratings & reviews** daily
- [ ] Monitor **Crashes & ANRs** dashboard
- [ ] Fix and roll out critical bugs immediately
- [ ] Respond to user reviews (especially negative ones)

### Update Process
For future versions:

1. Increment version code in `android/app/build.gradle.kts`:
   ```kotlin
   versionCode = 2  // Increment this
   versionName = "1.1.0"  // Semantic versioning
   ```

2. Update CHANGELOG.md with new features

3. Build and test:
   ```bash
   ./gradlew bundleRelease
   ```

4. Upload to production or testing track in Google Play Console

5. Follow same review process

---

## 10. TROUBLESHOOTING & FAQ

### Common Issues

#### "App bundle upload failed"
- Verify bundle is valid: `bundletool validate --bundle-path=app-release.aab`
- Check file is not corrupted
- Ensure signing config is correct in gradle.properties

#### "Crashes & ANRs" dashboard shows issues after launch
- Immediately pull release (click "Pause release")
- Fix bugs, increment version code
- Re-test, then re-upload with new version

#### "App rejected during review"
- Check review notes for reason
- Address issues (e.g., privacy policy URL, permissions, etc.)
- Resubmit

#### Cannot incrementally update in future
- You can only update if you keep the signing key safe
- If keystore is lost, you will need to create a new app listing
- **Back up keystore file securely**

### Version Management
- **versionCode**: Must increment with each release (Android requirement)
- **versionName**: Use semantic versioning (1.0.0, 1.1.0, 2.0.0, etc.) for user visibility
- Keep versions in sync with iOS app if possible for consistency

---

## 11. REFERENCES & RESOURCES

- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Google Play App Store Listing Requirements](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Android App Bundle Documentation](https://developer.android.com/guide/app-bundle)
- [Google Play Privacy Policies](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Content Ratings Questionnaire](https://support.google.com/googleplay/android-developer/answer/4646334)

---

## 12. CHECKLIST — READY TO SUBMIT

Before clicking "Submit for review" in Google Play Console:

- [ ] App builds successfully: `./gradlew bundleRelease`
- [ ] App bundle signed with upload key
- [ ] Tested on internal testing track (multiple Android versions)
- [ ] All crashes and ANRs fixed
- [ ] Store listing complete (description, keywords, screenshots, icon)
- [ ] Privacy policy URL set and publicly accessible
- [ ] Content rating questionnaire completed (4+ expected)
- [ ] App privacy section filled out
- [ ] Release notes (from CHANGELOG.md) added
- [ ] Review notes explaining local-first architecture added
- [ ] Support email address confirmed active
- [ ] Version code incremented (currently at 1, ready for 1.0.0 release as versionCode=1)
- [ ] No secrets or sensitive data in app or configuration

---

**Status**: Ready for initial submission once all items above are complete.

*Last updated: 2026-07-26*
