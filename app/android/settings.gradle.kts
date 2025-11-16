import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    repositories {
        google()
        maven { url = uri("https://dl.google.com/dl/android/maven2/") }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        maven { url = uri("https://dl.google.com/dl/android/maven2/") }
        mavenCentral()
        // Add Maven repository for dev dependencies if using --dev mode
        if (false) {
            maven {
                url = uri("https://jitpack.io")
            }
        }
    }
}

rootProject.name = "Together"
include(":app")

// In dev mode, use GitHub dependency; otherwise use local backend
if (!false) {
    includeBuild("../backends/android") {
        dependencySubstitution {
            substitute(module("dev.waterui.android:runtime")).using(project(":runtime"))
        }
    }
}
