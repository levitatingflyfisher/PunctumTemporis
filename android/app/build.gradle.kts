plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.openhearth.punctumtemporis"
    compileSdk = flutter.compileSdkVersion // 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Fleet-convention identity (was com.example.one_second_a_day; installs of
        // the old id migrate via backup export → side-by-side restore, see
        // docs/how-to/migrate-app-id.md).
        applicationId = "com.openhearth.punctumtemporis"
        minSdk = 24 // flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion // 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
	    isMinifyEnabled = false
	    isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
