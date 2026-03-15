# ProGuard rules for Foxgeen Mobile
# Fix for ucrop/okhttp3/okio missing classes during R8 shrinkage

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.yalantis.ucrop.**
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
