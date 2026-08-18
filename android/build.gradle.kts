allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    if (project.name != "app") {
        afterEvaluate {
            if (project.hasProperty("android")) {
                val androidExtension = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
                if (androidExtension != null) {
                    // 1. Injects missing namespace for legacy plugins
                    if (androidExtension.namespace == null) {
                        androidExtension.namespace = if (project.name == "perfect_volume_control") {
                            "top.huic.perfect_volume_control.perfect_volume_control"
                        } else {
                            project.group.toString().ifEmpty { "com.example.${project.name}" }
                        }
                    }

                    // 2. Upgrades Java 8 target to Java 17 to eliminate the obsolete 8 warning
                    androidExtension.compileOptions.apply {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}