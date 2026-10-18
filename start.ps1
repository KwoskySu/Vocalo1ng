param([switch]$Rebuild, [switch]$Lan, [switch]$NoBrowser, [int]$Port = 5418)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Port must be between 1024 and 65535.' }
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodeRuntime = if ($nodeCommand) { $nodeCommand.Source } else {
    Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
}
if (-not (Test-Path -LiteralPath $nodeRuntime)) { throw 'Install Node.js 22 or newer first.' }
if (-not (Test-Path -LiteralPath 'node_modules/@neteasecloudmusicapienhanced/api')) {
    $pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
    $pnpmRuntime = if ($pnpmCommand) { $pnpmCommand.Source } else {
        Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\bin\fallback\pnpm.cmd'
    }
    if (-not (Test-Path -LiteralPath $pnpmRuntime)) { throw 'Install pnpm, then run pnpm install --ignore-scripts.' }
    & $pnpmRuntime install --frozen-lockfile --ignore-scripts
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
}
if ($Rebuild -or -not (Test-Path -LiteralPath 'build/web/index.html')) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutterRuntime = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $PSScriptRoot '.tools/flutter/bin/flutter.bat' }
    if (-not (Test-Path -LiteralPath $flutterRuntime)) { throw 'Install Flutter stable and run flutter pub get first.' }
    & $flutterRuntime build web --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
}
$previewUrl = "http://127.0.0.1:$Port"
try { $running = Invoke-RestMethod "$previewUrl/api/health" -TimeoutSec 2 } catch { $running = $null }
if ($running.ok -and $running.provider -eq 'personal') {
    if ($Lan -and -not $running.lan) { throw "The existing service only listens locally. Stop it first, or use -Lan -Port 5419." }
    Write-Host "Vocalo1ng-better player is already running: $previewUrl"
    if (-not $NoBrowser) { Start-Process $previewUrl }
    return
}
$env:VOCASHELF_PORT = "$Port"
$env:VOCASHELF_HOST = if ($Lan) { '0.0.0.0' } else { '127.0.0.1' }
if ($Lan) { Write-Host "LAN preview: on your phone open http://YOUR-PC-LAN-IP:$Port" }
Write-Host "Vocalo1ng-better player: $previewUrl | Keep this terminal open. Ctrl+C stops the service."
# This launcher is explicitly used to view the app, so the browser is intentionally visible.
if (-not $NoBrowser) { Start-Process $previewUrl }
& $nodeRuntime server/index.mjs
