## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

## Remove Google Play Core classes (required for F-Droid)
## These are included by Flutter but not used by this app
-dontwarn com.google.android.play.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

## Explicitly remove Play Core classes - don't keep them
-assumenosideeffects class com.google.android.play.** { *; }
-assumenosideeffects class com.google.android.play.core.** { *; }
-assumenosideeffects class com.google.android.play.core.splitcompat.** { *; }
-assumenosideeffects class com.google.android.play.core.splitinstall.** { *; }
-assumenosideeffects class com.google.android.play.core.tasks.** { *; }

## Allow R8 to fully remove unused Play Core classes
-allowaccessmodification
-repackageclasses

## Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep custom parcelables
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

## AndroidX Work Manager
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keep class androidx.work.** { *; }

## Encryption library (for vault)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

## Keep model classes (adjust package name as needed)
-keep class com.trudido.app.models.** { *; }

## Biometric authentication
-keep class androidx.biometric.** { *; }

## Remove logging in release builds for additional size reduction
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

## General Android framework
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
