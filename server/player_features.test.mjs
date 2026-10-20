import test from 'node:test';
import assert from 'node:assert/strict';
import {deflateRawSync,gzipSync} from 'node:zlib';
import {parseDanmaku, community} from './community.mjs';
import {songQualities} from './qualities.mjs';
import {LiveStore} from './live.mjs';

test('compressed danmaku parses and HTML restriction pages are errors, not empty success',()=>{
  const xml=Buffer.from('<i><d p="1.5,1,25,16777215">你好 &amp; &#x39;</d></i>');
  for(const bytes of [xml,deflateRawSync(xml),gzipSync(xml)]) assert.equal(parseDanmaku(bytes)[0].text,'你好 & 9');
  assert.throws(()=>parseDanmaku(Buffer.from('<html>Access denied</html>')),/限制/);
});
test('danmaku uses the supplied account and comments retain a clearly limited legacy preview',async()=>{
  const calls=[];
  const session={bilibili:{cookies:{SESSDATA:'test-only'}}};
  const fetcher=async(url,opts)=>{
    calls.push({url:String(url),opts});
    if(String(url).includes('/view?'))return Response.json({code:0,data:{aid:1,cid:2}});
    if(String(url).includes('list.so'))return new Response('<i><d p="1,1,25,1">弹幕</d></i>');
    if(String(url).includes('/nav'))return Response.json({code:-352,message:'restricted'});
    return Response.json({code:0,data:{cursor:{all_count:1},replies:[{rpid:3,member:{uname:'a'},content:{message:'comment'},like:5}]}});
  };
  const dm=await community('/api/pv/danmaku',new URL('http://localhost?bvid=BV1s54y1Z7Bi'),session,{fetcher});
  assert.equal(dm.items.length,1);assert.match(calls[1].opts.headers.Cookie,/SESSDATA=test-only/);
  const c=await community('/api/pv/comments',new URL('http://localhost?bvid=BV1s54y1Z7Bi'),session,{fetcher});
  assert.equal(c.comments[0].text,'comment');assert.equal(c.more,false);
});
test('login does not falsely unlock downgraded or unavailable music quality',async()=>{
  const call=async()=>({body:{data:[{url:'https://m.music.126.net/a.mp3',type:'mp3',br:128000}]}});
  const data=await songQualities('123',{profile:{},uid:'1'},{call});
  assert.deepEqual(data.qualities.map(q=>q.locked),[false,true,true]);
  const anonymous=await songQualities('123',{}, {call});assert.equal(anonymous.qualities[1].locked,true);
});
test('live publication scopes owners, validates fields, expires and stops without exposing session',()=>{
  let now=0; const store=new LiveStore(()=>now);
  const a=store.publish('private-session',{title:'test',cover:'file:///secret',mode:900,color:'bad',size:999});
  assert.equal(store.read(a.token).cover,'');assert.equal(store.read(a.token).size,64);
  assert.ok(!JSON.stringify(store.read(a.token)).includes('private-session'));
  store.publish('private-session',{font:'serif',coverSize:220,coverShape:4,backgroundStyle:5,textEffect:3,translationScale:.7,titleScale:.8,coverVisible:false});
  const styled=store.read(a.token);
  assert.equal(styled.font,'serif');assert.equal(styled.coverSize,220);assert.equal(styled.coverVisible,false);
  assert.equal(styled.coverShape,4);assert.equal(styled.backgroundStyle,5);assert.equal(styled.textEffect,3);
  assert.equal(styled.translationScale,.7);assert.equal(styled.titleScale,.8);
  store.publish('private-session',{font:'url(secret)',coverSize:9999,coverShape:-1,backgroundStyle:99,textEffect:99});
  const bounded=store.read(a.token);
  assert.equal(bounded.font,'sans-serif');assert.equal(bounded.coverSize,260);
  assert.equal(bounded.coverShape,0);assert.equal(bounded.backgroundStyle,5);assert.equal(bounded.textEffect,4);
  const b=store.publish('other',{});store.stop('private-session');assert.equal(store.read(a.token).offline,true);assert.equal(store.read(b.token).offline,undefined);
  now=16000;assert.equal(store.read(b.token).offline,true);
});
