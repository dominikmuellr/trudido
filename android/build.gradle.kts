allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force all plugins to use the same compileSdk
subprojects {
    project.plugins.withId("com.android.library") {
        val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        android.compileSdkVersion(36)
    }
    project.plugins.withId("com.android.application") {
        val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        android.compileSdkVersion(36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
