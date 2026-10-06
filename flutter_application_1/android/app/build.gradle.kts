import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release identity and signing come from android/key.properties (git-ignored)
// or CI environment variables, never from the repository. See key.properties.example.
val releaseProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun releaseSetting(key: String, env: String): String? =
    (releaseProperties.getProperty(key) ?: System.getenv(env))?.takeIf { it.isNotBlank() }

val releaseApplicationId = releaseSetting("applicationId", "WASTELESS_APPLICATION_ID")
val releaseStoreFile = releaseSetting("storeFile", "WASTELESS_ANDROID_KEYSTORE")
val releaseStorePassword = releaseSetting("storePassword", "WASTELESS_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = releaseSetting("keyAlias", "WASTELESS_ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSetting("keyPassword", "WASTELESS_ANDROID_KEY_PASSWORD")

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The placeholder ID is for local debug builds only; release builds
        // refuse to run without WASTELESS_APPLICATION_ID (checked below).
        applicationId = releaseApplicationId ?: "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Never the debug key: without release credentials the build stops.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val releasing = allTasks.any { it.project == project && it.name.contains("Release") }
    if (!releasing) return@whenReady
    val missing = listOfNotNull(
        "applicationId (WASTELESS_APPLICATION_ID)".takeIf {
            releaseApplicationId?.startsWith("com.example.") != false
        },
        "storeFile (WASTELESS_ANDROID_KEYSTORE)".takeIf { releaseStoreFile == null },
        "storePassword (WASTELESS_ANDROID_STORE_PASSWORD)".takeIf { releaseStorePassword == null },
        "keyAlias (WASTELESS_ANDROID_KEY_ALIAS)".takeIf { releaseKeyAlias == null },
        "keyPassword (WASTELESS_ANDROID_KEY_PASSWORD)".takeIf { releaseKeyPassword == null },
    )
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Wasteless release build is missing: ${missing.joinToString()}. " +
                "Set them in android/key.properties or the environment; see key.properties.example."
        )
    }
}
