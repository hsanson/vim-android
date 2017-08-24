This document describes some of the complicated parts of the plugin in hopes that contributors have an easier time when dealing with them.

# Gradle Sync

When a java, xml or kt file is open in vim this plugin automatically executes the __gradle#syncCmd()__ on the gradle project. This command under the hood executes the
following command:

    ./gradlew -I init.gradle -b build.gradle vim

The __init.gradle__ file contains gradle hooks and tasks specific for this plugin to work. The vim task defined in the init.gradle file inspects the whole project and
outputs to stdout the project name, target SDK versions, plugin versions and all dependencies. This information is then parsed by the plugin and loaded in a cache.
You can execute the command inside your gradle or android project to see the kind of information it extracts.

If in the future it is needed to get additional information from the gradle project this file must be modified to ouput it and the plugin modified to read and store it.
Refer to the autoload/gradle.vim file for details on how this is implemented.

# Errorformat

Supporting the plethora of errors that gradle can output in vim's quickfix window has been the most complex part of writing this plugin. Depending on the tool or
compiler used the errors are handled differently.

## External Error Files

Some tools like android's linter, PMD, findbugs, and checkstyle like to output their reports to external files in XML format. To handle these cases we have some hooks
added in the init.gradle file that can find those reports, parse them, and output to stdout a simplified ASCII version of the errors. To see the ascii output generated
by the hooks you can execute:

   ./gradlew -I init.gradle -b build.gradle lint

To add error output to vim for any other tool that generates reports in external files, it is necessary to create a new hook in the init.gradle file that can find that
report, parse it and output to stdout a simpler (one-line) string with the error message.

## Non Errorformat Friendly

Some other tools like to generate error messages that are not easy to describe using vim's errorformat syntax. In this cases we have a __efmsanity__ filter that uses
__sed__ to modify the output of gradle and try to accommodate the difficult messages to a format that is easier to match using errorformat syntax. Refer to that tool
if some new tool is generating such messages.

## Gradle Errorformat

The ultimate errorformat for gradle/android development can be found inside the __autoload/efm.vim__. It is able to match and display errors for java, kotlin, pmd,
checkstyle, lint, aapt, manifest, among others.

## Errorformat Testing

A simple change to the errorformat can easily break it for any of the currently supported tools. To ensure changes to it do not break other tools we have extensive
testing suite using [vim-vader](https://github.com/junegunn/vader.vim).

To run the tests simply execute the following while inside the plugin directory:

    vim +'Vader test/*'

If you make modifications to the errorformat like adding new errors or improving current ones you must ensure the tests pass before submitting any PR.

To generate new errorformat test files you can use the following command that is the same exact command used by the plugin to build the projects:

    LANG=en ./gradlew -I /path/to/init.gradle -b build.gradle [task] 2>&1 | /path/to/efmsanity | tee out.efm

Notes:
 - You can use the gradlew wrapper or your locally installed gradle.
 - Use LANG=en to ensure error messages are not localized. That would break the errorformat.
 - Use the absolute path to the location of both the init.gradle and efmsanity files. These are part of this plugin.
 - Replace [task] with the gradle task that generates the errors you want to add.


