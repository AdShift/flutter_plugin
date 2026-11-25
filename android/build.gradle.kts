group = "com.adshift.adshift_flutter_sdk"
version = "1.0"

// These versions are the ones of the oldest supported Flutter's app template.
// The app's own Android Gradle plugin is the one that runs; a version here
// newer than the app's breaks its build, an older one does not.
buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.adshift.adshift_flutter_sdk"

    // The lowest version an app may compile against; the app's own, when higher, is what counts.
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Exact pin, raised with each plugin release; see native_sdk.json.
    implementation("com.adshift:android-sdk:4.2.0")
    // The bridge is written with coroutines. This is the version Flutter's own Android code
    // brings, so it raises nothing in the app; a newer one in the app wins.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("org.robolectric:robolectric:4.15.1")
    testImplementation("io.mockk:mockk:1.14.3")
}
