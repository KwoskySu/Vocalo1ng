$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path -LiteralPath '.tools/qq-runtime/Scripts/python.exe')) { python -m venv .tools/qq-runtime }
& .tools/qq-runtime/Scripts/python.exe -m pip install -r server/requirements-qq.lock.txt
if ($LASTEXITCODE -ne 0) { throw 'QQ Music dependency installation failed.' }
Write-Host 'QQ Music runtime is ready.'

