plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
}

subprojects {
    plugins.withId("com.android.library") {
        val hasAndroidTests = layout.projectDirectory.dir("src/androidTest").asFile.exists()

        tasks.matching { it.name.startsWith("connected") && it.name.endsWith("AndroidTest") }
            .configureEach {
                onlyIf { hasAndroidTests }
            }
    }
}
