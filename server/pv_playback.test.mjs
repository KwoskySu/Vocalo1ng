import test from 'node:test';
import assert from 'node:assert/strict';
import { BilibiliPlayback, videoUrl } from './pv_playback.mjs';
const track = (id, codecs, host = 'upos-test.bilivideo.com') => ({ id, codecs, baseUrl: `https://${host}/stream`, bandwidth: 1000, width: 1280, height: 720, SegmentBase: { Initialization: '0-99', indexRange: '100-200' } });
const session = () => ({ bilibili: { profile: { uid: '7' }, cookies: { SESSDATA: 'private' } } });
test('Android MP4 fallback uses actual platform quality and retries a failed CDN', async () => {
  const playback = new BilibiliPlayback({fetcher:async(url)=> {
    if(String(url).includes('/view?'))return Response.json({code:0,data:{cid:123}});
    if(String(url).includes('/playurl?'))return Response.json({code:0,data:{quality:32,durl:[{url:'https://first.bilivideo.com/a.mp4',backup_url:['https://backup.bilivideo.com/a.mp4']}]}});
    if(String(url).includes('first.'))return new Response(null,{status:403});
    return new Response('media',{status:206});
  }});
  const token = new URL(playback.create(session(),'BV1s54y1Z7Bi'),'http://localhost').searchParams.get('token');
  const source = await playback.progressive(token,80);
  assert.equal(source.quality,32);
  const key = new URL(source.url,'http://localhost').searchParams.get('stream');
  assert.equal((await playback.stream(token,key,'bytes=0-4')).status,206);
});
test('embedded playback exposes only actual compatible qualities and scoped media URLs', async () => {
  const calls = [];
  const playback = new BilibiliPlayback({ fetcher: async (url, opts) => {
    calls.push({ url: String(url), opts });
    const main = track(64, 'avc1.64001f', 'untrusted.example');
    main.backup_url = ['https://upos-test.bilivideo.com/backup'];
    const data = String(url).includes('/view?') ? { cid: 123 } : { dash: { duration: 120, video: [main, track(32, 'avc1.64001f'), track(80, 'hev1.test')], audio: [track(30280, 'mp4a.40.2')] } };
    return Response.json({ code: 0, data });
  } });
  const path = playback.create(session(), 'BV1s54y1Z7Bi');
  const token = new URL(path, 'http://localhost').searchParams.get('token');
  const source = await playback.source(token, '80');
  assert.equal(source.quality, 64);
  assert.deepEqual(source.qualities.map(q => q.id), [64, 32]);
  assert.ok(source.mpd.includes('&amp;stream='));
  assert.ok(!JSON.stringify(source).includes('private'));
  assert.ok(!source.mpd.includes('bilivideo.com'));
  assert.equal(calls[1].opts.headers.Cookie, 'SESSDATA=private');
  assert.match(calls[1].url, /qn=80/);
  const key = [...playback.get(token).streams.keys()][0];
  await playback.stream(token, key, 'bytes=0-99');
  assert.equal(calls.at(-1).opts.headers.Range, 'bytes=0-99');
  assert.equal(calls.at(-1).opts.headers.Cookie, undefined);
  assert.equal(calls.at(-1).url, 'https://upos-test.bilivideo.com/backup');
  await assert.rejects(playback.stream(token, 'unknown'), /失效/);
});
test('player capabilities expire and are invalidated on account changes', () => {
  let time = 0;
  const playback = new BilibiliPlayback({ now: () => time });
  const owner = session();
  const token = new URL(playback.create(owner, 'BV1s54y1Z7Bi'), 'http://localhost').searchParams.get('token');
  delete owner.bilibili.profile;
  assert.throws(() => playback.get(token), /会话/);
  owner.bilibili.profile = { uid: '7' };
  time = 3 * 3600_000;
  assert.throws(() => playback.get(token), /会话/);
  assert.throws(() => playback.create(owner, '../bad'), /编号/);
});
test('PV stream proxy rejects arbitrary hosts and redirects', async () => {
  for (const url of ['https://bilivideo.com.evil.test/x', 'http://upos.bilivideo.com/x', 'https://127.0.0.1/x', 'https://user@upos.bilivideo.com/x', 'https://upos.bilivideo.com:8888/x']) assert.equal(videoUrl(url), null);
  const playback = new BilibiliPlayback({ fetcher: async () => new Response(null, { status: 302, headers: { location: 'https://127.0.0.1/private' } }) });
  const token = new URL(playback.create(session(), 'BV1s54y1Z7Bi'), 'http://localhost').searchParams.get('token');
  playback.get(token).streams.set('key', 'https://upos.bilivideo.com/stream');
  await assert.rejects(playback.stream(token, 'key'), /跳转来源/);
  await assert.rejects(playback.stream(token, 'key', 'bytes=0-99,200-300'), /范围/);
});
