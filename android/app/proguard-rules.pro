# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.plugins.**  { *; }
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

# Firebase Storage
-keepnames class com.google.firebase.storage.** { *; }

# Firebase Crashlytics
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.abt.** { *; }

# Google Mobile Ads (AdMob)
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keepclassmembers class ** { @com.google.android.gms.common.util.RetainForClient *; }

# video_player plugin
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ffmpeg_kit_flutter
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# image_picker
-keep public class androidx.core.content.FileProvider { *; }

# For Hive
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

# Keep all classes and their members (added as per user request)
-keep class ** { *; }

# Rules for gRPC/OkHttp
-keep class com.squareup.okhttp.CipherSuite { *; }
-keep class com.squareup.okhttp.ConnectionSpec { *; }
-keep class com.squareup.okhttp.TlsVersion { *; }

-dontwarn com.squareup.okhttp.CipherSuite
-dontwarn com.squareup.okhttp.ConnectionSpec
-dontwarn com.squareup.okhttp.TlsVersion
