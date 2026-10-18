import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('./player.js',import.meta.url),'utf8');
const requestFunction=source.slice(source.indexOf('async function readJson('),source.indexOf('let recoveryCount='));

test('quality menu supports WebViews without Element.replaceChildren',()=>{
  const context=vm.createContext({});
  vm.runInContext(source.slice(source.indexOf('function replaceNodes('),source.indexOf('async function readJson(')),context);
  const children=['loading'];
  const parent={get firstChild(){return children[0];},removeChild:()=>children.shift(),appendChild:child=>children.push(child)};
  context.replaceNodes(parent,['360P','480P']);
  assert.deepEqual(children,['360P','480P']);
});

test('player requests work on old WebView without AbortSignal.timeout',async()=>{
  let calls=0;
  const context=vm.createContext({AbortController,AbortSignal:{},setTimeout,clearTimeout,
    fetch:async()=>{calls++;return {ok:true,json:async()=>({quality:32})};},
  });
  vm.runInContext(requestFunction,context);
  assert.equal((await context.readJson('/api/pv/playback')).quality,32);
  assert.equal(calls,1);
});

test('old WebView can recover a temporary network failure without the modern timeout API',async()=>{
  let calls=0;
  const context=vm.createContext({AbortController,AbortSignal:{},setTimeout,clearTimeout,
    fetch:async()=>{if(++calls===1)throw new Error('network');return {ok:true,json:async()=>({items:[1]})};},
  });
  vm.runInContext(requestFunction,context);
  assert.equal((await context.readJson('/api/pv/danmaku')).items.length,1);
  assert.equal(calls,2);
});
