# Android Google Play Store Readiness Summary

Quick reference for what's needed to publish Pro Money Manager on Android.

---

## Current App Status

| Aspect | Status | Notes |
|--------|--------|-------|
| Android codebase | ✅ Ready | Full Kotlin/Compose implementation matches iOS |
| Min/Target SDK | ✅ Ready | minSdk 26 (Android 8.0), targetSdk 36 |
| Build signing | ✅ Configured | Signing config ready, needs local keystore |
| Privacy compliance | ✅ Ready | No tracking, analytics, or data collection |
| Localization | ✅ Ready | 7 languages supported |
| Database | ✅ Ready | Room database, local-only storage |
| Permissions | ✅ Minimal | Only POST_NOTIFICATIONS declared |

---

## What You Need Before Submitting

### 1. Signing Key (First Time Only)
**Current state**: Signing config exists but keystore not checked in (correct).

**What to do**:
```bash
# Generate once and save securely
keytool -genkey -v -keystore ProMoneyManager.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Add credentials to `android/local.gradle.properties` (already gitignored):
```properties
PROMONEY_UPLOAD_STORE_FILE=/path/to/ProMoneyManager.keystore
PROMONEY_UPLOAD_STORE_PASSWORD=your_password
PROMONEY_UPLOAD_KEY_ALIAS=upload
PROMONEY_UPLOAD_KEY_PASSWORD=your_key_password
```

### 2. Google Play Developer Account
**Current state**: Not yet set up.

**What to do**:
- Go to [Google Play Console](https://play.google.com/console)
- Sign in with your developer account email
- Pay $25 one-time registration fee
- Create app listing for "Pro Money Manager"
- Fill in store metadata (description, screenshots, etc.)

### 3. Store Listing Assets (Same as iOS)
**Current state**: iOS assets exist; Android uses different dimensions.

**What to do**:
- App icon: 512×512 PNG (high-res, same as iOS)
- Feature graphic: 1024×500 PNG (banner)
- Screenshots: 4–8 at 1080×1920 pixels (portrait phones)
- Use same messaging and branding as iOS version

All copy/metadata can be adapted from `AppStore/CompleteSubmissionGuide.md`.

### 4. Privacy Policy
**Current state**: iOS policy exists at specified URL.

**What to do**:
- Verify same privacy policy is published at public URL
- Use same URL in both iOS and Android listings
- Google Play requires privacy policy for all apps

### 5. Testing
**Current state**: App needs final testing on real devices.

**What to do**:
```bash
cd android

# Build release bundle
./gradlew bundleRelease

# Validate bundle
bundletool validate --bundle-path=app/build/outputs/bundle/release/app-release.aab

