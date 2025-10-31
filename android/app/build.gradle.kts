
    }

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("HOME") + "/trudido-release-key.jks")
            storePassword = "^%o7^7#rK#r2J@3&59*H$798E"
            keyAlias = "trudido-key"
            keyPassword = "^%o7^7#rK#r2J@3&59*H$798E"
        }
    }



----

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.trudido.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.trudido.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Keystore from environment variables for safety
            storeFile = file(System.getenv("HOME") + "/trudido-release-key.jks")
            storePassword = System.getenv("^%o7^7#rK#r2J@3&59*H$798E")
            keyAlias = System.getenv("trudido-key")
            keyPassword = System.getenv("^%o7^7#rK#r2J@3&59*H$798E")
        }
    }








    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}

