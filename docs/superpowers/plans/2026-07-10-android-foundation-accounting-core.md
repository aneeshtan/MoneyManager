# Android Foundation and Accounting Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a buildable, tested native Android application foundation with exact money arithmetic, balanced account postings, Room persistence, dependency injection, a branded adaptive shell, and a local workspace.

**Architecture:** The repository gains an isolated `android/` Gradle build using AGP 9.2.1 and built-in Kotlin. Domain models remain independent from Room; repositories map between Room entities and immutable domain values; Hilt wires production implementations; Compose renders state from ViewModels.

**Tech Stack:** Kotlin 2.3.10, AGP 9.2.1, Gradle 9.6.1, JDK 17, Compose BOM 2026.06.00, Material 3, Navigation 3 1.1.4, Room 2.8.4, Hilt 2.60.1, KSP 2.3.10, Coroutines 1.10.2, JUnit 4, Truth, Robolectric, AndroidX Test.

---

## Locked file structure

```text
android/
├── app/
│   └── src/main/java/com/farshadghanzanfari/promoneymanager/
│       ├── MoneyManagerApplication.kt
│       ├── MainActivity.kt
│       ├── AppViewModel.kt
│       └── ProMoneyManagerApp.kt
├── core/
│   ├── model/src/main/java/.../core/model/
│   │   ├── CurrencyCode.kt
│   │   ├── Money.kt
│   │   ├── FinanceIds.kt
│   │   └── FinanceModels.kt
│   ├── domain/src/main/java/.../core/domain/
│   │   ├── AccountBalanceCalculator.kt
│   │   ├── SplitValidator.kt
│   │   ├── TransferPostingFactory.kt
│   │   └── WorkspaceRepository.kt
│   ├── database/src/main/java/.../core/database/
│   │   ├── AppDatabase.kt
│   │   ├── FinanceEntities.kt
│   │   ├── FinanceDao.kt
│   │   └── DatabaseModule.kt
│   ├── data/src/main/java/.../core/data/
│   │   ├── RoomWorkspaceRepository.kt
│   │   ├── DefaultWorkspaceSeeder.kt
│   │   └── RepositoryModule.kt
│   └── designsystem/src/main/java/.../core/designsystem/
│       ├── Color.kt
│       ├── Theme.kt
│       └── ProMoneySurface.kt
├── parity/ios-feature-parity.yaml
├── gradle/libs.versions.toml
├── settings.gradle.kts
├── build.gradle.kts
└── gradle.properties
```

Every Kotlin file above has one responsibility. Subsequent plans add feature modules without moving these contracts.

Execution convention: Gradle commands use `android/` as the working directory with JDK 17 in `JAVA_HOME`. Git commands use the repository root.

### Task 1: Bootstrap the Android build and module graph

**Files:**
- Create: `android/settings.gradle.kts`
- Create: `android/build.gradle.kts`
- Create: `android/gradle.properties`
- Create: `android/gradle/libs.versions.toml`
- Create: `android/gradle/wrapper/gradle-wrapper.properties`
- Generate: `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar`
- Create: `android/app/build.gradle.kts`
- Create: `android/core/model/build.gradle.kts`
- Create: `android/core/domain/build.gradle.kts`
- Create: `android/core/database/build.gradle.kts`
- Create: `android/core/data/build.gradle.kts`
- Create: `android/core/designsystem/build.gradle.kts`

- [ ] **Step 1: Verify the wrapper does not exist**

Run:

```bash
test ! -f android/gradlew
```

Expected: exit 0.

- [ ] **Step 2: Create settings and the root plugin declarations**

`android/settings.gradle.kts`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "ProMoneyManagerAndroid"
include(
    ":app",
    ":core:model",
    ":core:domain",
    ":core:database",
    ":core:data",
    ":core:designsystem",
)
```

`android/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
}
```

`android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
org.gradle.configuration-cache=true
org.gradle.parallel=true
android.useAndroidX=true
android.nonTransitiveRClass=true
android.nonFinalResIds=true
```

- [ ] **Step 3: Create the version catalog**

`android/gradle/libs.versions.toml`:

```toml
[versions]
agp = "9.2.1"
kotlin = "2.3.10"
ksp = "2.3.10"
composeBom = "2026.06.00"
activity = "1.13.0"
core = "1.19.0"
lifecycle = "2.11.0"
navigation3 = "1.1.4"
adaptive = "1.4.0"
room = "2.8.4"
datastore = "1.2.1"
hilt = "2.60.1"
hiltNavigationCompose = "1.3.0"
coroutines = "1.10.2"
junit = "4.13.2"
truth = "1.4.5"
androidxTestJunit = "1.3.0"
androidxTestCore = "1.7.0"
espresso = "3.7.0"
robolectric = "4.16.1"

