# What is this?

The most complete plugin there is to develop [Android](http://www.android.com) applications within vim.

$ Quick Start

Install the plugin using your favorite plugin manager (e.g. NeoBundle):

    NeoBundle "hsanson/vim-android"

Add *g:android_sdk_path* to your vimrc with the absolute path where the android sdk is installed:

    let g:android_sdk_path = /path/to/android-sdk

Optionally add *g:gradle_path* to the absolute path whre gradle is installed:

    let g:gradle_path = /path/to/gradle

Open a java or xml file of your project and use the Anroid command to compile, clean, test, lint or install your application:

    :Android clean
    :Android assembleDebug
    :Android installDebug
    :Android connectedCheck
    :Android lint

# Features

 - Automatically detect if file belongs to an android project when opening a java or xml file.
 - Updates the CLASSPATH environment variable to include jar and class files for the target Android API, included libs, external lib-projects and the current project. This can be used by other plugins like [javacomplete2](https://github.com/artur-shaik/vim-javacomplete2) to enable omnicompletion of these libraries.
 - Updates the SRCPATH environment variable to include the current project source path and any other dependency source files available. This allows plugins like [vebugger](https://github.com/idanarye/vim-vebugger) to track source during debugging within vim.
 - Sets custom gradle vim compiler.
 - Sets an extensive errorformat that captures java errors, linter errors, test errors, aapt errors and adds them to the qflist.
 - Adds commands to build and install APK files in one or all devices/emulators present.
 - Adds commands to generate tag files for the Android SDK as well as your Android application.

# Details

Refer to the [doc/vim-android.txt](doc/vim-android.txt) file for details on usage and configuration of this plugin.
