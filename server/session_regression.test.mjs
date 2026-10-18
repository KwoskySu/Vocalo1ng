import test from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {mkdtempSync,rmSync,existsSync} from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {resolveSession} from './sessions.mjs';
import {SessionVault} from './session_vault.mjs';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
test('thousands of anonymous requests cannot evict a saved account',()=>{
  const id='a'.repeat(64), account={id,updated:1,cookie:{MUSIC_U:'test-only'},profile:{uid:'test'},bilibili:{},qq:{}};
  const sessions=new Map([[id,account]]);
  for(let i=0;i<1200;i++)resolveSession(sessions,null,{now:1000+i});
  assert.equal(sessions.get(id),account);assert.equal(sessions.size,101);
  assert.equal(resolveSession(sessions,id,{now:Date.now()}).profile.uid,'test');
});
test('image traffic has no session cookie and login survives anonymous traffic and gateway restart',async()=>{
  const directory=mkdtempSync(path.join(tmpdir(),'voca-image-session-'));
  const id='c'.repeat(64),base='http://127.0.0.1:15423'; let child;
  const start=async()=>{
    child=spawn(process.execPath,['server/index.mjs'],{env:{...process.env,VOCASHELF_PORT:'15423',VOCASHELF_SESSION_DIR:directory},windowsHide:true,stdio:['ignore','pipe','pipe']});
    await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('startup timeout')),15000);child.once('exit',()=>{clearTimeout(timer);reject(new Error('gateway exited'));});child.stdout.on('data',b=>{if(String(b).includes('Vocalo1ng:')){clearTimeout(timer);resolve();}});});
  };
  const stop=async()=>{const closed=once(child,'exit');child.kill();await closed;};
  try {
    new SessionVault(directory).save(new Map([[id,{id,updated:Date.now(),cookie:{MUSIC_U:'test-only'},profile:{uid:'test-account'},uid:'test-account',bilibili:{},qq:{}}]]));
    await start();
    for(let batch=0;batch<12;batch++)await Promise.all(Array.from({length:20},async()=>{
      const image=await fetch(base+'/api/image?url=https://untrusted.invalid/image.jpg');
      assert.equal(image.status,400);assert.equal(image.headers.get('set-cookie'),null);await image.text();
      const anonymous=await fetch(base+'/api/session');await anonymous.text();
    }));
    const headers={'X-VocaShelf-Session':id,'X-VocaShelf':'1'};
    const current=await(await fetch(base+'/api/session',{headers})).json();assert.equal(current.profile.uid,'test-account');
    const logout=await fetch(base+'/api/qq/logout',{method:'POST',headers});assert.equal(logout.status,200);await logout.text();
    await stop();await start();
    const restored=await(await fetch(base+'/api/session',{headers})).json();assert.equal(restored.profile.uid,'test-account');
  }finally{if(child?.exitCode===null)await stop();rmSync(directory,{recursive:true,force:true});}
});
test('credentials survive missing profile metadata and encrypted backup precedes explicit logout',()=>{
  const directory=mkdtempSync(path.join(tmpdir(),'voca-safe-session-'));const key=randomBytes(32);
  try {
    const v=new SessionVault(directory,{key}),id='b'.repeat(64);
    v.save(new Map([[id,{id,updated:1,cookie:{MUSIC_U:'test-only'},bilibili:{},qq:{}}]]));
    assert.equal(v.load().get(id).cookie.MUSIC_U,'test-only');
    v.save(new Map());assert.equal(v.load().size,0);
    assert.equal(existsSync(path.join(directory,'accounts.last-good.enc')),true);
  }finally{rmSync(directory,{recursive:true,force:true});}
});
