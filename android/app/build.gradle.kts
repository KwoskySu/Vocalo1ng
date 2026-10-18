plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.vocashelf.vocashelf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.vocashelf.vocashelf"
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
        externalNativeBuild {
            cmake {
                arguments += listOf("-DNODE_MOBILE_ROOT=E:/gpt-vocal/node-mobile", "-DANDROID_STL=c++_shared")
            }
        }
    }

    buildTypes {
        release {
            // AGP/R8 currently rewrites Pigeon suspend interfaces incompatibly
            // with the bundled Kotlin shared_preferences implementation.
            isMinifyEnabled = false
            isShrinkResources = false
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty("maven.repo.local", "E:/gpt-vocal/robolectric")
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}

// Flutter's asset copy task and AGP 9's resource-aware JVM test packaging
// otherwise share an output without a declared ordering dependency.
tasks.matching { it.name == "packageDebugUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsDebug")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
