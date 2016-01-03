" Vim XML data file
" Last Change: 2016-01-02

let g:xmldata_manifest = {
\ 'vimxmlentities': ['lt', 'gt', 'amp', 'apos', 'quot'],
\ 'vimxmlroot': ['manifest'],
\ 'supports-screens': [
\ [],
\ {'android:compatibleWidthLimitDp': [], 'android:largeScreens': [], 'android:requiresSmallestWidthDp': []}
\ ],
\ 'uses-library': [
\ [],
\ {'android:name': [], 'android:required': []}
\ ],
\ 'uses-permission': [
\ [],
\ {'android:name': []}
\ ],
\ 'service': [
\ ['intent-filter', 'meta-data'],
\ {'android:allowEmbedded': [], 'android:enabled': [], 'android:exported': [], 'android:isolatedProcess': [], 'android:label': [], 'android:name': [], 'android:permission': [], 'android:process': [], 'android:stopWithTask': [], 'android:taskAffinity': []}
\ ],
\ 'grant-uri-permission': [
\ [],
\ {'android:pathPattern': []}
\ ],
\ 'permission': [
\ [],
\ {'android:name': []}
\ ],
\ 'instrumentation': [
\ [],
\ {'android:label': [], 'android:name': [], 'android:targetPackage': []}
\ ],
\ 'category': [
\ [],
\ {'android:name': []}
\ ],
\ 'activity-alias': [
\ ['intent-filter'],
\ {'android:label': [], 'android:name': [], 'android:targetActivity': []}
\ ],
\ 'uses-feature': [
\ [],
\ {'android:glEsVersion': [], 'android:name': [], 'android:required': []}
\ ],
\ 'manifest': [
\ ['application', 'instrumentation', 'meta-data', 'permission', 'supports-screens', 'uses-feature', 'uses-permission', 'uses-permission-sdk-m', 'uses-sdk'],
\ {'android:uiOptions': [], 'android:versionCode': [], 'android:versionName': [], 'package': []}
\ ],
\ 'intent-filter': [
\ ['action', 'category', 'data'],
\ {'android:label': []}
\ ],
\ 'application': [
\ ['activity', 'activity-alias', 'meta-data', 'provider', 'receiver', 'service', 'uses-library'],
\ {'android:allowBackup': [], 'android:backupAgent': [], 'android:debuggable': [], 'android:description': [], 'android:fullBackupContent': [], 'android:hardwareAccelerated': [], 'android:icon': [], 'android:label': [], 'android:logo': [], 'android:name': [], 'android:persistent': [], 'android:supportsRtl': [], 'android:theme': []}
\ ],
\ 'meta-data': [
\ [],
\ {'android:name': [], 'android:resource': [], 'android:value': []}
\ ],
\ 'provider': [
\ ['grant-uri-permission', 'intent-filter'],
\ {'android:authorities': [], 'android:enabled': [], 'android:exported': [], 'android:grantUriPermissions': [], 'android:name': [], 'android:permission': []}
\ ],
\ 'data': [
\ [],
\ {'android:host': [], 'android:mimeType': [], 'android:scheme': [], 'android:ssp': []}
\ ],
\ 'receiver': [
\ ['intent-filter', 'meta-data'],
\ {'android:description': [], 'android:enabled': [], 'android:exported': [], 'android:label': [], 'android:name': [], 'android:permission': [], 'android:process': []}
\ ],
\ 'uses-sdk': [
\ [],
\ {'android:minSdkVersion': [], 'android:targetSdkVersion': [], 'minSdkVersion': []}
\ ],
\ 'action': [
\ [],
\ {'android:name': []}
\ ],
\ 'uses-permission-sdk-m': [
\ [],
\ {'android:name': []}
\ ],
\ 'activity': [
\ ['intent-filter', 'meta-data'],
\ {'android:allowEmbedded': [], 'android:configChanges': [], 'android:enabled': [], 'android:excludeFromRecents': [], 'android:exported': [], 'android:hardwareAccelerated': [], 'android:icon': [], 'android:label': [], 'android:launchMode': [], 'android:logo': [], 'android:name': [], 'android:noHistory': [], 'android:parentActivityName': [], 'android:persistableMode': [], 'android:relinquishTaskIdentity': [], 'android:screenOrientation': [], 'android:stateNotNeeded': [], 'android:taskAffinity': [], 'android:theme': [], 'android:uiOptions': [], 'android:windowSoftInputMode': []}
\ ],
\ }
