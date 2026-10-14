plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.myisn"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.myisn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Kunci tanda tangan TETAP milik ISKOM (bukan kunci debug bawaan Gradle).
    // Tanpa kunci ini, setiap build di runner GitHub dibangkitkan ulang kunci
    // debug-nya sehingga tanda tangan APK berubah tiap rilis dan Android
    // menolak memasang APK baru di atas aplikasi yang sudah terpasang.
    // Salinan cadangan kunci disimpan di luar repo (VPS:
    // ~/.hermes/state/iskom-signing-backup.p12) - jangan diganti selama
    // aplikasi ini masih dipakai staf, karena tanda tangannya jadi berbeda lagi.
    signingConfigs {
        create("iskom") {
            storeFile = file("iskom-signing.p12")
            storeType = "PKCS12"
            storePassword = "iskom2026"
            keyAlias = "iskom"
            keyPassword = "iskom2026"
        }
    }

    buildTypes {
        debug {
            // APK debug yang dibagikan ke staf ikut memakai kunci tetap ini,
            // supaya APK rilis berikutnya bisa menimpa yang sudah terpasang
            // (kunci debug Gradle yang dibangkitkan ulang tiap runner GitHub
            // membuat tanda tangannya BERUBAH tiap build -> instalasi
            // pembaruan ditolak Android dengan "Aplikasi tidak terpasang").
            signingConfig = signingConfigs.getByName("iskom")
        }
        release {
            signingConfig = signingConfigs.getByName("iskom")
            
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
