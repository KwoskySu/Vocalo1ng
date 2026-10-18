import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { SessionVault } from './session_vault.mjs';
import { roamBatch } from './roam.mjs';
test('encrypted accounts survive a new vault and logout removes only the selected provider', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'vocashelf-vault-'));
  try {
    const key = randomBytes(32), vault = new SessionVault(directory, {key});
    const id = 'a'.repeat(64);
    const sessions = new Map([[id, {id, updated: Date.now(), profile: {uid:'1'}, cookie:{MUSIC_U:'secret-music'}, key:'pending-qr', bilibili:{profile:{uid:'2'}, cookies:{SESSDATA:'secret-bili'}}, qq:{profile:{uid:'3'},credential:{musickey:'secret-qq'}}}]]);
    vault.save(sessions);
    const data = readFileSync(path.join(directory,'accounts.enc'));
    assert.equal(data.includes(Buffer.from('secret-')), false);
    const restored = new SessionVault(directory,{key}).load();
    assert.equal(restored.get(id).cookie.MUSIC_U, 'secret-music');
    assert.equal(restored.get(id).qq.credential.musickey, 'secret-qq');
    assert.equal(restored.get(id).key, undefined);
    restored.get(id).bilibili = {}; vault.save(restored);
    const again = vault.load().get(id);
    assert.equal(again.bilibili.profile, undefined); assert.equal(again.profile.uid,'1'); assert.equal(again.qq.profile.uid,'3');
    assert.throws(() => new SessionVault(directory,{key:randomBytes(32)}).load());
  } finally { rmSync(directory,{recursive:true,force:true}); }
});
test('roaming returns 24 unique songs and avoids the previous batch when the pool permits', () => {
  const pool = Array.from({length:90},(_,i)=>({id:String(i),title:`song ${i}`}));
  const first = roamBatch([...pool, pool[0]]);
  const second = roamBatch(pool, first.map(s=>s.id));
  assert.equal(first.length,24); assert.equal(new Set(first.map(s=>s.id)).size,24);
  assert.equal(second.filter(s=>first.some(a=>a.id===s.id)).length,0);
  assert.equal(roamBatch(pool.slice(0,20),pool.map(s=>s.id)).length,20);
});
