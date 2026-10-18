import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';

test('gateway rejects unauthenticated writes, foreign origins and arbitrary proxy URLs', async () => {
  const child = spawn(process.execPath, ['server/index.mjs'], {
    env: { ...process.env, VOCASHELF_PORT: '15418' }, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
  });
  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('gateway startup timeout')), 15000);
      child.once('exit', code => { clearTimeout(timeout); reject(new Error(`gateway exited: ${code}`)); });
      child.stdout.on('data', chunk => { if (String(chunk).includes('VocaShelf:')) { clearTimeout(timeout); resolve(); } });
    });
    const base = 'http://127.0.0.1:15418';
    const write = await fetch(`${base}/api/playlists`, { method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-VocaShelf': '1' }, body: '{"name":"test"}' });
    assert.equal(write.status, 401);
    const foreign = await fetch(`${base}/api/session`, { headers: { Origin: 'https://evil.example' } });
    assert.equal(foreign.status, 403);
    const proxy = await fetch(`${base}/api/image?url=http://127.0.0.1/private`);
    assert.equal(proxy.status, 502);
    const id = await fetch(`${base}/api/music/url?id=not-a-song`);
    assert.equal(id.status, 400);
    const csrf = await fetch(`${base}/api/login/qr`, { method: 'POST' });
    assert.equal(csrf.status, 403);
    assert.ok(write.headers.get('set-cookie').includes('HttpOnly'));
  } finally { child.kill(); }
});
