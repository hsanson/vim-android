= What is this? =

This is a plugin that loads Android API in javacomplete plugin allowing you to complete classes from Android SDK.


= Install =

Copy java.vim to ~/.vim/after/ftplugin/ this will load the script whenever 'java' filetype is set.
Edit s:androidSdkPath in java.vim accordingly to yout Android SDK path.


= Usage =

Start vim in an Android project -I use NERDTree so I'm starting at a project's root-. Done.

The script will recognize this is an Android project by checking AndroidManifest.xml and will get the target from project.properties, then it will prepend the jar path to CLASSPATH.


= License =

As usual.
