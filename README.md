# What is this?

This is a plugin that adds Android SDK jar to CLASSPATH when using [javacomplete](http://www.vim.org/scripts/script.php?script_id#1785) plugin allowing you to complete classes from Android SDK.


# Install

Copy java.vim to ~/.vim/after/ftplugin/ this will load the script whenever 'java' filetype is set.

Edit s:androidSdkPath in java.vim accordingly to your Android SDK path.


# Usage

Cd to an Android project, start vim and you're done. I use NERDTree so I'm usually strating vim at a project's root as habit.

The script will recognize this is an Android project by checking AndroidManifest.xml and will get the target from project.properties, then it will prepend the jar path to CLASSPATH and the [Android API](http://developer.android.com/reference/android/widget/package-summary.html) will be available to omnifunc completion.


# License

As usual (will fill in when I'll manage to understand license-world).



Enjoy
