pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val sdk = properties.getProperty("flutter.sdk")
            require(sdk != null) { "flutter.sdk not set in local.properties" }
            sdk
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // ✅ Pin to AGP 8.x (avoid AGP 9 for Flutter+plugins)
    id("com.android.application") version "8.13.0" apply false

    // Google Services (Firebase)
    id("com.google.gms.google-services") version "4.4.2" apply false

    // Crashlytics plugin
    id("com.google.firebase.crashlytics") version "3.0.2" apply false

    // ✅ Kotlin plugin (stable with Gradle 8.x)
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
}

include(":app")