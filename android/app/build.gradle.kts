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

// Fix for ffmpeg_kit_flutter namespace issue - Run during configuration phase
val userHome = System.getProperty("user.home")
val osName = System.getProperty("os.name").lowercase()

// Handle Windows vs Unix pub cache locations
// Use forward slashes - Gradle's file() function handles path conversion
val pubCacheBase = when {
    osName.contains("win") -> {
        "$userHome/AppData/Local/Pub/Cache"
    }
    else -> {
        "$userHome/.pub-cache"
    }
}

// Dynamically find ffmpeg_kit_flutter or ffmpeg_kit_flutter_new plugin directory
val pubCacheFfmpegDir = file("$pubCacheBase/hosted/pub.dev")
val ffmpegPluginDirs = pubCacheFfmpegDir.listFiles()?.filter { 
    it.isDirectory && (it.name.startsWith("ffmpeg_kit_flutter-") || it.name.startsWith("ffmpeg_kit_flutter_new-"))
}?.sortedByDescending { it.name } // Get latest version first

val pubCachePath = if (ffmpegPluginDirs != null && ffmpegPluginDirs.isNotEmpty()) {
    "${ffmpegPluginDirs.first().absolutePath}/android"
} else {
    // Fallback - try new package first, then old
    "$pubCacheBase/hosted/pub.dev/ffmpeg_kit_flutter_new-1.6.1/android"
}

// Try both .gradle and .gradle.kts files
val buildGradleFile = file("$pubCachePath/build.gradle")
val buildGradleKtsFile = file("$pubCachePath/build.gradle.kts")

val targetFile = when {
    buildGradleFile.exists() -> buildGradleFile
    buildGradleKtsFile.exists() -> buildGradleKtsFile
    else -> null
}

