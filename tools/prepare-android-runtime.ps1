$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$runtimeRoot = 'E:/gpt-vocal/node-mobile'
$archive = 'E:/gpt-vocal/downloads/nodejs-mobile-v18.20.4-android.zip'
if (!(Test-Path -LiteralPath "$runtimeRoot/bin/arm64-v8a/libnode.so")) {
    New-Item -ItemType Directory -Force $runtimeRoot,(Split-Path $archive) | Out-Null
    Invoke-WebRequest 'https://github.com/nodejs-mobile/nodejs-mobile/releases/download/v18.20.4/nodejs-mobile-v18.20.4-android.zip' -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $runtimeRoot -Force
}
New-Item -ItemType Directory -Force android/app/src/main/assets | Out-Null
$dependencyRoot = 'E:/gpt-vocal/android-gateway-deps'
New-Item -ItemType Directory -Force $dependencyRoot | Out-Null
Copy-Item -LiteralPath package.json -Destination "$dependencyRoot/package.json" -Force
$pnpm = 'C:/Users/0/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/pnpm/bin/pnpm.cjs'
& node $pnpm install --dir $dependencyRoot --prod --ignore-scripts --node-linker=hoisted --store-dir E:/gpt-vocal/pnpm-store *> E:/gpt-vocal/logs/android-node-deps.log
if ($LASTEXITCODE -ne 0) { throw 'Android provider dependency install failed' }
# Package the same provider code on Android, without a PC, external executable,
# user accounts, Python, test fixtures, or platform caches.
@'
import pathlib, zipfile, hashlib
root = pathlib.Path.cwd()
target = root / 'android/app/src/main/assets/gateway.zip'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for folder, source in [('server', root / 'server'), ('node_modules', pathlib.Path('E:/gpt-vocal/android-gateway-deps/node_modules'))]:
        for p in source.rglob('*'):
            if not p.is_file() or any(s in ('.bin', '__pycache__', '.cache', '.git') for s in p.parts): continue
            if p.name.endswith(('.test.mjs', '.pyc', '.py', '.map')): continue
            name = folder + '/' + p.relative_to(source).as_posix()
            if name.endswith('/@neteasecloudmusicapienhanced/api/util/crypto.js'):
                text = p.read_text(encoding='utf-8')
                needle = "const decoder = new TextDecoder('utf-8', { fatal: true })"
                if needle not in text: raise RuntimeError('Provider UTF-8 compatibility patch requires review')
                # Preserve strict UTF-8 validation without ICU. Do not weaken it
                # to a replacement-character decoder (used in crypto detection).
                text = text.replace(needle, "const decoder = { decode(buf) { if (!require('node:buffer').isUtf8(buf)) throw new TypeError('Invalid UTF-8'); return Buffer.from(buf).toString('utf8') } }")
                z.writestr(name, text)
            else:
                z.write(p, name)
digest = hashlib.sha256(target.read_bytes()).hexdigest()
(target.parent / 'gateway.sha256').write_text(digest)
print(f'Android offline runtime payload: {target.stat().st_size} bytes; SHA256 {digest}')
'@ | & 'E:/gpt-vocal/releases/0.3.3/Windows/gateway/runtime/python/python.exe' -
if ($LASTEXITCODE -ne 0) { throw 'Runtime packaging failed' }
