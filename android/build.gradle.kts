// android/build.gradle.kts (PROJECT LEVEL)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Google Services plugin (required for google-services.json)
        classpath("com.google.gms:google-services:4.4.2")

        // ✅ Crashlytics Gradle plugin (required if you apply crashlytics in app module)
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter/Gradle projects often use this clean task.
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
