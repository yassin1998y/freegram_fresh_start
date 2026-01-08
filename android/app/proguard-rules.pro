# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-keepattributes Signature
-keepattributes Exceptions
-keepclassmembers class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Firebase Core and common Firebase libraries
-keep class com.google.firebase.** { *; }
-keepattributes Signature
-keepnames class com.google.android.gms.tasks.** { *; } # Keep for Task API
-dontwarn com.google.firebase.** # Suppress warnings from Firebase libraries, they usually handle their own Proguard needs

# Firebase Auth
-keepattributes JavascriptInterface
-keepclassmembers class * implements com.google.firebase.auth.FirebaseUser { *; }

# Firebase Firestore
-keepnames class com.google.firebase.firestore.** { *; }

# Firebase Storage (Keep if you still use it for profile pictures etc.)
-keepnames class com.google.firebase.storage.** { *; }

# Firebase Crashlytics (Keep if used)
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.abt.** { *; }

# Google Mobile Ads (AdMob)
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keepclassmembers class ** { @com.google.android.gms.common.util.RetainForClient *; }

# --- REMOVED: video_player plugin rules ---
# -keep class com.google.android.exoplayer2.** { *; }
# -dontwarn com.google.android.exoplayer2.**

# --- REMOVED: ffmpeg_kit_flutter rules ---
# -keep class com.arthenica.ffmpegkit.** { *; }
# -dontwarn com.arthenica.ffmpegkit.**

# image_picker (Keep for profile pictures)
-keep public class androidx.core.content.FileProvider { *; }

# For Hive (Keep)
# Note: Newer Hive versions might not need these explicit rules if setup correctly
-keep class * extends io.flutter.plugins.hive.HiveObject { *; }
-keep class * implements io.flutter.plugins.hive.adapters.TypeAdapter { *; }
-keepclassmembers class * {
    @io.flutter.plugins.hive.HiveField <fields>;
    @io.flutter.plugins.hive.HiveType <fields>;
}
-keepattributes *Annotation*
# End of Hive Rules

# Keep native libraries (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Rules for gRPC/OkHttp (Used by Firestore/Firebase)
-keep class com.squareup.okhttp.CipherSuite { *; }
-keep class com.squareup.okhttp.ConnectionSpec { *; }
-keep class com.squareup.okhttp.TlsVersion { *; }

-dontwarn com.squareup.okhttp.CipherSuite
-dontwarn com.squareup.okhttp.ConnectionSpec
-dontwarn com.squareup.okhttp.TlsVersion

# Keep Guava classes (often uses reflection)
-keep class com.google.common.** { *; }
-dontwarn com.google.common.**

# --- ADDED: Keep rules for R8 error fix ---
# Keep AnnotatedType needed by Guava/reflection used in Firebase/Google libs

-keep class java.lang.reflect.AnnotatedType
-keep class * extends java.lang.reflect.AnnotatedType
-keep interface java.lang.reflect.AnnotatedType
-keep interface * extends java.lang.reflect.AnnotatedType
# --- END ADDED RULES ---


# Keep MainActivity, AdvertiserManager, and MainApplication to prevent crashes
# Only keep necessary classes - code shrinking and obfuscation enabled for security
-keep class com.freegram.app.MainActivity { *; }
-keep class com.freegram.app.AdvertiserManager { *; }
-keep class com.freegram.app.MainApplication { *; }
-keep class com.freegram.app.BluetoothForegroundService { *; }

# Google Play Services specific rules
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.ads.** { *; }

# Keep Google API classes
-keep class com.google.api.** { *; }
-keep class com.google.protobuf.** { *; }