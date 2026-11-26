import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase config is per-developer and untracked. Without it the build still
// works and push registration reports itself unavailable at runtime.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing comes from android/key.properties (untracked). Without it,
// release builds fall back to the debug key so `flutter run --release` works.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.navadeep.docket"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // Permanent once published: Google OAuth and Firebase clients are registered
        // against this ID plus the signing certificate fingerprint.
        applicationId = "com.navadeep.docket"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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

// Drop the x86_64 slice from release builds: emulators and a few Chromebooks,
// about 46 MB of engine, ML Kit and PDF native code no shipped device uses.
// Not ndk.abiFilters: the Flutter Gradle plugin rewrites those from
// --target-platform, and they conflict with --split-per-abi. Excluding at
// packaging time holds for every release variant. Debug keeps x86_64 so
// emulators still work.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.add("lib/x86_64/**")
    }
}

// Swap ML Kit face detection and barcode scanning from the bundled model
// variants to the Play Services ones: identical API surface (no Dart changes),
// but the models are fetched by Play Services instead of shipping in the APK.
// Text recognition stays bundled so MRZ/OCR works offline on a fresh install.
configurations.all {
    exclude(group = "com.google.mlkit", module = "face-detection")
    exclude(group = "com.google.mlkit", module = "barcode-scanning")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-mlkit-face-detection:17.1.0")
    implementation("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")

    implementation("org.jmrtd:jmrtd:0.7.38")
    implementation("net.sf.scuba:scuba-sc-android:0.0.23")
    implementation("org.bouncycastle:bcprov-jdk18on:1.75")
    implementation("com.github.Tgo1014:JP2ForAndroid:1.0.4") {
        exclude(group = "org.bouncycastle", module = "bcprov-jdk15to18")
    }
}
