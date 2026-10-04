import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "cn.bh2vsq.qslmanager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "cn.bh2vsq.qslmanager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core:1.17.0")
}

// Flutter CLI compatibility for modern AGP plugin DSL.
// AGP can successfully create the APK while Flutter fails to discover it.
// Copy the generated APK to the project-level directory Flutter scans.
val flutterCliApkDir = rootProject.projectDir.parentFile.resolve("build/app/outputs/flutter-apk")

gradle.buildFinished {
    val candidateDirs = listOf(
        layout.buildDirectory.get().asFile.resolve("outputs/apk/release"),
        projectDir.resolve("build/outputs/apk/release")
    )

    val apkFiles = candidateDirs
        .filter { it.isDirectory }
        .flatMap { dir -> dir.listFiles()?.filter { it.isFile && it.extension == "apk" } ?: emptyList() }

    if (apkFiles.isNotEmpty()) {
        flutterCliApkDir.mkdirs()
        apkFiles.forEach { apk ->
            apk.copyTo(flutterCliApkDir.resolve(apk.name), overwrite = true)
        }
        println("[flutter-cli-fix] Copied ${apkFiles.size} APK(s) to $flutterCliApkDir")
    } else {
        println("[flutter-cli-fix] No release APK found in: $candidateDirs")
    }
}

flutter {
    source = "../.."
}
