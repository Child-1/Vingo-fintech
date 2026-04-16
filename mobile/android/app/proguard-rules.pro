# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress missing Play Core classes (not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep app entry points
-keep class com.myraba.app.** { *; }

# Prevent stripping of security-related classes
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep JSON model classes (used by http package)
-keepclassmembers class * {
    public <init>(org.json.JSONObject);
}
