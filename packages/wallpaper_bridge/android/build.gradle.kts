group = "com.yusufaycicek.wallpaper_bridge"
version = "1.0"

buildscript {
    val kotlinVersion = "2.2.0"

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.12.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

// AGP 9 ships Kotlin support unless the app opts out with
// android.builtInKotlin=false (what `flutter create` writes today).
val builtInKotlinEnabled =
    agpMajor >= 9 &&
        (providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() ?: true)

if (!builtInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.yusufaycicek.wallpaper_bridge"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}
