param([switch]$Install)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$flutter=Join-Path $root '.tools/flutter/bin/flutter.bat'
$env:PUB_CACHE=Join-Path $root '.tools/pub-cache'
Set-Location (Join-Path $root 'app')
& $flutter pub get
if($LASTEXITCODE -ne 0){throw 'Dependency resolution failed.'}
& $flutter build apk --release --target-platform android-arm64
if($LASTEXITCODE -ne 0){throw 'Android build failed.'}
$apk=Join-Path $root 'deliverables/Dishcovery-Android.apk'
Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $apk -Force
Write-Host "Android APK: $apk"
if($Install){
 $sdkLine=Get-Content android/local.properties | Where-Object {$_ -like 'sdk.dir=*'}
 $sdk=($sdkLine -replace '^sdk.dir=','') -replace '\\\\','\'
 $adb=Join-Path $sdk 'platform-tools/adb.exe'
 & $adb install -r $apk
 if($LASTEXITCODE -ne 0){throw 'Connect an Android device with USB debugging enabled.'}
 & $adb shell am start -n com.dishcovery.dishcovery/.MainActivity
}
