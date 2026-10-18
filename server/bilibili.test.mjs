import test from 'node:test';
import assert from 'node:assert/strict';
import { BilibiliAuth, biliCookieHeader } from './bilibili.mjs';

const json = (data, headers = {}) => new Response(JSON.stringify({ code: 0, data }), { headers });
test('browser bootstrap keeps account credentials and reuses public device cookies', async () => {
  let calls = 0;
  const auth = new BilibiliAuth({now:()=>1000, fetcher:async()=> {
    calls++;
    return new Response('', {headers:{'set-cookie':'buvid3=public-device; Path=/'}});
  }});
  const state = {cookies:{SESSDATA:'existing-account'}};
  await Promise.all([auth.ensureBrowser(state),auth.ensureBrowser(state)]);
  await auth.ensureBrowser(state);
  assert.equal(calls,1);
  assert.equal(state.cookies.SESSDATA,'existing-account');
  assert.equal(state.cookies.buvid3,'public-device');
});
test('Bilibili QR waits for confirmation and returns only public profile', async () => {
  let stateCode = 86101;
  const state = {};
  const auth = new BilibiliAuth({ now: () => 1000, fetcher: async (url, options) => {
    if (url.includes('/generate')) return json({ url: 'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=test', qrcode_key: 'test' });
    if (url.includes('/poll')) return json({ code: stateCode }, stateCode === 0 ? {
      'set-cookie': 'SESSDATA=synthetic-session; Path=/; HttpOnly',
    } : {});
    assert.equal(options.headers.Cookie, 'SESSDATA=synthetic-session');
    return json({ isLogin: true, mid: 42, uname: 'listener', face: '', vipStatus: 0 });
  }});
  const qr = await auth.generate(state);
  assert.ok(qr.url.startsWith('https://passport.bilibili.com/'));
  assert.equal((await auth.check(state)).code, 86101);
  stateCode = 86090; assert.equal((await auth.check(state)).code, 86090);
  assert.equal(state.profile, undefined);
  stateCode = 0;
  const result = await auth.check(state);
  assert.equal(result.profile.nickname, 'listener');
  assert.equal(JSON.stringify(result).includes('synthetic-session'), false);
  assert.equal(state.key, undefined);
  auth.logout(state); assert.deepEqual(state, {});
});
test('Bilibili QR expires without polling and accepts SSO-only cookies locally', async () => {
  const expired = new BilibiliAuth({ now: () => 180001, fetcher: () => { throw new Error('should not call'); } });
  assert.equal((await expired.check({ key: 'old', created: 0 })).code, 86038);
  const auth = new BilibiliAuth({ fetcher: async url => url.includes('/poll')
    ? json({ code: 0, url: 'https://passport.biligame.com/crossDomain?SESSDATA=demo%2Fsession&DedeUserID=42' })
    : json({ isLogin: true, mid: 42, uname: 'listener' }) });
  const state = { key: 'test', created: Date.now() };
  const result = await auth.check(state);
  assert.equal(result.code, 0);
  assert.equal(state.cookies.SESSDATA, 'demo%2Fsession');
  assert.equal(JSON.stringify(result).includes('crossDomain'), false);
  assert.equal(biliCookieHeader({ arbitrary: 'no', SESSDATA: 'yes' }), 'SESSDATA=yes');
});
test('Bilibili accepts the current official account-domain QR URL', async () => {
  const auth = new BilibiliAuth({ fetcher: async () => json({
    url: 'https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=test', qrcode_key: 'test',
  }) });
  assert.equal(new URL((await auth.generate({})).url).hostname, 'account.bilibili.com');
});
test('Bilibili never follows an untrusted credential redirect or accepts a logged-out profile', async () => {
  const auth = new BilibiliAuth({ fetcher: async url => url.includes('/poll')
    ? json({ code: 0, url: 'https://evil.example/?SESSDATA=secret' }) : json({ isLogin: false }) });
  await assert.rejects(auth.check({ key: 'test', created: Date.now() }), /未返回有效/);
  await assert.rejects(auth.profile({ SESSDATA: 'expired' }), /会话未生效/);
});
test('disconnecting during an in-flight QR poll cannot restore the session', async () => {
  let release;
  const auth = new BilibiliAuth({ fetcher: () => new Promise(resolve => { release = resolve; }) });
  const state = { key: 'test', created: Date.now() };
  const checking = auth.check(state);
  auth.logout(state);
  release(json({ code: 0 }, { 'set-cookie': 'SESSDATA=synthetic; Path=/' }));
  assert.equal((await checking).code, 86038);
  assert.deepEqual(state, {});
});
