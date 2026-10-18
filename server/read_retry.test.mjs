import test from 'node:test';
import assert from 'node:assert/strict';
import {retryRead} from './read_retry.mjs';
import {wikiApi} from './wiki_transport.mjs';

test('transient reads retry with backoff; permission failures stop immediately',async()=>{
  let calls=0;const delays=[];
  assert.equal(await retryRead(async()=>{if(++calls<3)throw new Error('network');return 'ok';},{sleep:async ms=>delays.push(ms)}),'ok');
  assert.deepEqual(delays,[400,800]);
  calls=0;
  await assert.rejects(retryRead(async()=>{calls++;throw Object.assign(new Error('permission'),{retryable:false});},{sleep:async()=>{}}),/permission/);
  assert.equal(calls,1);
});

test('wiki coalesces concurrent reads, retries invalid responses and caches only success',async(t)=>{
  const original=globalThis.fetch;t.after(()=>globalThis.fetch=original);
  let calls=0;
  globalThis.fetch=async()=>++calls===1?new Response('<html>temporary error</html>'):Response.json({parse:{pageid:987653,title:'test',text:'<p>article</p>'}});
  const params=new URLSearchParams({action:'parse',pageid:'987653',format:'json'});
  const [a,b]=await Promise.all([wikiApi(params),wikiApi(params)]);
  assert.equal(a.parse.title,'test');assert.equal(a,b);assert.equal(calls,2);
  assert.equal((await wikiApi(params)).parse.pageid,987653);assert.equal(calls,2);
  await assert.rejects(wikiApi(new URLSearchParams({action:'edit',format:'json'})),/查询类型/);
});