[libraries]
androidx-core-ktx = { module = "androidx.core:core-ktx", version.ref = "core" }
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "activity" }
androidx-lifecycle-runtime-compose = { module = "androidx.lifecycle:lifecycle-runtime-compose", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-compose-bom = { module = "androidx.compose:compose-bom", version.ref = "composeBom" }
androidx-compose-ui = { module = "androidx.compose.ui:ui" }
androidx-compose-ui-tooling = { module = "androidx.compose.ui:ui-tooling" }
androidx-compose-ui-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }
androidx-compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }
androidx-compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }
androidx-compose-material3 = { module = "androidx.compose.material3:material3" }
androidx-compose-material3-adaptive-navigation = { module = "androidx.compose.material3:material3-adaptive-navigation-suite", version.ref = "adaptive" }
androidx-navigation3-runtime = { module = "androidx.navigation3:navigation3-runtime", version.ref = "navigation3" }
androidx-navigation3-ui = { module = "androidx.navigation3:navigation3-ui", version.ref = "navigation3" }
androidx-room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
androidx-room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
androidx-room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }
androidx-room-testing = { module = "androidx.room:room-testing", version.ref = "room" }
androidx-datastore-preferences = { module = "androidx.datastore:datastore-preferences", version.ref = "datastore" }
hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-android-compiler", version.ref = "hilt" }
androidx-hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version.ref = "hiltNavigationCompose" }
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutines" }
junit = { module = "junit:junit", version.ref = "junit" }
truth = { module = "com.google.truth:truth", version.ref = "truth" }
androidx-test-core = { module = "androidx.test:core", version.ref = "androidxTestCore" }
androidx-test-ext-junit = { module = "androidx.test.ext:junit", version.ref = "androidxTestJunit" }
androidx-test-espresso-core = { module = "androidx.test.espresso:espresso-core", version.ref = "espresso" }
robolectric = { module = "org.robolectric:robolectric", version.ref = "robolectric" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

- [ ] **Step 4: Create minimal module builds**

Use this exact base in `android/core/model/build.gradle.kts`:

```kotlin
plugins { alias(libs.plugins.android.library) }

android {
    namespace = "com.farshadghanzanfari.promoneymanager.core.model"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    testImplementation(libs.junit)
    testImplementation(libs.truth)
}
```

`android/core/domain/build.gradle.kts`:

```kotlin
plugins { alias(libs.plugins.android.library) }

android {
    namespace = "com.farshadghanzanfari.promoneymanager.core.domain"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":core:model"))
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
```

`android/core/database/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.farshadghanzanfari.promoneymanager.core.database"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions { unitTests.isIncludeAndroidResources = true }
}

dependencies {
    api(project(":core:model"))
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    implementation(libs.hilt.android)
    ksp(libs.androidx.room.compiler)
    ksp(libs.hilt.compiler)
    testImplementation(libs.junit)
    testImplementation(libs.truth)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.room.testing)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.robolectric)
}
```

`android/core/data/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.farshadghanzanfari.promoneymanager.core.data"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions { unitTests.isIncludeAndroidResources = true }
}

dependencies {
    implementation(project(":core:model"))
    implementation(project(":core:domain"))
    implementation(project(":core:database"))
    implementation(libs.androidx.room.ktx)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    testImplementation(libs.junit)
    testImplementation(libs.truth)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.room.testing)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.robolectric)
}
```

`android/core/designsystem/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "com.farshadghanzanfari.promoneymanager.core.designsystem"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
```

`android/app/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.farshadghanzanfari.promoneymanager"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.farshadghanzanfari.promoneymanager"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation(project(":core:model"))
    implementation(project(":core:domain"))
    implementation(project(":core:data"))
    implementation(project(":core:designsystem"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation3.runtime)
    implementation(libs.androidx.navigation3.ui)
    implementation(libs.androidx.hilt.navigation.compose)
    implementation(libs.androidx.compose.material3.adaptive.navigation)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.espresso.core)
}
```

- [ ] **Step 5: Generate and run the Gradle wrapper**

Run:

```bash
cd android
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home gradle wrapper --gradle-version 9.6.1
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew projects
```

Expected: `BUILD SUCCESSFUL` and all six modules listed.

- [ ] **Step 6: Commit the build skeleton**

```bash
git add android
git commit -m "build(android): bootstrap native project"
```

### Task 2: Implement exact currency and money values with TDD

**Files:**
- Create: `android/core/model/src/test/java/com/farshadghanzanfari/promoneymanager/core/model/MoneyTest.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/CurrencyCode.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/Money.kt`

- [ ] **Step 1: Write the failing tests**

```kotlin
class MoneyTest {
    @Test fun parsesTwoDecimalCurrencyExactly() {
        assertThat(Money.parseStrict("1,234.50", CurrencyCode.of("AED")).minorUnits).isEqualTo(123_450L)
    }

    @Test fun parsesThreeDecimalCurrencyExactly() {
        assertThat(Money.parseStrict("1.234", CurrencyCode.of("KWD")).minorUnits).isEqualTo(1_234L)
    }

    @Test fun rejectsExcessPrecision() {
        assertThrows(MoneyFormatException::class.java) {
            Money.parseStrict("1.001", CurrencyCode.of("AED"))
        }
    }

    @Test fun rejectsCurrencyMismatchDuringAddition() {
        assertThrows(CurrencyMismatchException::class.java) {
            Money(100, CurrencyCode.of("AED")) + Money(100, CurrencyCode.of("USD"))
        }
    }

    @Test fun rejectsOverflow() {
        assertThrows(ArithmeticException::class.java) {
            Money(Long.MAX_VALUE, CurrencyCode.of("AED")) + Money(1, CurrencyCode.of("AED"))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify failure**

```bash
cd android
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest --tests '*MoneyTest'
```

Expected: compilation failure because `Money` and `CurrencyCode` do not exist.

- [ ] **Step 3: Implement the value objects**

```kotlin
@JvmInline
value class CurrencyCode private constructor(val value: String) {
    val fractionDigits: Int get() = Currency.getInstance(value).defaultFractionDigits

    companion object {
        fun of(raw: String): CurrencyCode {
            val normalized = raw.trim().uppercase(Locale.ROOT)
            require(normalized.length == 3) { "Currency code must contain three letters" }
            val currency = Currency.getInstance(normalized)
            require(currency.defaultFractionDigits >= 0) { "Currency must define minor units" }
            return CurrencyCode(normalized)
        }
    }
}
```

```kotlin
data class Money(val minorUnits: Long, val currency: CurrencyCode) {
    operator fun plus(other: Money): Money {
        requireCurrency(other)
        return copy(minorUnits = Math.addExact(minorUnits, other.minorUnits))
    }

    operator fun minus(other: Money): Money {
        requireCurrency(other)
        return copy(minorUnits = Math.subtractExact(minorUnits, other.minorUnits))
    }

    fun requirePositiveMagnitude(): Money {
        if (minorUnits <= 0) throw MoneyFormatException("Amount must be greater than zero")
        return this
    }

    private fun requireCurrency(other: Money) {
        if (currency != other.currency) throw CurrencyMismatchException(currency, other.currency)
    }

    companion object {
        fun zero(currency: CurrencyCode) = Money(0, currency)

        fun parseStrict(raw: String, currency: CurrencyCode): Money {
            try {
                val normalized = raw.trim().replace(",", "")
                val scaled = BigDecimal(normalized).setScale(currency.fractionDigits, RoundingMode.UNNECESSARY)
                return Money(scaled.movePointRight(currency.fractionDigits).longValueExact(), currency)
            } catch (error: ArithmeticException) {
                throw MoneyFormatException("Amount has invalid precision or exceeds the supported range", error)
            } catch (error: NumberFormatException) {
                throw MoneyFormatException("Amount is not a valid number", error)
            }
        }
    }
}

class MoneyFormatException(message: String, cause: Throwable? = null) : IllegalArgumentException(message, cause)

class CurrencyMismatchException(left: CurrencyCode, right: CurrencyCode) :
    IllegalArgumentException("Cannot combine ${left.value} and ${right.value}")
```

- [ ] **Step 4: Run the model tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest
```

Expected: all `MoneyTest` tests pass.

- [ ] **Step 5: Commit exact money arithmetic**

```bash
git add android/core/model
git commit -m "feat(android): add exact money values"
```

### Task 3: Define finance IDs, postings, and account balances with TDD

**Files:**
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceIds.kt`
- Create: `android/core/model/src/main/java/com/farshadghanzanfari/promoneymanager/core/model/FinanceModels.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/AccountBalanceCalculator.kt`
- Create: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/AccountBalanceCalculatorTest.kt`

- [ ] **Step 1: Write balance tests for every posting direction**

```kotlin
class AccountBalanceCalculatorTest {
    private val aed = CurrencyCode.of("AED")
    private val accountId = AccountId("account")

    @Test fun appliesIncomeExpenseAndTransferLegs() {
        val account = Account(accountId, "Bank", aed, Money(10_000, aed), AccountType.BANK)
        val postings = listOf(
            Transaction.posting("income", accountId, Money(2_000, aed), TransactionKind.INCOME),
            Transaction.posting("expense", accountId, Money(500, aed), TransactionKind.EXPENSE),
            Transaction.transferLeg("out", accountId, Money(1_000, aed), TransferId("t"), TransferDirection.OUT),
            Transaction.transferLeg("in", accountId, Money(300, aed), TransferId("t2"), TransferDirection.IN),
        )

        assertThat(AccountBalanceCalculator.currentBalance(account, postings)).isEqualTo(Money(10_800, aed))
    }

    @Test fun rejectsPostingInAnotherCurrency() {
        val account = Account(accountId, "Bank", aed, Money.zero(aed), AccountType.BANK)
        val usdPosting = Transaction.posting("bad", accountId, Money(100, CurrencyCode.of("USD")), TransactionKind.INCOME)
        assertThrows(CurrencyMismatchException::class.java) {
            AccountBalanceCalculator.currentBalance(account, listOf(usdPosting))
        }
    }
}
```

- [ ] **Step 2: Run and observe the missing-type failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest --tests '*AccountBalanceCalculatorTest'
```

Expected: compilation failure for `Account`, `Transaction`, and IDs.

- [ ] **Step 3: Add IDs and immutable domain models**

```kotlin
@JvmInline value class ProfileId(val value: String)
@JvmInline value class AccountId(val value: String)
@JvmInline value class CategoryId(val value: String)
@JvmInline value class TransactionId(val value: String)
@JvmInline value class TransferId(val value: String)
@JvmInline value class SplitId(val value: String)
```

```kotlin
enum class AccountType { CASH, BANK, CREDIT_CARD, LIABILITY, INVESTMENT, OTHER }
enum class TransactionKind { EXPENSE, INCOME, TRANSFER }
enum class TransferDirection { OUT, IN }

data class Account(
    val id: AccountId,
    val name: String,
    val currency: CurrencyCode,
    val openingBalance: Money,
    val type: AccountType,
    val isArchived: Boolean = false,
)

data class Transaction(
    val id: TransactionId,
    val accountId: AccountId,
    val amount: Money,
    val kind: TransactionKind,
    val transferId: TransferId? = null,
    val transferDirection: TransferDirection? = null,
) {
    init {
        amount.requirePositiveMagnitude()
        require((kind == TransactionKind.TRANSFER) == (transferId != null && transferDirection != null))
    }

    companion object {
        fun posting(id: String, accountId: AccountId, amount: Money, kind: TransactionKind) =
            Transaction(TransactionId(id), accountId, amount, kind)

        fun transferLeg(
            id: String,
            accountId: AccountId,
            amount: Money,
            transferId: TransferId,
            direction: TransferDirection,
        ) = Transaction(TransactionId(id), accountId, amount, TransactionKind.TRANSFER, transferId, direction)
    }
}
```

- [ ] **Step 4: Implement the calculator**

```kotlin
object AccountBalanceCalculator {
    fun currentBalance(account: Account, transactions: List<Transaction>): Money =
        transactions.filter { it.accountId == account.id }.fold(account.openingBalance) { balance, transaction ->
            if (transaction.amount.currency != account.currency) {
                throw CurrencyMismatchException(account.currency, transaction.amount.currency)
            }
            when (transaction.kind) {
                TransactionKind.INCOME -> balance + transaction.amount
                TransactionKind.EXPENSE -> balance - transaction.amount
                TransactionKind.TRANSFER -> when (transaction.transferDirection) {
                    TransferDirection.IN -> balance + transaction.amount
                    TransferDirection.OUT -> balance - transaction.amount
                    null -> error("Transfer direction is required")
                }
            }
        }
}
```

- [ ] **Step 5: Run both model and domain tests**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest
```

Expected: all tests pass.

- [ ] **Step 6: Commit domain postings**

```bash
git add android/core/model android/core/domain
git commit -m "feat(android): model balanced account postings"
```

### Task 4: Enforce split invariants with TDD

**Files:**
- Create: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/SplitValidatorTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/SplitValidator.kt`

- [ ] **Step 1: Write exact-total and currency tests**

```kotlin
class SplitValidatorTest {
    private val aed = CurrencyCode.of("AED")

    @Test fun acceptsAllocationsThatExactlyEqualParent() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(SplitAllocation(SplitId("1"), CategoryId("food"), Money(600, aed)),
                SplitAllocation(SplitId("2"), CategoryId("travel"), Money(400, aed))),
        )
        assertThat(result).isEqualTo(SplitValidation.Valid)
    }

    @Test fun rejectsUnderAllocation() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(
                SplitAllocation(SplitId("1"), CategoryId("food"), Money(600, aed)),
                SplitAllocation(SplitId("2"), CategoryId("travel"), Money(399, aed)),
            ),
        )
        assertThat(result).isEqualTo(SplitValidation.TotalMismatch(expectedMinor = 1_000, actualMinor = 999))
    }

    @Test fun rejectsMixedCurrency() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(SplitAllocation(SplitId("1"), CategoryId("food"), Money(1_000, CurrencyCode.of("USD")))),
        )
        assertThat(result).isEqualTo(SplitValidation.CurrencyMismatch)
    }
}
```

- [ ] **Step 2: Run and observe failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest --tests '*SplitValidatorTest'
```

