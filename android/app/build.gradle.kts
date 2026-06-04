import java.util.Properties
import java.io.FileInputStream

// Cargar propiedades del keystore (opcional: solo para builds release firmados)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val keystoreFileExists = keystorePropertiesFile.exists() &&
    run {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        val storeFile = keystoreProperties["storeFile"] as? String
        storeFile != null && file(storeFile).exists()
    }

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.impostor_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Configuración de firma — solo si el keystore existe en disco.
    // En debug se usa la firma de debug por defecto y no se necesita esto.
    if (keystoreFileExists) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.dreamers.impostorgame"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystoreFileExists) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Copiar APKs a donde Flutter los espera
afterEvaluate {
    tasks.register<Copy>("copyApks") {
        from(layout.buildDirectory.dir("outputs/apk"))
        into(File(project.rootDir.parentFile, "build/app/outputs/flutter-apk"))
        include("**/*.apk")
        eachFile {
            // Flatten: remove subdirectory (debug/, release/) so APKs end up at root
            relativePath = RelativePath(true, relativePath.lastName)
        }
        includeEmptyDirs = false
    }

    tasks.named("assembleDebug").configure {
        finalizedBy("copyApks")
    }

    tasks.named("assembleRelease").configure {
        finalizedBy("copyApks")
    }
}