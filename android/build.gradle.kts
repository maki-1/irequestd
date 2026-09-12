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
    project.evaluationDependsOn(":app")
}

// blue_thermal_printer (kiosk Bluetooth receipt printing) predates AGP's
// namespace requirement and has none in its own build.gradle, which fails the
// build under this project's AGP version ("Namespace not specified"). It
// can't be edited in place — that file lives in the pub cache, not this repo
// — so the namespace is supplied here instead, matching the package already
// declared in the plugin's own AndroidManifest.xml.
subprojects {
    val fixNamespace: () -> Unit = {
        if (project.name == "blue_thermal_printer") {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null && android.namespace == null) {
                android.namespace = "id.kakzaki.blue_thermal_printer"
            }
        }
    }
    // evaluationDependsOn(":app") above can make a subproject's evaluation
    // happen before this block runs for it, in which case afterEvaluate()
    // throws instead of just running late — so pick whichever still works.
    if (project.state.executed) fixNamespace() else afterEvaluate { fixNamespace() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
