import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionVault } from './session_vault.mjs';
test('gateway restores all accounts across process restart and persists a provider logout', async () => {
  const directory=mkdtempSync(path.join(tmpdir(),'vocashelf-restart-'));
  const id='b'.repeat(64), base='http://127.0.0.1:15419';
  let child;
  const start=async()=> {
    child=spawn(process.execPath,['server/index.mjs'],{env:{...process.env,VOCASHELF_PORT:'15419',VOCASHELF_SESSION_DIR:directory},stdio:['ignore','pipe','pipe'],windowsHide:true});
    await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('startup timeout')),15000); child.once('exit',()=>{clearTimeout(timer);reject(new Error('gateway exited'));});child.stdout.on('data',b=>{if(String(b).includes('VocaShelf:')){clearTimeout(timer);resolve();}});});
  };
  const stop=async()=>{const closed=once(child,'exit');child.kill();await closed;};
  try {
    const vault=new SessionVault(directory);
    vault.save(new Map([[id,{id,updated:Date.now(),cookie:{MUSIC_U:'test-only'},profile:{uid:'1'},uid:1,bilibili:{cookies:{SESSDATA:'test-only'},profile:{uid:'2'}},qq:{credential:{musickey:'test-only'},profile:{uid:'3'}}}]]));
    await start();
    const headers={Cookie:`vs_sid=${id}`,'X-VocaShelf':'1'};
    const first=await fetch(base+'/api/session',{headers});const accounts=await first.json();assert.equal(accounts.profile.uid,'1');assert.equal(accounts.bilibili.uid,'2');assert.equal(accounts.qq.uid,'3');assert.match(first.headers.get('set-cookie'),/Max-Age=15552000/);
    const logout=await fetch(base+'/api/qq/logout',{method:'POST',headers});assert.equal(logout.status,200);
    await stop();await start();
    const restored=await(await fetch(base+'/api/session',{headers})).json();assert.equal(restored.qq,null);assert.equal(restored.profile.uid,'1');assert.equal(restored.bilibili.uid,'2');
  } finally {if(child?.exitCode===null) await stop();rmSync(directory,{recursive:true,force:true});}
});