Expected: compilation failure because split types are absent.

- [ ] **Step 3: Implement split validation**

```kotlin
data class SplitAllocation(val id: SplitId, val categoryId: CategoryId, val amount: Money)

sealed interface SplitValidation {
    data object Valid : SplitValidation
    data object Empty : SplitValidation
    data object CurrencyMismatch : SplitValidation
    data class TotalMismatch(val expectedMinor: Long, val actualMinor: Long) : SplitValidation
}

object SplitValidator {
    fun validate(parent: Money, allocations: List<SplitAllocation>): SplitValidation {
        if (allocations.size < 2) return SplitValidation.Empty
        if (allocations.any { it.amount.currency != parent.currency || it.amount.minorUnits <= 0 }) {
            return SplitValidation.CurrencyMismatch
        }
        val total = allocations.fold(0L) { sum, allocation -> Math.addExact(sum, allocation.amount.minorUnits) }
        return if (total == parent.minorUnits) SplitValidation.Valid
        else SplitValidation.TotalMismatch(parent.minorUnits, total)
    }
}
```

- [ ] **Step 4: Run and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
git add android/core/domain
git commit -m "feat(android): enforce exact transaction splits"
```

Expected: domain tests pass and the commit succeeds.

### Task 5: Create balanced transfer postings with TDD

**Files:**
- Create: `android/core/domain/src/test/java/com/farshadghanzanfari/promoneymanager/core/domain/TransferPostingFactoryTest.kt`
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/TransferPostingFactory.kt`