# Test on devices running Android 8.0–15+
# Verify: import, export, notifications, no crashes
```

---

## iOS vs Android: Key Differences

| Requirement | iOS (App Store) | Android (Google Play) | Notes |
|-------------|-----------------|----------------------|-------|
| **Bundle Format** | `.ipa` archive | `.aab` (App Bundle) | Android uses modern bundle format |
| **Signing** | Apple Developer Cert | Keystore (RSA 2048) | Different signing authorities |
| **Manifest** | Xcode-managed | AndroidManifest.xml | Explicit in Android |
| **Permissions** | Info.plist | AndroidManifest.xml | Android requires explicit declaration |
| **Review Time** | 24–48 hours typical | 2–4 hours typical | Google Play reviews faster |
| **Testing Track** | TestFlight | Internal testing | Both offer beta testing |
| **Privacy Policy** | Required URL | Required URL | Same policy can be used |
| **Screenshots** | 6.7", 6.9" iPhone | 1080×1920 phone | Different aspect ratios |
| **Content Rating** | Age rating form | Content rating questionnaire | Similar but different forms |
| **Version Mgmt** | CFBundleVersion | versionCode (int) | Android: must increment always |
| **Release Process** | Staged rollout | Staged rollout (25%→100%) | Both support gradual rollout |

---

## Step-by-Step Submission Workflow

### Phase 1: Prepare (This Week)
1. Create Google Play Developer Account ($25)
2. Generate signing key and save securely
3. Build release bundle: `./gradlew bundleRelease`
4. Test on Android 8.0, 11, and 13+ devices
5. Verify import, export, notifications work

### Phase 2: Create Listing (Before Upload)
1. Log into Google Play Console
2. Create new app: "Pro Money Manager"
3. Fill in store listing:
   - Short description (80 chars)
   - Full description (4000 chars, from iOS guide adapted)
   - Screenshots (1080×1920, 4–5 needed)
   - App icon (512×512)
   - Feature graphic (1024×500)
   - Privacy policy URL
   - Support email

### Phase 3: Submit for Review
1. Create internal testing release (recommended first)
2. Add internal testers, gather feedback
3. Fix any issues found
4. Create production release
5. Upload signed `.aab` bundle
6. Submit for review
7. Wait 2–4 hours for approval

### Phase 4: Launch & Monitor
1. Approve release when review passes
2. Start with 25% rollout
3. Monitor crash rates for 24 hours
4. Increase rollout to 50%, then 100% if stable
5. Monitor ratings and reviews daily

---

## Key Files & Locations

| Item | Location | Status |
|------|----------|--------|
| Build config | `android/app/build.gradle.kts` | ✅ Ready |
| Manifest | `android/app/src/main/AndroidManifest.xml` | ✅ Ready |
| Strings (localized) | `android/app/src/main/res/values*` | ✅ Ready |
| ProGuard rules | `android/app/proguard-rules.pro` | ✅ Ready |
| Signing config | (Gradle config, keystore is local only) | ⚠️ Keystore needed |
| Release bundle | `android/app/build/outputs/bundle/release/app-release.aab` | 🔨 Build on demand |

---

## Critical Reminders

### 🔑 Signing Key Security
- **Never** check keystore into git (already in `.gitignore`)
- **Keep a backup** of `.keystore` file in secure location
- **Backup password** separately from keystore file
- **Losing the key** means you must create a new app listing (cannot update existing)

### 📦 Version Management
- First release: `versionCode=1`, `versionName="1.0.0"`
- Every future release must increment `versionCode` (cannot reuse or decrease)
- `versionName` can be any string, but use semantic versioning (1.0.0, 1.1.0, etc.)

### 🔒 Privacy First
- No tracking SDKs, analytics, or crash reporting
- All data stays on device (no sync, no cloud)
- Privacy policy must be publicly accessible
- Google Play reviews privacy compliance carefully

### ✅ Testing
- Test on minimum SDK (Android 8.0) and latest SDK
- Test import with large files (1000+ transactions)
- Verify notifications work
- Check for crashes and ANRs

---

## Estimated Timeline

| Phase | Time Required | Notes |
|-------|---------------|-------|
| Signing key setup | 15 minutes | One-time, keep forever |
| Build & test | 1–2 hours | Depends on testing scope |
| Google Play account | 10 minutes | One-time, $25 fee |
| Store listing | 30 minutes–1 hour | Copy from iOS guide |
| Internal testing | 2–4 hours | Wait for tester feedback |
| Fix feedback | 1–2 hours | Address any issues |
| Production submission | 5 minutes | Upload and submit |
| Review wait | 2–4 hours | Google Play review time |
| **Total** | **~6–10 hours** | Spread over 1–2 days |

---

## Checklist: Ready to Go?

Before you start, verify:

- [ ] Android app builds successfully (`./gradlew bundleRelease`)
- [ ] Tested on Android 8.0+ devices
- [ ] No crashes, ANRs, or major issues
- [ ] You have access to your developer account email
- [ ] Privacy policy URL is ready
- [ ] App icon and screenshots prepared
- [ ] You understand version code management (must increment always)
- [ ] Signing key generated and backed up securely
- [ ] You've read the full submission guide below

---

## Next Steps

1. **Read**: [Google Play Submission Guide](GooglePlaySubmissionGuide.md)
2. **Generate**: Signing key and save securely
3. **Test**: Build release bundle and test on real devices
4. **Prepare**: Store listing assets (screenshots, description)
5. **Create**: Google Play account ($25)
6. **Submit**: Create app in Google Play Console and upload bundle

---

*Last updated: 2026-07-26*

You're ready to publish. Follow the detailed submission guide for step-by-step instructions.
