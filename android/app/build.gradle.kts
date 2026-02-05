plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must be applied last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.trudido.app"
    compileSdk = 36
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
        minSdk = 24  // Required for video_player and other media features
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "store"
    productFlavors {
        create("playstore") {
            dimension = "store"
            // PlayStore build - donations hidden via Dart define
        }
        create("fdroid") {
            dimension = "store"
            // FDroid build - donations enabled via --dart-define=IS_FDROID=true
        }
    }

    signingConfigs {
        create("release") {
            val home = System.getenv("HOME") ?: System.getenv("USERPROFILE") ?: ""
            val keystorePath = "$home/Documents/keystores/trudido-release-key.jks"
            val keystoreFile = file(keystorePath)
            
            // Only configure signing if keystore exists and env vars are set
            if (keystoreFile.exists() && System.getenv("KEYSTORE_PASSWORD") != null) {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Only use signing config if keystore exists and is configured
            val releaseSigningConfig = signingConfigs.getByName("release")
            if (releaseSigningConfig.storeFile?.exists() == true) {
                signingConfig = releaseSigningConfig
            }
            // Enable code shrinking, obfuscation, and optimization (standard for production)
            isMinifyEnabled = true
            // Remove unused resources to reduce APK size
            isShrinkResources = true
            // Apply ProGuard rules for proper minification
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    implementation("com.google.guava:guava:31.1-android")
}