- [ ] **Step 1: Write same-currency, cross-currency, and invalid-account tests**

```kotlin
class TransferPostingFactoryTest {
    private val aed = CurrencyCode.of("AED")

    @Test fun createsBalancedSameCurrencyLegs() {
        val result = TransferPostingFactory.create(
            TransferId("transfer"), AccountId("source"), AccountId("destination"),
            Money(1_000, aed), Money(1_000, aed),
        )
        assertThat(result.source.transferDirection).isEqualTo(TransferDirection.OUT)
        assertThat(result.destination.transferDirection).isEqualTo(TransferDirection.IN)
    }

    @Test fun preservesBothCrossCurrencyAmounts() {
        val result = TransferPostingFactory.create(
            TransferId("transfer"), AccountId("source"), AccountId("destination"),
            Money(1_000, aed), Money(272, CurrencyCode.of("USD")),
        )
        assertThat(result.destination.amount.minorUnits).isEqualTo(272)
    }

    @Test fun rejectsSameAccount() {
        assertThrows(IllegalArgumentException::class.java) {
            TransferPostingFactory.create(
                TransferId("transfer"), AccountId("same"), AccountId("same"), Money(1_000, aed), Money(1_000, aed),
            )
        }
    }
}
```

- [ ] **Step 2: Run and observe failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest --tests '*TransferPostingFactoryTest'
```

Expected: compilation failure because the factory is absent.

- [ ] **Step 3: Implement the factory**

```kotlin
data class TransferPostings(val source: Transaction, val destination: Transaction)

