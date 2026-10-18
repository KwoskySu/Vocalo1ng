import test from 'node:test';
import assert from 'node:assert/strict';
import {community, parseDanmaku} from './community.mjs';
import {parseDanmakuSegment, readDanmaku} from './danmaku.mjs';

const varint = n => { const b=[];do {const v=n%128;n=Math.floor(n/128);b.push(v|(n?128:0));}while(n);return Buffer.from(b); };
const num = (key,n)=>Buffer.concat([varint(key*8),varint(n)]);
const blob = (key,b)=>Buffer.concat([varint(key*8+2),varint(b.length),b]);
const segment = blob(1,Buffer.concat([num(1,999),num(2,12500),num(3,1),num(5,0xabcdef),blob(7,Buffer.from('测试弹幕')),blob(13,Buffer.from('unknown'))]));

test('comments use signed cursor paging and preserve the returned continuation',async()=>{
  const seen=[];
  const fetcher=async raw=>{
    const url=new URL(raw);seen.push(url);
    if(url.pathname.endsWith('/view'))return Response.json({code:0,data:{aid:1,cid:2}});
    if(url.pathname.endsWith('/nav'))return Response.json({code:-101,data:{wbi_img:{img_url:'https://i0.hdslb.com/bfs/wbi/'+ 'a'.repeat(32)+'.png',sub_url:'https://i0.hdslb.com/bfs/wbi/'+ 'b'.repeat(32)+'.png'}}});
    assert.equal(url.pathname,'/x/v2/reply/wbi/main');
    assert.equal(JSON.parse(url.searchParams.get('pagination_str')).offset,'opaque-next');
    assert.match(url.searchParams.get('w_rid'),/^[a-f0-9]{32}$/);
    return Response.json({code:0,data:{cursor:{all_count:45,is_end:false,pagination_reply:{next_offset:'opaque-third'}},replies:[{rpid:2,member:{uname:'a'},content:{message:'可读取的评论'}}]}});
  };
  const data=await community('/api/pv/comments',new URL('http://localhost?bvid=BV1s54y1Z7Bi&page=2&cursor=opaque-next'),{bilibili:{}},{fetcher});
  assert.equal(data.comments[0].text,'可读取的评论');assert.equal(data.more,true);
  assert.equal(data.nextCursor,'opaque-third');assert.equal(seen.length,3);
});

test('a legacy three-comment preview never advertises nonfunctional next pages',async()=>{
  const fetcher=async raw=>{
    const url=new URL(raw);
    if(url.pathname.endsWith('/view'))return Response.json({code:0,data:{aid:1,cid:2}});
    if(url.pathname.endsWith('/reply')) {
      assert.equal(url.searchParams.get('ps'),'20');
      return Response.json({code:0,data:{page:{size:20,count:5056},replies:[1,2,3].map(rpid=>({rpid,content:{message:'preview'}}))}});
    }
    return Response.json({code:-352,message:'limited'});
  };
  const data=await community('/api/pv/comments',new URL('http://localhost?bvid=BV1s54y1Z7Bi'),{bilibili:{}},{fetcher});
  assert.equal(data.comments.length,3);assert.equal(data.more,false);assert.match(data.notice,/预览/);
});

test('explicit Bilibili restrictions remain errors, never empty successful comments',async()=>{
  const fetcher=async raw=>Response.json(new URL(raw).pathname.endsWith('/view')
    ?{code:0,data:{aid:1,cid:2}}:{code:-352,message:'-352'});
  await assert.rejects(()=>community('/api/pv/comments',new URL('http://localhost?bvid=BV1s54y1Z7Bi'),{bilibili:{}},{fetcher}),/限制.*-352/);
});

test('segmented protobuf reads progress, mode, color and UTF8 while skipping unknown fields',()=>{
  assert.deepEqual(parseDanmakuSegment(segment),[{time:12.5,mode:1,color:0xabcdef,text:'测试弹幕'}]);
  assert.throws(()=>parseDanmakuSegment(segment.subarray(0,segment.length-2)),/长度|完整/);
  assert.throws(()=>parseDanmakuSegment(Buffer.from('<html>restricted</html>')),/格式|完整|长度/);
});

test('XML restriction falls back to segmented danmaku with the same supplied account',async()=>{
  const seen=[];
  const fetcher=async(raw,options)=>{
    seen.push({url:new URL(raw),cookie:options.headers.Cookie});
    return String(raw).includes('.xml')?new Response('<html>restricted</html>'):new Response(segment);
  };
  const result=await readDanmaku({cid:2,duration:720,stat:{danmaku:2}},'BV1s54y1Z7Bi',{SESSDATA:'synthetic'},{fetcher,parseXml:parseDanmaku});
  assert.equal(result.length,2);assert.equal(result[0].time,12.5);
  assert.deepEqual(seen.slice(1).map(s=>s.url.searchParams.get('segment_index')),['1','2']);
  assert.ok(seen.every(s=>s.cookie==='SESSDATA=synthetic'));
});

test('actual empty XML succeeds without unnecessary fallback; all-source failures stay visible',async()=>{
  let calls=0;
  const none=await readDanmaku({cid:2,stat:{danmaku:0}},'BV1s54y1Z7Bi',{},
    {fetcher:async()=>{calls++;return new Response('<i></i>');},parseXml:parseDanmaku});
  assert.deepEqual(none,[]);assert.equal(calls,1);
  await assert.rejects(()=>readDanmaku({cid:2},'BV1s54y1Z7Bi',{},
    {fetcher:async()=>new Response('blocked',{status:403}),parseXml:parseDanmaku}),/弹幕加载失败/);
});
