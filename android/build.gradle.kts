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
// Plugin modules pin their own compileSdk, and several still pin 34 while
// their AndroidX dependencies now require 36. The build then fails in the
// plugin, not in this app - `:file_picker is currently compiled against
// android-34`.
//
// Raising them here rather than chasing plugin versions: upgrading file_picker
// far enough drags in a win32 range that syncfusion_flutter_pdfviewer cannot
// satisfy, and the next plugin to fall behind would need the same dance again.
//
// compileSdk only decides which APIs are available at compile time. minSdk and
// targetSdk are untouched, so this changes neither which devices can install
// the app nor which runtime behaviours it opts into.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        // Reflection because the root build script has no AGP types on its
        // classpath, and the setter's name is stable across AGP 8 and 9.
        runCatching {
            android.javaClass
                .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(android, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