object TransferPostingFactory {
    fun create(
        transferId: TransferId,
        sourceAccountId: AccountId,
        destinationAccountId: AccountId,
        sourceAmount: Money,
        destinationAmount: Money,
    ): TransferPostings {
        require(sourceAccountId != destinationAccountId) { "Transfer accounts must be different" }
        sourceAmount.requirePositiveMagnitude()
        destinationAmount.requirePositiveMagnitude()
        if (sourceAmount.currency == destinationAmount.currency) {
            require(sourceAmount.minorUnits == destinationAmount.minorUnits) { "Same-currency transfer must balance" }
        }
        return TransferPostings(
            source = Transaction.transferLeg("${transferId.value}-out", sourceAccountId, sourceAmount, transferId, TransferDirection.OUT),
            destination = Transaction.transferLeg("${transferId.value}-in", destinationAccountId, destinationAmount, transferId, TransferDirection.IN),
        )
    }
}
```

- [ ] **Step 4: Run and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:domain:testDebugUnitTest
git add android/core/domain
git commit -m "feat(android): create balanced transfer postings"
```

Expected: all domain tests pass.

### Task 6: Persist accounts and postings in Room with TDD

**Files:**
- Create: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceEntities.kt`
- Create: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/FinanceDao.kt`
- Create: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabase.kt`
- Create: `android/core/database/src/test/java/com/farshadghanzanfari/promoneymanager/core/database/AppDatabaseTest.kt`

- [ ] **Step 1: Write the Room relationship and atomic-delete tests**

```kotlin
@RunWith(RobolectricTestRunner::class)
class AppDatabaseTest {
    private lateinit var database: AppDatabase

    @Before fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(), AppDatabase::class.java,
        ).allowMainThreadQueries().build()
    }

    @After fun tearDown() = database.close()

    @Test fun observesAccountsInSortOrder() = runTest {
        database.financeDao().upsertAccount(AccountEntity("b", "profile", "Second", "AED", 0, "BANK", false, 2))
        database.financeDao().upsertAccount(AccountEntity("a", "profile", "First", "AED", 0, "CASH", false, 1))
        assertThat(database.financeDao().observeAccounts().first().map { it.id }).containsExactly("a", "b").inOrder()
    }

    @Test fun deletingWorkspaceRemovesEveryFoundationTable() = runTest {
        database.financeDao().upsertProfile(ProfileEntity("profile", "Local User", "AED", "AE", "Asia/Dubai"))
        database.financeDao().upsertAccount(AccountEntity("a", "profile", "Cash", "AED", 0, "CASH", false, 0))
        database.clearWorkspace()
        assertThat(database.financeDao().countProfiles()).isEqualTo(0)
        assertThat(database.financeDao().countAccounts()).isEqualTo(0)
    }
}
```

- [ ] **Step 2: Run and observe the missing-schema failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:database:testDebugUnitTest --tests '*AppDatabaseTest'
```

Expected: compilation failure because Room types are absent.

- [ ] **Step 3: Add the foundation entities**

```kotlin
@Entity(tableName = "profiles")
data class ProfileEntity(
    @PrimaryKey val id: String,
    val displayName: String,
    val baseCurrency: String,
    val countryCode: String?,
    val timeZoneId: String?,
)

@Entity(
    tableName = "accounts",
    foreignKeys = [ForeignKey(ProfileEntity::class, ["id"], ["profileId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("profileId"), Index(value = ["profileId", "name"], unique = true)],
)
data class AccountEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val currencyCode: String,
    val openingBalanceMinor: Long,
    val type: String,
    val isArchived: Boolean,
    val sortOrder: Int,
)

@Entity(
    tableName = "transactions",
    foreignKeys = [ForeignKey(AccountEntity::class, ["id"], ["accountId"], onDelete = ForeignKey.RESTRICT)],
    indices = [Index("accountId"), Index("transferId"), Index(value = ["accountId", "localDate", "amountMinor", "currencyCode", "normalizedMerchant"])],
)
data class TransactionEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val localDate: String,
    val amountMinor: Long,
    val currencyCode: String,
    val kind: String,
    val merchant: String,
    val normalizedMerchant: String,
    val note: String,
    val transferId: String?,
    val transferDirection: String?,
)
```

- [ ] **Step 4: Add DAO and database transactions**

