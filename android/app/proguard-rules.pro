# ProGuard rules for the SALAMA ATTENDANCE terminal
# This file protects critical classes for face recognition and hardware access.

## Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

## TensorFlow Lite (Critical for Face Recognition)
-keep class org.tensorflow.lite.** { *; }
-keepnames class org.tensorflow.lite.**
-keep class com.google.android.gms.tflite.** { *; }
# Ignore missing GPU delegate options if not using GPU delegate
-dontwarn org.tensorflow.lite.gpu.**

## Google Play Core (Fixes R8 missing classes)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.internal.play_billing.**

## Google ML Kit (Face Detection)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-keep class com.google.android.gms.tflite.** { *; }

## Sqflite (Local Database)
-keep class com.tekartik.sqflite.** { *; }

## Camera & Mobile Scanner
-keep class io.flutter.plugins.camera.** { *; }
-keep class dev.vinicios.mobile_scanner.** { *; }

## JSON Serialization
# If you use specific models for JSON parsing, keep them from being renamed
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

## Prevent shrinking of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Flutter SVG
-keep class com.caverock.androidsvg.** { *; }
