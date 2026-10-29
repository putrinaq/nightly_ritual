plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.nightly_ritual"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.nightly_ritual"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Spotify OAuth callback scheme, read from SPOTIFY_REDIRECT_URI in the
        // project's .env so a custom redirect only has to be set in one place.
        val envFile = rootProject.file("../.env")
        val redirect = if (envFile.exists()) {
            envFile.readLines()
                .map { it.trim() }
                .firstOrNull { it.startsWith("SPOTIFY_REDIRECT_URI=") }
                ?.substringAfter("=")?.trim()?.trim('"', '\'')
        } else null
        manifestPlaceholders["spotifyRedirectScheme"] =
            redirect?.takeIf { "://" in it }?.substringBefore("://") ?: "ritual"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