```kotlin
@Dao
interface FinanceDao {
    @Upsert suspend fun upsertProfile(profile: ProfileEntity)
    @Upsert suspend fun upsertAccount(account: AccountEntity)
    @Upsert suspend fun upsertTransactions(transactions: List<TransactionEntity>)
    @Query("SELECT * FROM accounts ORDER BY sortOrder, name") fun observeAccounts(): Flow<List<AccountEntity>>
    @Query("SELECT * FROM transactions ORDER BY localDate DESC, id") fun observeTransactions(): Flow<List<TransactionEntity>>
    @Query("SELECT COUNT(*) FROM profiles") suspend fun countProfiles(): Int
    @Query("SELECT COUNT(*) FROM accounts") suspend fun countAccounts(): Int
    @Query("DELETE FROM transactions") suspend fun deleteTransactions()
    @Query("DELETE FROM accounts") suspend fun deleteAccounts()
    @Query("DELETE FROM profiles") suspend fun deleteProfiles()

    @Transaction
    suspend fun clearWorkspace() {
        deleteTransactions()
        deleteAccounts()
        deleteProfiles()
    }
}

@Database(entities = [ProfileEntity::class, AccountEntity::class, TransactionEntity::class], version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun financeDao(): FinanceDao

    suspend fun clearWorkspace() = financeDao().clearWorkspace()
}
```

- [ ] **Step 5: Configure Room schema export and run tests**

Add to `core/database/build.gradle.kts`:

```kotlin
ksp { arg("room.schemaLocation", "$projectDir/schemas") }
```

Run:

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:database:testDebugUnitTest
```

Expected: both database tests pass and `android/core/database/schemas/.../1.json` exists.

- [ ] **Step 6: Commit persistence foundation**

```bash
git add android/core/database
git commit -m "feat(android): persist finance foundation with Room"
```

### Task 7: Add repositories, idempotent workspace seed, and Hilt

**Files:**
- Create: `android/core/domain/src/main/java/com/farshadghanzanfari/promoneymanager/core/domain/WorkspaceRepository.kt`
- Create: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RoomWorkspaceRepository.kt`
- Create: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/DefaultWorkspaceSeeder.kt`
- Create: `android/core/data/src/main/java/com/farshadghanzanfari/promoneymanager/core/data/RepositoryModule.kt`
- Create: `android/core/database/src/main/java/com/farshadghanzanfari/promoneymanager/core/database/DatabaseModule.kt`
- Create: `android/core/data/src/test/java/com/farshadghanzanfari/promoneymanager/core/data/DefaultWorkspaceSeederTest.kt`

- [ ] **Step 1: Write the idempotent seed test**

```kotlin
@RunWith(RobolectricTestRunner::class)
class DefaultWorkspaceSeederTest {
    @Test fun createsOneProfileAndFourGenericAccountsOnlyOnce() = runTest {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(), AppDatabase::class.java,
        ).allowMainThreadQueries().build()
        val seeder = DefaultWorkspaceSeeder(database)
        seeder.seed(CurrencyCode.of("AED"))
        seeder.seed(CurrencyCode.of("AED"))
        assertThat(database.financeDao().countProfiles()).isEqualTo(1)
        assertThat(database.financeDao().countAccounts()).isEqualTo(4)
        database.close()
    }
}
```

- [ ] **Step 2: Run and observe failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:data:testDebugUnitTest --tests '*DefaultWorkspaceSeederTest'
```

Expected: compilation failure because the seeder is absent.

- [ ] **Step 3: Define repository contract and mapping implementation**

```kotlin
interface WorkspaceRepository {
    fun observeAccounts(): Flow<List<Account>>
    fun observeTransactions(): Flow<List<Transaction>>
    suspend fun createLocalWorkspace(displayName: String, currency: CurrencyCode)
    suspend fun clearWorkspace()
}
```

```kotlin
@Singleton
class RoomWorkspaceRepository @Inject constructor(
    private val database: AppDatabase,
    private val seeder: DefaultWorkspaceSeeder,
) : WorkspaceRepository {
    private val dao = database.financeDao()

    override fun observeAccounts(): Flow<List<Account>> = dao.observeAccounts().map { rows ->
        rows.map { row ->
            val currency = CurrencyCode.of(row.currencyCode)
            Account(
                id = AccountId(row.id),
                name = row.name,
                currency = currency,
                openingBalance = Money(row.openingBalanceMinor, currency),
                type = AccountType.valueOf(row.type),
                isArchived = row.isArchived,
            )
        }
    }

    override fun observeTransactions(): Flow<List<Transaction>> = dao.observeTransactions().map { rows ->
        rows.map { row ->
            val amount = Money(row.amountMinor, CurrencyCode.of(row.currencyCode))
            val kind = TransactionKind.valueOf(row.kind)
            if (kind == TransactionKind.TRANSFER) {
                Transaction.transferLeg(
                    id = row.id,
                    accountId = AccountId(row.accountId),
                    amount = amount,
                    transferId = TransferId(requireNotNull(row.transferId)),
                    direction = TransferDirection.valueOf(requireNotNull(row.transferDirection)),
                )
            } else {
                Transaction.posting(row.id, AccountId(row.accountId), amount, kind)
            }
        }
    }

    override suspend fun createLocalWorkspace(displayName: String, currency: CurrencyCode) {
        seeder.seed(currency, displayName)
    }

    override suspend fun clearWorkspace() = database.clearWorkspace()
}
```

- [ ] **Step 4: Implement deterministic seed records**

