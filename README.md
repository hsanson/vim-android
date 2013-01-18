# What is this?

This is a fork of [android-javacomplete](https://github.com/hsanson/android-javacomplete) with some improvements:

 - Remove dependency on vimgrep that messes the quickfix window.
 - Create a vim folder structure that works with [vim-pathogen](https://github.com/tpope/vim-pathogen)
 - Added a global variable to set the android SDK path.

What this plugin does is search for the AndroidManifest.xml file in the current path and if found it tries to find out what is the android target API version. Once found it updates the CLASSPATH environment variable with the android sdk jar of that target allowing auto-completion of all android classes.

This plugin depends on the [javacomplete](http://www.vim.org/scripts/script.php?script_id=1785) plugin so make sure you have it installed and working.

# Recommended plugins

For a better vim experience I also recommend these plugins:

 - [neocomplcache](https://github.com/Shougo/neocomplcache) plugin for automatic auto-completion of Android code.
 - [easytags](https://github.com/xolox/vim-easytags)
 - [tagbar](https://github.com/majutsushi/tagbar)

# Install

If you use pathogen clone this repository inside your bundle folder:

```bash
git submodule add git@github.com:hsanson/android-javacomplete.git bundle/android-javacomplete
```

if you do not use pathogen simply clone the repo and copy the after folder into your VIMHOME (usually ~/.vim in Linux).

```bash
cp -rf after ~/.vim
```

Before you start using this plugin you must tell it where you have the Android SDK installed by setting the g:android_sdk_path global variable:

```
let g:android_sdk_path='/opt/android-sdk'
```

# Usage

This plugin works only if the AndroidManifest.xml file is located in your current path. That is if your current directory is the android project's root path.

The script will recognize this is an Android project by checking AndroidManifest.xml and will get the target from project.properties, then it will prepend the jar path to CLASSPATH and the [Android API](http://developer.android.com/reference/android/widget/package-summary.html) will be available to omnifunc completion.


# License (same as original author)

As usual (will fill in when I'll manage to understand license-world).

Enjoy
