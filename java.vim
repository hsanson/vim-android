if glob('AndroidManifest.xml') =~ ''
    if filereadable('project.properties') 
        let s:androidSdkPath = '/opt/android-sdk'
        " the following line uses external tools and is less portable
        "let s:androidTargetPlatform = system('grep target= project.properties | cut -d \= -f 2')
        vimgrep /target=/j project.properties
        let s:androidTargetPlatform = split(getqflist()[0].text, '=')[1] 
        let s:targetAndroidJar = s:androidSdkPath . '/platforms/' . s:androidTargetPlatform . '/android.jar'
        if $CLASSPATH =~ ''
            let $CLASSPATH = s:targetAndroidJar . ':' . $CLASSPATH
        else
            let $CLASSPATH = s:targetAndroidJar
        endif
    end
endif
