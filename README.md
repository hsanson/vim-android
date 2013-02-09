# What is this?

The most complete plugin there is to develop [Android](http://www.android.com) applications within vim.

This plugin when installed will try to detect if you are working on an Android application by looking for the AndroidManifest.xml file in your current directory. If the file is found then vim adds several commands and variables that facilitate development of Android within vim.

# Installation

It is highly recommended that you use [vundle](https://github.com/gmarik/vundle) or [pathogen](https://github.com/tpope/vim-pathogen) to
install this plugin. With vundle is as simple as adding the following line in your vimrc and running :BundleInstall within vim:

```bash
Bundle 'hsanson/vim-android.git'
```

If you don't like these plugin managers then download the plugin from github and copy all files into your vim runtime
directory:

```sh
git clone https://github.com/hsanson/vim-android.git  ~/vim-android
cp -rf ~/vim-android ~/.vim
```

# Configuration

This plugin depends on the Android SDK so it must be installed on your system. Before the plugin can work you must set the global variable *g:android_sdk_path* to the path where you have the SDK installed:

```vimscript
let g:android_sdk_path = '/path/to/android-sdk
```

The most important android tool this plugin requires is the *adb* tool. The plugin assumes it is located at *g:android_sdk_path/platform-tools/adb* but if for some reason in your installation it is located somewhere else you must tell the plugin by setting the global *g:android_adb_tool* variable:

```vimscript
let g:anroid_sdk_path = '/absolute/path/to/adb'
```

Optionally you can set the global variable *g:android_sdk_tags* to the path where the android SDK ctags file is to be located. This file is added to your *tags* variable when opening java files to enable auto-completion via ctags. If you do not set this variable then by default the plugin assumes it is at *~/.vim/tags/android*.

```vimscript
let g:android_sdk_tags = '/my/tags/android'
```

# Usage

All you have to do is make sure your current path (pwd) is where your AndroidManifest.xml is located. Once you open a java or xml file and the AndroidManifest.xml is in your current path this plugin kicks in and performs all the magic for you.

## Commands

If the plugin detects the AndroidManifest.xml file and the g:android_sdk_path is correctly set then it defines some commands that you can use to compile and install your application:

 - AndroidDebug: Compiles the application on debug mode.
 - AndroidRelease: Compiles the application on release mode.
 - AndroidDebugInstall: Compiles and installs the application in debug mode. I you have more than one device/emulator connected
    you will be prompted with a list of devices so you can select on which one to install. If no device or emulator is found then 
    this command fallbacks to compilation only.
 - AndroidReleaseInstall: Same as AndroidDebugInstall but in release mode.
 - AndroidUpdateAndroidTags: Creates a ctags file with the Android SDK sources. The resulting file is saved at *g:android_sdk_tags* if
    defined or at *~/.vim/tags/android* if not. This command depends on VimProc plugin so will only work if it is installed. Note that
    this command can take a long time to finish so only use it when you update the Android SDK with new versions.
 - AndroidUpdateProjectTags: Creates a ctags file with the current android project sources. The file is stored at the project root and
    called *.tags*. Make sure you add this file to your tags variable (e.g. set tags+=.tags).
 
## Command Mappings

You may prefer to map the above commands to some shorter strings so you do not have to type the commands every time:

```vimscript
nmap <F5> <ESC>:AndroidDebugInstall<CR>
```

If you prefer these mappings to take effect only when working on Android applications you may use the *android#isAndroidProject()* method. In your vimrc file add some lines like:

```vimscript
if android#isAndroidProject()
  au BufNewFile,BufRead *.java,*.xml nmap <F5> <ESC>:AndroidDebugInstall<CR>
endif
```

Now everytime you open a java or xml file and your current path has an AndroidManifest.xml the F5 key is mapped to the AndroidDebugInstall command.

You can also map the *AndroidUpdateProjectTags* with an auto command so it is executed every time you save a buffer or after compiling the project. Keeping your ctags up to date is important to enable tags navigation and tag based auto-completion of code.

## Auto-completion

This plugin by itself does not provide auto-completion of Android code but it configures the environment CLASSPATH variable so other plugins like [javacomplete](https://github.com/vim-scripts/javacomplete) can omni-complete Android packages, classes, and methods.

What this plugin does is try to determine the application target SDK version and add the corresponding android.jar file to the CLASSPATH environment variable. This allows javacomplete to find Android packages, classes and methods and provide auto-completion via omnifunc (Ctrl-X Ctrl-O).

Also make sure you have your ctags files updated. You can use the provided AndroidUpdateProjecTags and AndroidUpdateAndroidTags commands to generate and update the project and android SDK tags.

# Recommended plugins

For a better experience I also recommend these plugins:

 - [neocomplcache](https://github.com/Shougo/neocomplcache) Simply the best auto-complete plugin for vim.
 - [vim-logcat](https://github.com/thinca/vim-logcat) Android's adb logcat output within vim and with syntax highlighting.
 - [tagbar](https://github.com/majutsushi/tagbar) Fast navigation via ctags of large code base.

# Resources

This plugin was written from scratch but I did use others as example so credit is due:

- [bpowell/vim-android](https://github.com/bpowell/vim-android)
- [mgarriott/vim-android](https://github.com/mgarriott/vim-android)
- [anddam/android-javacomplete](https://github.com/anddam/android-javacomplete)

