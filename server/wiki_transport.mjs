import {spawn} from 'node:child_process';
import {retryRead} from './read_retry.mjs';
const pending = new Map(), cache = new Map();
let bytes = 0;
let active = 0;
const waiting = [];
// Standard Windows HTTP transport for public wiki image files. No credentials,
// challenge handling, redirects, certificate overrides or user-supplied code.
export function windowsWikiImage(target) {
  const url = new URL(target);
  if (process.env.VOCALO1NG_ANDROID === '1' && url.protocol === 'https:' && url.hostname === 'voca.wiki' &&
      !url.username && !url.password && (!url.port || url.port === '443') && url.pathname.startsWith('/images/')) {
    const key = url.href;
    if(cache.has(key))return Promise.resolve(cache.get(key));
    if(pending.has(key))return pending.get(key);
    const task = androidWikiImage(url).then(value=> {
      if(!value)return null;
      while(cache.size && (cache.size>=64 || bytes+value.body.length>48000000)) {
        const first=cache.keys().next().value;bytes-=cache.get(first).body.length;cache.delete(first);
      }
      cache.set(key,value);bytes+=value.body.length;return value;
    }).finally(()=>pending.delete(key));
    pending.set(key,task);return task;
  }
  if (process.platform !== 'win32' || url.protocol !== 'https:' ||
      url.hostname !== 'voca.wiki' || url.username || url.password ||
      (url.port && url.port !== '443') || !url.pathname.startsWith('/images/')) return Promise.resolve(null);
  const key = url.href;
  if (cache.has(key)) return Promise.resolve(cache.get(key));
  if (pending.has(key)) return pending.get(key);
  const task = (async()=> {
    if(active>=3) await new Promise(resolve=>waiting.push(resolve));
    active++;
    try { return await new Promise(resolve => {
    const script = `$ErrorActionPreference='Stop';Add-Type -AssemblyName System.Net.Http;$u=[uri][Console]::In.ReadToEnd();if($u.Scheme-ne'https'-or$u.Host-ne'voca.wiki'-or-not$u.AbsolutePath.StartsWith('/images/')){exit 1};$h=New-Object System.Net.Http.HttpClientHandler;$h.AllowAutoRedirect=$false;$c=New-Object System.Net.Http.HttpClient($h);$c.Timeout=[TimeSpan]::FromSeconds(15);try{$r=$c.GetAsync($u).GetAwaiter().GetResult();if(-not$r.IsSuccessStatusCode){exit 1};$t=$r.Content.Headers.ContentType.MediaType;if(-not$t.StartsWith('image/')){exit 1};$b=$r.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();if($b.Length-gt8388608){exit 1};[Console]::Out.Write($t+[char]10+[Convert]::ToBase64String($b))}finally{$c.Dispose()}`;
    const child = spawn('powershell.exe', ['-NoProfile','-NonInteractive','-Command',script], {windowsHide:true,stdio:['pipe','pipe','ignore']});
    let output = '', finished = false;
    const finish = value => { if (!finished) {finished=true;clearTimeout(timer);resolve(value);} };
    const timer = setTimeout(() => {child.kill();finish(null);},18000);
    child.on('error',()=>finish(null));child.stdin.on('error',()=>{});
    child.stdout.on('data',part=>{output+=part;if(output.length>12000000){child.kill();finish(null);}});
    child.on('close',code=>{
      if(code!==0)return finish(null);
      const split=output.indexOf('\n'),type=output.slice(0,split).trim();
      if(split<0||!/^image\/[a-z0-9.+-]+$/i.test(type))return finish(null);
      const body=Buffer.from(output.slice(split+1),'base64');
      if(!body.length||body.length>8388608)return finish(null);
      while(cache.size && (bytes+body.length>48000000||cache.size>=64)) {
        const first=cache.keys().next().value;bytes-=cache.get(first).body.length;cache.delete(first);
      }
      const value={body,type};cache.set(key,value);bytes+=body.length;finish(value);
    });
    child.stdin.end(key);
    }); } finally {active--;waiting.shift()?.();}
  })().finally(()=>pending.delete(key));
  pending.set(key,task);return task;
}

async function androidWikiImage(url, json = false) {
  const port = Number(process.env.VOCALO1NG_NATIVE_IMAGES_PORT);
  if (!Number.isInteger(port) || port < 1024 || port > 65535 || !process.env.VOCALO1NG_NATIVE_IMAGES_TOKEN) return null;
  const response = await fetch(`http://127.0.0.1:${port}/image?url=${encodeURIComponent(url.href)}`, {
    headers: {Authorization:`Bearer ${process.env.VOCALO1NG_NATIVE_IMAGES_TOKEN}`}, signal:AbortSignal.timeout(json ? 9000 : 20000), redirect:'error',
  });
  const type = response.headers.get('content-type')?.split(';')[0] || '';
  if (!response.ok || !(json ? type === 'application/json' : /^image\/[a-z0-9.+-]+$/i.test(type))) { await response.body?.cancel(); return null; }
  const body = Buffer.from(await response.arrayBuffer());
  return body.length && body.length <= 8388608 ? {body,type} : null;
}

const apiPending = new Map(), apiCache = new Map();
let apiBytes=0;
export async function wikiApi(params) {
  const allowed = new Set(['action','list','rnnamespace','rnlimit','format','formatversion','origin','pageid','page','prop','disableeditsection','disabletoc','maxlag','srsearch','srnamespace','srprop','srlimit']);
  for (const [key,value] of params) if (!allowed.has(key) || value.length > 300) throw new Error('百科查询参数无效');
  if (!['query','parse'].includes(params.get('action')) || params.get('format') !== 'json') throw new Error('百科查询类型无效');
  if (params.get('action') === 'query' && !['search','random'].includes(params.get('list'))) throw new Error('百科查询列表无效');
  const target = new URL('https://voca.wiki/api.php'); target.search = params.toString();
  const key = target.href, cached = apiCache.get(key);
  if (cached?.expires > Date.now()) return cached.value;
  if (apiPending.has(key)) return apiPending.get(key);
  const task = retryRead(async () => {
  let value;
  if (process.env.VOCALO1NG_ANDROID === '1') {
    const native = await androidWikiImage(target, true).catch(()=>null);
    if (native) value = JSON.parse(native.body.toString('utf8'));
  }
  if (!value) {
  const response = await fetch(target, {headers:{'User-Agent':'Vocalo1ng/0.4.3 (personal music reader)',Accept:'application/json'},signal:AbortSignal.timeout(8000),redirect:'error'});
  if (!response.ok) throw new Error(`百科暂不可用（HTTP ${response.status}），请刷新重试`);
  value = await response.json();
  }
  if (value.error) {
    const error = new Error(value.error.info || '百科暂时繁忙');
    error.retryable = ['maxlag', 'ratelimited', 'readonly'].includes(value.error.code);
    throw error;
  }
  if (!value.query && !value.parse) throw new Error('百科响应不完整');
  if (params.get('list') !== 'random') {
    const size=Buffer.byteLength(JSON.stringify(value));
    if(size<=8000000){
      while(apiCache.size && (apiCache.size>=24 || apiBytes+size>12000000)){
        const first=apiCache.keys().next().value;apiBytes-=apiCache.get(first).size;apiCache.delete(first);
      }
      apiBytes-=apiCache.get(key)?.size||0;apiBytes+=size;
      apiCache.set(key, {value,size,expires:Date.now() + (value.parse ? 300000 : 60000)});
    }
  }
  return value;
  }, {attempts: 2}).finally(()=>apiPending.delete(key));
  apiPending.set(key,task);
  return task;
}
