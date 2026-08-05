# Android App Lock Security Design

**Status:** Approved by the standing product specification and the user's instruction to continue without additional approval pauses.

## Scope

This slice turns the existing app-lock preference into an enforced Android security boundary. It also replaces process-memory settings with Preferences DataStore so privacy, notification, and regional choices survive process death.

## Behavior

- When app lock is disabled, the workspace opens normally.
- When app lock is enabled, the root UI fails closed and renders only a branded unlock surface until authentication succeeds.
- Authentication uses the Android system prompt and permits biometrics plus the device credential (PIN, pattern, or password). Pro Money Manager never stores a custom PIN.
- Returning from the background relocks after the configured immediate, one-, five-, or fifteen-minute timeout.
- Authentication cancellation or failure leaves the workspace locked and offers an explicit retry action.
- Devices without an enrolled supported authenticator cannot enable app lock; the UI explains how to secure the device.
- `FLAG_SECURE` follows the secure-screen preference so screenshots and non-secure displays cannot capture finance screens.
- Shortcut and Sharesheet launches cannot bypass the lock.

## Architecture

- `SettingsDataStore` is the single data-layer owner of the preferences file and maps immutable domain settings to typed keys and Flows.
- `RoomWorkspaceRepository` delegates preference observation and updates to that store and resets it during workspace deletion.
- `AppLockSessionPolicy` is a pure model that decides whether elapsed background time requires reauthentication.
- `AppLockGate` owns only presentation and system-prompt orchestration. Finance content remains below the gate.
- `MainActivity` remains the lifecycle/window boundary and applies secure-window policy requested by the root composable.

## Compatibility and failure handling

DataStore defaults exactly match current domain defaults, so existing installs migrate without a visible settings regression. Corrupt preference reads recover to defaults. The stable AndroidX Biometric API is used; the allowed authenticator combination is checked before app lock is enabled.

## Verification

- JVM tests prove timeout boundaries and persisted settings round trips/reset.
- Instrumented UI tests prove an enabled lock hides workspace content and exposes unlock/retry UI without relying on emulator biometric enrollment.
- Instrumented platform tests prove the secure-window flag is applied.
- The full unit, lint, debug APK, release bundle, and connected-test gates remain green.
