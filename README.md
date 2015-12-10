# What is this?

This plugin provides functions that facilitate the development of Gradle based projects. It also has additional functions to support Android projects.

# Installation Start

Install the plugin using your favorite plugin manager (e.g. NeoBundle):

    NeoBundle "hsanson/vim-android"

If you have a gradle wrapper script (e.g gradlew or gradlew.bat) in your project rood directory or if you have gradle in your PATH environment, then you are good to go. If you prefer to setup a specific gradle version then you need to set *g:gradle_path* to the absolute path where gradle is installed:

    let g:gradle_path = /path/to/gradle/folder

this results in the plugin using the gradle binary located at:

    /path/to/gradle/folder/bin/gradle

If you are working in an Android project then set the *g:android_sdk_path*  with the absolute path where the android sdk is installed:

    let g:android_sdk_path = /path/to/android-sdk

# Usage

Open a java or xml source file and this plugin will automatically kick in and perform some tasks:

 - Execute a custom vim gradle task to inspect the project and extract dependencies, project names, and android sdk versions.
 - Set CLASSPATH environment variable with the JAR dependencies of the project and the Android SDK jar.
 - Set SRCPATH environment variables with the project source sets.
 - Create Gradle and Android commands that can be used to invoke gradle tasks.
 - Optionally set syntastic, and javacomplete2 variables.

Once the plugin finishes loading the Gradle command becomes available to use:

    :Gradle <task>

If the project is also an Android project then the android command also becomes available:

    :Android <task>

# Features

 - Automatically detect if file belongs to an android project when opening a java or xml file.
 - Adds custom tasks to gradle build using [Init scripts](https://docs.gradle.org/current/userguide/init_scripts.html).
 * Updates the CLASSPATH environment variable with all jar and class files for the target Android API and gradle dependencies. This can be used by other plugins like [javacomplete2](https://github.com/artur-shaik/vim-javacomplete2) to enable omnicompletion of these libraries.
 - Updates the SRCPATH environment variable to include the current project source path and any other dependency source files available. This allows plugins like [vebugger](https://github.com/idanarye/vim-vebugger) to track source during debugging within vim.
 - Sets custom gradle vim compiler.
 - Sets an extensive errorformat that captures java errors, linter errors, test errors, aapt errors and adds them to the qflist.
 - Adds commands to build and install APK files in one or all devices/emulators present.
 - Adds commands to generate tag files for the Android SDK as well as your Android application.
 - Improved XML omnicompletion for android resource and manifest files (Thanks to Donnie West).

# Details

Refer to the [doc/vim-android.txt](doc/vim-android.txt) file for details on usage and configuration of this plugin.
