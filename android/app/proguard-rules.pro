# Picked up automatically by the Flutter Gradle plugin for release builds.

# flutter_local_notifications caches scheduled notifications as JSON via Gson.
# Without these rules R8 strips the generic signatures Gson needs, and every
# zonedSchedule()/cancel() call fails in release builds with
# "TypeToken must be created with a type argument".
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# The plugin's notification models are (de)serialized by field name.
-keep class com.dexterous.** { *; }
