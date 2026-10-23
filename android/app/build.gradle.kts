import java.util.Base64
import java.util.Properties
import java.net.URI

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val validateReleaseConfiguration = tasks.register("validateReleaseConfiguration") {
    doLast {
        for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            require(!keystoreProperties.getProperty(key).isNullOrBlank()) {
                "Release signing requires $key in android/key.properties. See docs/android-release.md."
            }
        }
        require(rootProject.file(keystoreProperties.getProperty("storeFile")).isFile) {
            "Release keystore not found. See docs/android-release.md."
        }
        val defines = (project.findProperty("dart-defines") as? String).orEmpty()
            .split(',').filter { it.isNotEmpty() }
            .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        val apiUrl = defines.lastOrNull { it.startsWith("API_BASE_URL=") }
            ?.substringAfter('=')
        val uri = runCatching { URI(apiUrl.orEmpty()) }.getOrNull()
        require(uri != null && uri.scheme == "https" && !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
            uri.path in listOf("/api/v1", "/api/v1/") &&
            uri.host !in listOf("localhost", "127.0.0.1", "[::1]", "10.0.2.2") &&
            !uri.host.endsWith(".invalid")) {
            "Release requires a production HTTPS API_BASE_URL ending in /api/v1. " +
                "Pass --dart-define-from-file=env/production.json. See docs/android-release.md."
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild" || name == "compileFlutterBuildRelease") {
        dependsOn(validateReleaseConfiguration)
    }
}

android {
    namespace = "id.bmafazi.vesper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.bmafazi.vesper"
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
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