```kotlin
class DefaultWorkspaceSeeder @Inject constructor(private val database: AppDatabase) {
    suspend fun seed(currency: CurrencyCode, displayName: String = "Local User") {
        if (database.financeDao().countProfiles() > 0) return
        database.withTransaction {
            val dao = database.financeDao()
            dao.upsertProfile(ProfileEntity("primary-user", displayName, currency.value, null, null))
            listOf(
                Triple("cash", "Cash", "CASH"),
                Triple("bank", "Bank Account", "BANK"),
                Triple("credit-card", "Credit Card", "CREDIT_CARD"),
                Triple("savings", "Savings", "BANK"),
            ).forEachIndexed { index, (id, name, type) ->
                dao.upsertAccount(AccountEntity(id, "primary-user", name, currency.value, 0, type, false, index))
            }
        }
    }
}
```

- [ ] **Step 5: Add Hilt bindings**

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides @Singleton fun database(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "pro-money-manager.db").build()
}
```

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds @Singleton abstract fun workspace(implementation: RoomWorkspaceRepository): WorkspaceRepository
}
```

- [ ] **Step 6: Run tests and commit**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :core:data:testDebugUnitTest :core:database:testDebugUnitTest
git add android/core/domain android/core/data android/core/database
git commit -m "feat(android): add local workspace repository"
```

Expected: repository and database tests pass.

### Task 8: Build the branded app shell and local onboarding

**Files:**
- Create: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values/styles.xml`
- Create: `android/app/proguard-rules.pro`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MoneyManagerApplication.kt`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/MainActivity.kt`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/AppViewModel.kt`
- Create: `android/app/src/main/java/com/farshadghanzanfari/promoneymanager/ProMoneyManagerApp.kt`
- Create: `android/core/designsystem/src/main/java/com/farshadghanzanfari/promoneymanager/core/designsystem/Color.kt`
- Create: `android/core/designsystem/src/main/java/com/farshadghanzanfari/promoneymanager/core/designsystem/Theme.kt`
- Create: `android/core/designsystem/src/main/java/com/farshadghanzanfari/promoneymanager/core/designsystem/ProMoneySurface.kt`
- Create: `android/app/src/androidTest/java/com/farshadghanzanfari/promoneymanager/OnboardingTest.kt`

- [ ] **Step 1: Write the onboarding UI test**

```kotlin
@RunWith(AndroidJUnit4::class)
class OnboardingTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun continueOnDeviceShowsStats() {
        var hasWorkspace by mutableStateOf(false)
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = hasWorkspace),
                    onContinueOnDevice = { hasWorkspace = true },
                )
            }
        }
        composeRule.onNodeWithText("Continue on this device").performClick()
        composeRule.onNodeWithText("Stats").assertIsDisplayed()
    }
}
```

- [ ] **Step 2: Run to verify the missing-activity failure**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:compileDebugAndroidTestKotlin
```

Expected: compilation failure because `MainActivity` is absent.

- [ ] **Step 3: Add application, activity, and manifest**

```kotlin
@HiltAndroidApp
class MoneyManagerApplication : Application()

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { ProMoneyManagerTheme { ProMoneyManagerApp() } }
    }
}
```

`android/app/src/main/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name=".MoneyManagerApplication"
        android:allowBackup="false"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.ProMoneyManager">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

`android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="app_name">Pro Money Manager</string>
</resources>
```

`android/app/src/main/res/values/styles.xml`:

```xml
<resources>
    <style name="Theme.ProMoneyManager" parent="android:style/Theme.Material.Light.NoActionBar">
        <item name="android:fontFamily">sans</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
    </style>
</resources>
```

`android/app/proguard-rules.pro`:

```proguard
# Room and Hilt provide consumer rules. Add project rules only when release verification proves they are required.
```

- [ ] **Step 4: Implement ViewModel state and local onboarding**

```kotlin
data class AppUiState(
    val hasWorkspace: Boolean = false,
    val accounts: List<Account> = emptyList(),
)

@HiltViewModel
class AppViewModel @Inject constructor(private val repository: WorkspaceRepository) : ViewModel() {
    val uiState: StateFlow<AppUiState> = repository.observeAccounts()
        .map { AppUiState(hasWorkspace = it.isNotEmpty(), accounts = it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppUiState())

    fun continueOnDevice() = viewModelScope.launch {
        repository.createLocalWorkspace("Local User", CurrencyCode.of("AED"))
    }
}
```

```kotlin
private enum class AppDestination(val label: String) {
    STATS("Stats"), TRANSACTIONS("Transactions"), IMPORT("Import"), MORE("More")
}

@Composable
fun ProMoneyManagerApp(viewModel: AppViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    ProMoneyManagerContent(state = state, onContinueOnDevice = viewModel::continueOnDevice)
}

@Composable
fun ProMoneyManagerContent(state: AppUiState, onContinueOnDevice: () -> Unit) {
    if (!state.hasWorkspace) {
        Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            ProMoneySurface {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Pro Money Manager", style = MaterialTheme.typography.headlineMedium)
                    Text("Private finance tracking, stored on this device.")
                    Button(onClick = onContinueOnDevice) { Text("Continue on this device") }
                }
            }
        }
        return
    }

    var selected by rememberSaveable { mutableStateOf(AppDestination.STATS) }
    NavigationSuiteScaffold(
        navigationSuiteItems = {
            AppDestination.entries.forEach { destination ->
                item(
                    selected = selected == destination,
                    onClick = { selected = destination },
                    icon = { Text(destination.label.take(1)) },
                    label = { Text(destination.label) },
                )
            }
        },
    ) {
        when (selected) {
            AppDestination.STATS -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { Text("Stats", style = MaterialTheme.typography.headlineMedium) }
                item { Text("This month") }
                items(state.accounts, key = { it.id.value }) { account ->
                    ProMoneySurface { Text(account.name) }
                }
            }
            else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(selected.label, style = MaterialTheme.typography.headlineMedium)
            }
        }
    }
}
```

- [ ] **Step 5: Implement theme tokens**

```kotlin
val Violet = Color(0xFF8151D1)
val Lavender = Color(0xFFE9DFFF)
val Teal = Color(0xFF20BFA9)
val Coral = Color(0xFFFF6878)
val Gold = Color(0xFFFFC857)
val Ink = Color(0xFF202334)

