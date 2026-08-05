# Pro Money Manager Android

Native, local-first Android application. The app requires JDK 17, Android SDK Platform 37,
Build Tools 37+, and the checked-in Gradle wrapper.

## Verify

From this directory, with an unlocked emulator or device connected:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew \
  testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
```

When more than one device is connected, select one explicitly:

```bash
ANDROID_SERIAL=emulator-5554 \
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home \
./gradlew connectedDebugAndroidTest
```

The foundation manifest intentionally has no `INTERNET` permission. Feature parity evidence is
tracked in [`parity/ios-feature-parity.yaml`](parity/ios-feature-parity.yaml).
