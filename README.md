# What is this?

The most complete plugin there is to develop [Android](http://www.android.com) applications within vim.

This plugin when installed will try to detect if you are working on an Android application by looking for the AndroidManifest.xml file in your current directory. If the file is found then vim adds several commands and variables that facilitate development of Android within vim.

# Features

 - Updates the CLASSPATH environment variable to include JARs for the target Android API, included libs, external lib-projects and the current project.
 - Adds commands to build and install APK files in one or all devices/emulators present.
 - Adds commands to generate tag files for the Android SDK as well as your Android application.

# Details

Refer to the [doc/vim-android.txt](doc/vim-android.txt) file for details on usage and configuration of this plugin.
