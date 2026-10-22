param([switch]$SplitPerAbi)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$env:PUB_CACHE = 'E:/gpt-vocal/pub-cache'
$env:ANDROID_HOME = 'E:/gpt-vocal/android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_USER_HOME = 'E:/gpt-vocal/gradle'
$env:ANDROID_USER_HOME = 'E:/gpt-vocal/android-user'
$env:JAVA_HOME = 'C:/Program Files/Java/jdk-24'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
# Use Windows' existing trusted roots; keep HTTPS certificate verification enabled.
$env:JAVA_TOOL_OPTIONS = '-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE'
$env:TEMP = 'E:/gpt-vocal/temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force $env:TEMP,$env:ANDROID_USER_HOME,'E:/gpt-vocal/logs','E:/gpt-vocal/releases/0.4.18/Android' | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare-android-runtime.ps1
if ($LASTEXITCODE -ne 0) { throw 'Android runtime preparation failed' }
# Native Java startup notices on stderr must not make PowerShell 5 abort Flutter.
$ErrorActionPreference = 'Continue'
$buildArgs = @('build','apk','--release','--no-pub')
if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }
& .tools/flutter/bin/flutter.bat @buildArgs *> 'E:/gpt-vocal/logs/android-build.log'
$vocaBuildExit = $LASTEXITCODE
if ($vocaBuildExit -eq 0) {
    $ErrorActionPreference = 'Stop'
    if ($SplitPerAbi) {
        foreach ($abi in @('arm64-v8a','armeabi-v7a','x86_64')) {
            Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$abi-release.apk" -Destination "E:/gpt-vocal/releases/0.4.18/Android/Vocalo1ng-0.4.18-$abi.apk" -Force
        }
    } else {
        Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-release.apk -Destination 'E:/gpt-vocal/releases/0.4.18/Android/Vocalo1ng-0.4.18.apk' -Force
    }
}
Set-Content -LiteralPath 'E:/gpt-vocal/logs/android-build.exit' -Value $vocaBuildExit
exit $vocaBuildExit