try {
    if (targetFile != null && targetFile.exists()) {
        var content = targetFile.readText()
        
        // Check if namespace is already set (look for the exact namespace we want to add)
        val hasNamespace = content.contains("namespace") && 
                          (content.contains("com.arthenica.ffmpegkit") || 
                           content.contains("\"com.arthenica.ffmpegkit\"") ||
                           content.contains("'com.arthenica.ffmpegkit'"))
        
        var needsUpdate = false
        
        // Check if namespace needs to be added
        if (!hasNamespace) {
            needsUpdate = true
            // Find the android block and add namespace
            if (content.contains("android {")) {
                // Use Groovy syntax (most common for plugins)
                val namespaceLine = "    namespace \"com.arthenica.ffmpegkit\""
                // Replace only the first occurrence of "android {" to avoid issues
                val firstAndroidBlockIndex = content.indexOf("android {")
                if (firstAndroidBlockIndex >= 0) {
                    val beforeAndroid = content.substring(0, firstAndroidBlockIndex)
                    val afterAndroid = content.substring(firstAndroidBlockIndex + "android {".length)
                    content = "$beforeAndroid android {\n$namespaceLine$afterAndroid"
                    println("  Added: $namespaceLine")
                } else {
                    println("⚠ Could not find 'android {' block position in ffmpeg_kit_flutter build file")
                    needsUpdate = false
                }
            } else {
                println("⚠ Could not find 'android {' block in ffmpeg_kit_flutter build file")
                println("  File content preview: ${content.take(200)}...")
                needsUpdate = false
            }
        } else {
            println("✓ Namespace already set in ffmpeg_kit_flutter build file")
        }
        
        // Check if repositories need to be added for ffmpeg-kit dependencies
        // Add both to buildscript and rootProject.allprojects
        val needsJitPack = !content.contains("jitpack.io") && !content.contains("JitPack")
        
        // Add to buildscript repositories
        if (needsJitPack && content.contains("buildscript {")) {
            needsUpdate = true
            val buildscriptRepos = "buildscript {\n    repositories {"
            if (content.contains(buildscriptRepos) && !content.contains("jitpack")) {
                val jitPackRepo = "        maven { url 'https://jitpack.io' }"
                content = content.replace(
                    "repositories {\n        google()\n        mavenCentral()\n    }",
                    "repositories {\n        google()\n        mavenCentral()\n$jitPackRepo\n    }"
                )
                println("  Added JitPack to buildscript repositories")
            }
        }
        
        // Add to rootProject.allprojects repositories
        if (needsJitPack && content.contains("rootProject.allprojects")) {
            needsUpdate = true
            if (content.contains("rootProject.allprojects {\n    repositories {\n        google()\n        mavenCentral()\n    }")) {
                val jitPackRepo = "        maven { url 'https://jitpack.io' }"
                content = content.replace(
                    "rootProject.allprojects {\n    repositories {\n        google()\n        mavenCentral()\n    }",
                    "rootProject.allprojects {\n    repositories {\n        google()\n        mavenCentral()\n$jitPackRepo\n    }"
                )
                println("  Added JitPack to rootProject.allprojects repositories")
            }
        }
        
        // Handle dependency issues (only for old ffmpeg_kit_flutter package)
        // The new ffmpeg_kit_flutter_new package should work without issues
        val isNewPackage = pubCachePath.contains("ffmpeg_kit_flutter_new")
        
        if (!isNewPackage && content.contains("implementation 'com.arthenica:ffmpeg-kit-https:")) {
            needsUpdate = true
            val dependencyPattern = "implementation 'com.arthenica:ffmpeg-kit-https:([^']+)'".toRegex()
            val match = dependencyPattern.find(content)
            
            if (match != null) {
                val currentVersion = match.groupValues[1]
                println("  ⚠️  WARNING: Old ffmpeg_kit_flutter package detected with problematic dependency")
                println("     Consider migrating to ffmpeg_kit_flutter_new package")
                println("     Attempting to fix dependency version...")
                
                // Try to use a version that might exist
                content = content.replace(
                    "implementation 'com.arthenica:ffmpeg-kit-https:$currentVersion'",
                    "implementation 'com.arthenica:ffmpeg-kit-https:5.0.3'"
                )
                println("     Changed dependency version to 5.0.3 (may still fail if not available)")
            }
        }
        
        // Save the file if updates were made
        if (needsUpdate) {
            // Make file writable if it's read-only
            targetFile.setWritable(true)
            targetFile.writeText(content)
            println("✓ Fixed ffmpeg_kit_flutter build file at: ${targetFile.absolutePath}")
        }
    } else {
        println("⚠ Could not find ffmpeg_kit_flutter build file at: $pubCachePath")
        println("  Searched for:")
        println("    - $pubCachePath/build.gradle")
        println("    - $pubCachePath/build.gradle.kts")
        println("  The plugin may not be downloaded yet. Run 'flutter pub get' first.")
    }
} catch (e: Exception) {
    println("⚠ Error fixing ffmpeg_kit_flutter namespace: ${e.message}")
    println("  This is a known issue with ffmpeg_kit_flutter 5.1.0")
    println("  You may need to manually add 'namespace \"com.arthenica.ffmpegkit\"' to the plugin's build.gradle file")
}

dependencies {
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.8.0"))
    
    // Core Library Desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Google Play Services - Use consistent versions
    implementation("com.google.android.gms:play-services-base:18.2.0")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("com.google.android.gms:play-services-ads:22.6.0")
    
    // Force consistent Google Play Services versions
    implementation("com.google.android.gms:play-services-measurement-api:21.6.1")
    
    // Firebase BOM (Bill of Materials) - manages all Firebase library versions
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    
    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
    
    // Firebase Messaging
    implementation("com.google.firebase:firebase-messaging")
    
    // Firebase Auth
    implementation("com.google.firebase:firebase-auth")
    
    // Firebase Firestore
    implementation("com.google.firebase:firebase-firestore")
    
    // Firebase Storage
    implementation("com.google.firebase:firebase-storage")

    // Multidex support
    implementation("androidx.multidex:multidex:2.0.1")

    // FFmpegKit - Workaround for ffmpeg_kit_flutter_android plugin missing classes
    // Note: FFmpegKit was discontinued, so Maven dependencies may not be available
    // The plugin should provide these via AAR files, but if not, we try to add them here
    // Commenting out for now as Maven dependencies are no longer available
    // implementation("com.arthenica:ffmpeg-kit-full:6.0-2.LTS")
}