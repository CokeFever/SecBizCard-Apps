import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.ixo.secbizcard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Required by the official OpenCV Maven artifact (org.opencv:opencv), which
    // ships its native libraries as a Prefab module (opencv_java4).
    buildFeatures {
        prefab = true
    }

    // Package native libraries uncompressed and page-aligned so that .so files
    // load correctly on devices using 16 KB memory pages (Android 15+).
    // Google Play requires 16 KB page-size support for apps targeting API 35+.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.ixo.secbizcard"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resConfigs("en", "zh", "zh_TW")

        // The official OpenCV Prefab module (opencv_java4) links against the
        // shared C++ runtime, so the native build must use c++_shared instead
        // of the default static STL. Without this the build fails with
        // "User is using a static STL but library requires a shared STL".
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyProperties.load(FileInputStream(keyPropertiesFile))

                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            } else {
                // Fallback to environment variables for CI/CD
                val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH") ?: "upload-keystore.jks"
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                
                println("Using environment variables for signing: storeFile=$keystorePath, keyAlias=${System.getenv("ANDROID_KEY_ALIAS")}")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // R8 is enabled by default in release builds for shrinking and obfuscation.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    dependencies {
        // Official OpenCV Android artifact from Maven Central.
        // Replaces the discontinued com.quickbirdstudios:opencv:4.5.3.0, whose
        // native .so files were only 4 KB aligned and fail Google Play's 16 KB
        // page-size requirement. 4.14.0 ships 16 KB-aligned (0x4000) libraries
        // and keeps the same org.opencv.* Java API used by the native code.
        implementation("org.opencv:opencv:4.14.0")
        implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
        implementation("com.google.android.play:integrity:1.6.0")
    }
}

flutter {
    source = "../.."
}
