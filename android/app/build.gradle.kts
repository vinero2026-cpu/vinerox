import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

// A partially filled key.properties is worse than none: it fails the build with
// an opaque cast error, so require every field before using it.
val hasUploadKey = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    .all { !(keystoreProperties[it] as String?).isNullOrBlank() }

android {
    namespace = "app.vinero.vinorox_mobile"
    compileSdk = 36
    // Highest NDK required by the bundled plugins (path_provider, sqflite, ...).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
            applicationId = "app.vinero.vinorox_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasUploadKey) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            } else if (gradle.startParameter.taskNames.any { it.contains("Release") }) {
                throw GradleException(
                    "Missing or incomplete android/key.properties — need keyAlias, " +
                        "keyPassword, storeFile and storePassword."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
