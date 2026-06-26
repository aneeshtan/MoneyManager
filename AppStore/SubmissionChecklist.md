# Pro Money Manager App Store Submission Checklist

## App Privacy

- App Privacy label: **Data Not Collected**
- Tracking: **No**
- Third-party advertising: **No**
- Analytics SDKs: **No**
- Account creation required: **Yes**, for the local app workspace gate.
- Data leaves device: **No**, except files the user explicitly exports through iOS sharing/storage.

## Privacy Manifest

- `PrivacyInfo.xcprivacy` is included in the app target.
- `NSPrivacyCollectedDataTypes` is empty.
- `NSPrivacyTracking` is false.
- `NSPrivacyTrackingDomains` is empty.
- `NSPrivacyAccessedAPITypes` is empty.

## App Store Connect Answers

- Does this app collect data from this app? **No**
- Does this app use third-party content or advertising? **No**
- Does this app use tracking? **No**
- Does this app require sign-in? **Yes**
- Does this app use encryption? **Use only standard Apple platform encryption/storage behavior; no custom encryption or network transport is implemented.**

## Login

- Native Sign in with Apple is enabled through `MManger.entitlements`.
- The current Google button is intentionally disabled until a production Google OAuth client is configured.
- To enable Google login for App Store builds, add the GoogleSignIn Swift Package, add `GIDClientID`, and add the reversed client ID URL scheme from the iOS OAuth client.
- Re-check App Store privacy answers before enabling Google login, because a third-party authentication SDK/provider may affect privacy disclosures even if finance data remains local.

## Required Before Upload

- Support email is set to `app@hafatalghad.com`; confirm this inbox is active before submission.
- Publish the privacy policy at a public URL and paste that URL into App Store Connect.
- Confirm `PRODUCT_BUNDLE_IDENTIFIER` exists in Apple Developer/App Store Connect:
  - `com.farshadghanzanfari.aimoneymanager`
- Archive with a real Apple Distribution signing profile.
- Prepare screenshots for 6.7-inch iPhone and any other selected device families.
- Add review notes explaining: all finance data is local, import parsing is on-device, no bank sync or external AI service is used.

## Suggested Review Notes

Pro Money Manager is a local-first personal finance app. It imports user-selected PDF/CSV files or pasted bank notification text, parses the content on device, and stores the resulting records locally using SwiftData. The app requires sign-in to open the local workspace, does not use analytics, does not use advertising, does not track users, and does not transmit financial data to any server. Export and backup files are only created when the user explicitly chooses to export.
