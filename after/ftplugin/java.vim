if !exists('g:android_sdk_path')
  let g:android_sdk_path = '/opt/android-sdk'
endif

if glob('AndroidManifest.xml') =~ ''
    if filereadable('project.properties') 
        for line in readfile('project.properties')
          if line =~ 'target='
            let s:androidTargetPlatform = split(line, '=')[1]
            let s:targetAndroidJar = g:android_sdk_path . '/platforms/' . s:androidTargetPlatform . '/android.jar'
            if $CLASSPATH =~ ''
              let $CLASSPATH = s:targetAndroidJar . ':' . $CLASSPATH
            else
              let $CLASSPATH = s:targetAndroidJar
            endif
            break
          endif
        endfor
    end
endif
