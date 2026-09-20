# ==============================================================================
# R8 / ProGuard keep rules for SecBizCard (release builds)
# ==============================================================================
# R8 is enabled in release (isMinifyEnabled + isShrinkResources, using
# proguard-android-optimize.txt). These rules are a SAFETY NET: they keep the
# code that R8's static analysis cannot see is reachable — anything reached via
# JNI, reflection, or native model loading — so an aggressive shrink/optimize
# pass (ours or a future dependency's) can't strip it and cause a release-only
# crash (which never shows up in debug).
#
# This does NOT chase Play's "optimization %" score; it protects correctness.
# Each block says WHY it exists so future edits stay deliberate.
# ==============================================================================

# --- Generic JNI safety -------------------------------------------------------
# Any class with native methods, and the native methods themselves, must be
# kept: R8 can't see the C/C++ side, and renaming/removing breaks the JNI link.
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- OpenCV (org.opencv.*) ----------------------------------------------------
# OpenCV ships as the official Maven artifact `org.opencv:opencv:4.14.0` with
# native libs via the Prefab module `opencv_java4`. The Java API is a thin layer
# over JNI — the native side references these Java classes/fields by name, so
# they must not be renamed or removed. Used by OpenCVProcessor.kt for card
# detection / perspective correction.
-keep class org.opencv.** { *; }
-dontwarn org.opencv.**

# --- Google ML Kit text recognition ------------------------------------------
# On-device OCR fallback. ML Kit loads models and uses reflection internally;
# keep its classes and silence warnings for the language packs we bundle.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- Google Play Integrity ----------------------------------------------------
# `com.google.android.play:integrity` uses reflection; keep its API surface.
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.**

# --- Firebase -----------------------------------------------------------------
# Firebase (Auth / Firestore / Functions / Messaging) relies on reflection for
# model (de)serialization and callback wiring. The Firebase SDKs ship their own
# consumer rules, but we keep our own guard for any model classes and silence
# stray warnings so a strict pass can't trip on them.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Flutter embedding --------------------------------------------------------
# Flutter's own rules are applied by the tool, but keep the embedding + our
# MethodChannel entry points (MainActivity / OpenCVProcessor are referenced by
# the engine, not by app code, so make the intent explicit).
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class app.ixo.secbizcard.MainActivity { *; }
-keep class app.ixo.secbizcard.OpenCVProcessor { *; }

# --- Enums --------------------------------------------------------------------
# Enums accessed by name (valueOf / values) via reflection must keep those
# synthesized methods; this is the standard, low-cost safeguard.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- Parcelables --------------------------------------------------------------
# Keep the CREATOR field for any Parcelable (accessed reflectively by the OS).
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
