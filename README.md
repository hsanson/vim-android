# What is this?

The most complete plugin there is to develop [Android](http://www.android.com) applications within vim.

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
