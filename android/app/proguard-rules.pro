# UNEXA release ProGuard/R8 rules.
# The release build runs through R8 with the standard Flutter defaults
# (see flutter.gradle); these rules only add what our plugins need.

# ---- Flutter engine plumbing ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ---- Firebase ----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- Play Integrity (App Check) ----
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ---- google_sign_in ----
-keep class com.google.android.gms.auth.** { *; }

# ---- flutter_local_notifications ----
-keep class com.dexterous.** { *; }

# ---- flutter_pdfview ----
-keep class com.github.barteksc.** { *; }
-dontwarn com.github.barteksc.**

# ---- cached_network_image / dio stack ----
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep line numbers readable in crash reports without shipping full debug info
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
