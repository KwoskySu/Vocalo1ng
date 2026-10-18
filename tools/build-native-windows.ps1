$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force 'E:/gpt-vocal/logs','E:/gpt-vocal/temp' | Out-Null
$env:PUB_CACHE = 'E:/gpt-vocal/pub-cache'
$env:TEMP = 'E:/gpt-vocal/temp'
$env:TMP = $env:TEMP
$vocaGit = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd'
$env:PATH = "$vocaGit;$env:PATH"
# PowerShell 5 wraps native stderr warnings as NativeCommandError. Let Flutter's
# exit code decide success so a NuGet discovery warning cannot abort the build.
$ErrorActionPreference = 'Continue'
& .tools/flutter/bin/flutter.bat build windows --release --no-pub *> 'E:/gpt-vocal/logs/windows-build.log'
$vocaBuildExit = $LASTEXITCODE
Set-Content -LiteralPath 'E:/gpt-vocal/logs/windows-build.exit' -Value $vocaBuildExit
exit $vocaBuildExit