@Composable
fun ProMoneyManagerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Violet,
            secondary = Teal,
            tertiary = Coral,
            background = Color(0xFFF9F7FF),
            surface = Color.White,
            onBackground = Ink,
            onSurface = Ink,
        ),
        content = content,
    )
}
```

```kotlin
@Composable
fun ProMoneySurface(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(modifier = modifier, shape = RoundedCornerShape(24.dp)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = content)
    }
}
```

- [ ] **Step 6: Build, install, and run the UI test**

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:assembleDebug
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew :app:connectedDebugAndroidTest
```

Expected: debug APK builds and `OnboardingTest` passes on `emulator-5554`.

- [ ] **Step 7: Commit the app shell**

```bash
git add android/app android/core/designsystem
git commit -m "feat(android): add branded local app shell"
```

### Task 9: Establish parity evidence and full foundation verification

**Files:**
- Create: `android/parity/ios-feature-parity.yaml`
- Create: `android/README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Create the parity ledger with stable foundation entries**

```yaml
schemaVersion: 1
sourceCommit: 1935db3
features:
  - id: foundation.local-profile
    ios: MManger/Views/AuthView.swift
    android: app/ProMoneyManagerApp.kt
    acceptance: Continue on this device creates one local profile and four generic accounts.
    evidence: app/OnboardingTest.kt
    status: verified
  - id: accounting.exact-money
    ios: MManger/Models/FinanceModels.swift
    android: core/model/Money.kt
    acceptance: Money uses checked integer minor units and rejects excess precision or mixed-currency arithmetic.
    evidence: core/model/MoneyTest.kt
    status: verified
  - id: accounting.account-balance
    ios: MManger/Models/FinanceModels.swift#AccountBalance
    android: core/domain/AccountBalanceCalculator.kt
    acceptance: Income, expense, and both transfer directions change balances exactly once.
    evidence: core/domain/AccountBalanceCalculatorTest.kt
    status: verified
  - id: accounting.splits
    ios: MManger/Views/SplitTransactionEditorView.swift
    android: core/domain/SplitValidator.kt
    acceptance: At least two positive same-currency allocations equal the parent amount exactly.
    evidence: core/domain/SplitValidatorTest.kt
    status: verified
  - id: accounting.transfers
    ios: MManger/Models/FinanceModels.swift
    android: core/domain/TransferPostingFactory.kt
    acceptance: Transfers have distinct accounts and balanced source/destination legs.
    evidence: core/domain/TransferPostingFactoryTest.kt
    status: verified
```

- [ ] **Step 2: Document reproducible commands**

`android/README.md`:

````markdown
# Pro Money Manager Android

Native local-first Android application. The app requires JDK 17, Android SDK Platform 36,
Build Tools 36+, and the checked-in Gradle wrapper.

## Verify

```bash
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew \
  testDebugUnitTest lintDebug assembleDebug connectedDebugAndroidTest
```

The phase-one manifest intentionally has no INTERNET permission. Feature parity evidence is
tracked in `parity/ios-feature-parity.yaml`.
````

- [ ] **Step 3: Ignore only generated Android outputs**

Append to `.gitignore`:

```gitignore
android/.gradle/
android/**/build/
android/local.properties
android/.idea/
android/captures/
```

- [ ] **Step 4: Run the complete foundation verification**

```bash
cd android
JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home ./gradlew \
  clean \
  testDebugUnitTest \
  lintDebug \
  assembleDebug \
  connectedDebugAndroidTest
```

Expected: `BUILD SUCCESSFUL`; unit, lint, APK, and connected tests pass.

- [ ] **Step 5: Verify privacy and staged scope**

```bash
apkanalyzer manifest permissions app/build/outputs/apk/debug/app-debug.apk
git diff --check
git status --short
```

Expected: no `android.permission.INTERNET`; no whitespace errors; only planned Android/docs changes present.

- [ ] **Step 6: Commit foundation evidence**

```bash
git add .gitignore android/README.md android/parity/ios-feature-parity.yaml
git commit -m "test(android): verify foundation parity"
```

## Plan self-review result

- Spec coverage: foundation, architecture, money, balances, splits, transfers, Room, Hilt, local profile, branded shell, and parity evidence all map to explicit tasks.
- Placeholder scan: no incomplete implementation instruction remains.
- Type consistency: `CurrencyCode`, `Money`, finance IDs, `Transaction`, Room entities, repositories, and UI state use the same names and signatures across tasks.
- Execution choice: inline execution with `superpowers:executing-plans`, selected from the user’s instruction to continue without additional approval pauses.
