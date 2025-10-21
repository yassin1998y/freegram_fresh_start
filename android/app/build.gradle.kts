plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.freegram_fresh_start"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // *** ADD THIS LINE ***
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.freegram_fresh_start"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // *** ADD THIS LINE if targeting API 34+ (recommended for newer features) ***
        multiDexEnabled = true // Enable multidex
    }

    buildTypes {
        release {
            // Enables code shrinking, obfuscation, and optimization for release builds.
            isMinifyEnabled = true
            isShrinkResources = true

            // Specifies the Proguard configuration files.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// *** ADD THIS ENTIRE BLOCK (or add the coreLibraryDesugaring line if dependencies exist) ***
dependencies {
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.8.0")) // Example Kotlin BOM, adjust if needed

    // *** ADD THIS LINE FOR DESUGARING ***
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Add other dependencies if you have them here
}
