import { randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, renameSync, existsSync, copyFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import {hasAccount} from './sessions.mjs';

const keep = session => ({ id: session.id, updated: session.updated,
  cookie: session.cookie ?? {}, uid: session.uid ?? null, profile: session.profile ?? null,
  bilibili: { cookies: session.bilibili?.cookies, profile: session.bilibili?.profile },
  qq: { credential: session.qq?.credential, profile: session.qq?.profile },
});
export class SessionVault {
  constructor(directory, { key } = {}) {
    this.directory = directory; mkdirSync(directory, { recursive: true, mode: 0o700 });
    this.file = path.join(directory, 'accounts.enc');
    if (key) { this.key = key; return; }
    const keyFile = path.join(directory, process.platform === 'win32' ? 'key.dpapi' : 'key.local');
    const dpapi = (bytes, decrypt) => Buffer.from(execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
      `Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); [Convert]::ToBase64String([Security.Cryptography.ProtectedData]::${decrypt ? 'Unprotect' : 'Protect'}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser))`],
      { input: bytes.toString('base64'), windowsHide: true, encoding: 'utf8' }).trim(), 'base64');
    if (existsSync(keyFile)) this.key = process.platform === 'win32' ? dpapi(readFileSync(keyFile), true) : readFileSync(keyFile);
    else {
      this.key = randomBytes(32);
      writeFileSync(keyFile, process.platform === 'win32' ? dpapi(this.key, false) : this.key, { mode: 0o600 });
    }
  }
  load() {
    if (!existsSync(this.file)) return new Map();
    const blob = readFileSync(this.file); const decipher = createDecipheriv('aes-256-gcm', this.key, blob.subarray(0, 12));
    decipher.setAuthTag(blob.subarray(12, 28));
    const data = JSON.parse(Buffer.concat([decipher.update(blob.subarray(28)), decipher.final()]).toString());
    return new Map(data.filter(s => /^[a-f0-9]{64}$/.test(s.id) && (hasAccount(s) || Date.now() - s.updated < 180 * 86400_000)).map(s => [s.id, s]));
  }
  save(sessions) {
    const data = [...sessions.values()].filter(hasAccount).map(keep);
    // Keep an encrypted recovery snapshot before account changes, including an
    // explicit logout. Recovery is manual, never silently reverses a logout.
    if (existsSync(this.file)) {
      const previous = this.load();
      if (previous.size && JSON.stringify([...previous.values()].map(keep)) !== JSON.stringify(data)) copyFileSync(this.file, path.join(this.directory, 'accounts.last-good.enc'));
    }
    const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(data)), cipher.final()]);
    writeFileSync(this.file + '.tmp', Buffer.concat([iv, cipher.getAuthTag(), encrypted]), { mode: 0o600 });
    renameSync(this.file + '.tmp', this.file);
  }
}
