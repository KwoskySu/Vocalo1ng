import { retryRead } from './read_retry.mjs';
import http from 'node:http';
import { randomBytes } from 'node:crypto';
import { createReadStream, existsSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { mediaUrl, playlistView, pvScore, songView, unwrap } from './core.mjs';
import { BilibiliAuth, biliCookieHeader, biliUserAgent } from './bilibili.mjs';
import { BilibiliPlayback } from './pv_playback.mjs';
import { fetchMedia } from './media_fetch.mjs';
import { SessionVault } from './session_vault.mjs';
import { qqCall } from './qq.mjs';
import { roamBatch } from './roam.mjs';
import { wikiSourceImage } from './wiki_image.mjs';
import {windowsWikiImage, wikiApi} from './wiki_transport.mjs';
import { community } from './community.mjs';
import { LiveStore } from './live.mjs';
import { AnniversarySource } from './anniversaries.mjs';
const anniversarySource = new AnniversarySource();
import { songQualities } from './qualities.mjs';
import {resolveSession} from './sessions.mjs';
const liveStore = new LiveStore();

// Only explicitly selected provider methods are exposed. No generic proxy or unlocking routes.
process.env.ENABLE_GENERAL_UNBLOCK = 'false';
process.env.ENABLE_RANDOM_CN_IP = 'false';
process.env.DOTENV_CONFIG_QUIET = 'true';
const require = createRequire(import.meta.url);
const providerRoot = path.dirname(require.resolve('@neteasecloudmusicapienhanced/api'));
const anonymousToken = path.join(tmpdir(), 'anonymous_token');
if (!existsSync(anonymousToken)) writeFileSync(anonymousToken, '', { mode: 0o600 });
const providerRequest = require(path.join(providerRoot, 'util/request.js'));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'build', 'web');
const port = Number(process.env.VOCASHELF_PORT || 5418);
const bindHost = process.env.VOCASHELF_HOST === '0.0.0.0' ? '0.0.0.0' : '127.0.0.1';
const vault = new SessionVault(process.env.VOCASHELF_SESSION_DIR || path.resolve('.session'));
const sessions = vault.load();
const persist = () => vault.save(sessions);
const pvCache = new Map();
const bilibiliAuth = new BilibiliAuth();
const pvPlayback = new BilibiliPlayback();
const roamPools = new Map();

class ApiError extends Error {
  constructor(message, status = 502) { super(message); this.status = status; }
}
const digit = value => /^\d{1,20}$/.test(String(value ?? ''));
const trim = (value, max = 100) => String(value ?? '').trim().slice(0, max);

async function call(name, params = {}, session) {
  try {
    const module = require(path.join(providerRoot, 'module', `${name}.js`));
    const result = await module({ ...params, cookie: session?.cookie || {}, timeout: 15000, unblock: 'false' }, providerRequest);
    const body = unwrap(result);
    if (!body || (body.code && ![200, 800, 801, 802, 803].includes(body.code))) {
      throw new ApiError(body?.code === 301 ? '请先登录网易云音乐' : trim(body?.message ?? body?.msg ?? '网易云暂时无法响应，请稍后重试', 150), body?.code === 301 ? 401 : 502);
    }
    return { body, cookies: result.cookie ?? [] };
  } catch (error) {
    // A provider error is not a local logout. Retain credentials until the user
    // explicitly signs out or replaces them with a successful new login.
    if (error instanceof ApiError) throw error;
    throw new ApiError(error?.body?.code === 301 ? '请先登录网易云音乐' : '网易云接口暂时不可用，请稍后重试', error?.body?.code === 301 ? 401 : 502);
  }
}

function sessionFor(req, res) {
  const sid = req.headers['x-vocashelf-session'] || req.headers.cookie?.match(/(?:^|;\s*)vs_sid=([a-f0-9]{64})/)?.[1];
  const session = resolveSession(sessions, sid);
  res.setHeader('Set-Cookie', `vs_sid=${session.id}; HttpOnly; SameSite=Strict; Path=/; Max-Age=15552000`);
  if (req.headers['x-vocashelf-native'] === '1') res.setHeader('X-VocaShelf-Session', session.id);
  return session;
}

function authenticated(session) { if (!session.uid) throw new ApiError('请先扫码登录网易云音乐', 401); }

async function readBody(req) {
  let text = '';
  for await (const chunk of req) {
    text += chunk;
    if (text.length > 8192) throw new ApiError('请求过大', 413);
  }
  try { return JSON.parse(text || '{}'); } catch { throw new ApiError('无效请求', 400); }
}

function send(res, body, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

async function fetchSafe(url, options = {}, kind) {
  let target = mediaUrl(url, kind);
  if (!target) throw new ApiError('媒体来源不可用');
  for (let redirect = 0; redirect < 4; redirect++) {
    const response = await fetchMedia(fetch, target, { ...options, redirect: 'manual' });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      await response.body?.cancel();
      target = mediaUrl(new URL(response.headers.get('location'), target).href, kind);
      if (!target) throw new ApiError('媒体跳转不可用');
    } else return response;
  }
  throw new ApiError('媒体跳转次数过多');
}

async function pipeResponse(upstream, res, kind) {
  if (!upstream.ok && upstream.status !== 206) throw new ApiError('媒体加载失败');
  const contentType = upstream.headers.get('content-type') ?? '';
  if (/image\/svg\+xml/i.test(contentType)) res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox");
  if (kind === 'image' && !/^image\/(jpe?g|png|webp|gif|avif|svg\+xml)(;|$)/i.test(contentType)) {
    await upstream.body?.cancel();
    throw new ApiError('不是可用图片');
  }
  for (const header of ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
    const value = upstream.headers.get(header); if (value) res.setHeader(header, value);
  }
  res.setHeader('Cache-Control', kind === 'image' ? 'private, max-age=3600' : 'no-store');
  res.writeHead(upstream.status);
  if (!upstream.body) return res.end();
  const source = Readable.fromWeb(upstream.body);
  // Client cancellation and late upstream errors must never terminate the server.
  source.on('error', () => {});
  res.on('error', () => {});
  try { await pipeline(source, res); }
  catch { res.destroy(); }
}

async function api(req, res, url) {
  const route = url.pathname;
  if (route === '/api/anniversaries') {
    try { return send(res, await anniversarySource.query(url.searchParams.get('date'))); }
    catch (error) { return send(res, {error: error.message || '纪念查询暂时失败'}, /有效月日/.test(error.message) ? 400 : 502); }
  }
  if (route === '/api/live/state') return send(res, liveStore.read(url.searchParams.get('token')));
  const stateless = ['/api/image','/api/wiki','/api/health','/api/pv/playback','/api/pv/manifest','/api/pv/stream'].includes(route)
    || (route === '/api/pv/danmaku' && url.searchParams.has('token'));
  const session = stateless ? null : sessionFor(req, res);
  const id = url.searchParams.get('id');
  if (route === '/api/wiki') return send(res, await wikiApi(url.searchParams));
  if (session && route.startsWith('/api/pv/')) {
    session.bilibili ??= {};
    await bilibiliAuth.ensureBrowser(session.bilibili).catch(()=>{});
  }
  if (route === '/api/live/publish' && req.method === 'POST') return send(res, liveStore.publish(session.id, await readBody(req)));
  if (route === '/api/live/stop' && req.method === 'POST') { liveStore.stop(session.id); return send(res, {ok: true}); }
  if (['/api/comments', '/api/pv/comments', '/api/pv/danmaku'].includes(route)) {
    try {
      const owner = url.searchParams.has('token') ? pvPlayback.get(url.searchParams.get('token')) : null;
      if (owner) {
        url.searchParams.set('bvid', owner.bvid);
        await bilibiliAuth.ensureBrowser(owner.session.bilibili).catch(()=>{});
      }
      return send(res, await community(route, url, owner?.session ?? session, {call, qqCall}));
    }
    catch (error) { throw new ApiError(error.message); }
    finally { persist(); }
  }
  if (route === '/api/music/qualities') {
    try { return send(res, await songQualities(id, session, {call,qqCall})); }
    finally {persist();}
  }
  if (route === '/api/download') {
    authenticated(session);
    if (!digit(id)) throw new ApiError('歌曲编号无效',400);
    const quality = url.searchParams.get('quality') ?? 'standard';
    if (!['standard','higher','lossless'].includes(quality)) throw new ApiError('音质无效',400);
    const {body} = await call('song_download_url_v1', {id,level:quality === 'higher' ? 'exhigh' : quality},session);
    const data = body.data;
    if (!data?.url || !mediaUrl(data.url)) throw new ApiError('当前账号没有此歌曲的下载权限，请在网易云客户端确认',403);
    if (url.searchParams.get('check') === '1') return send(res,{path:`/api/download?id=${id}&quality=${quality}`});
    res.setHeader('Content-Disposition',`attachment; filename="${id}.${String(data.type).toLowerCase() === 'flac' ? 'flac' : 'mp3'}"`);
    return pipeResponse(await fetchSafe(data.url,{},'audio'),res,'audio');
  }
  if (route === '/api/health') return send(res, { ok: true, version: '0.4.16', provider: 'personal', lan: bindHost === '0.0.0.0' });
  if (session) session.bilibili ??= {};
  if (route === '/api/session' && req.method === 'GET') return send(res, { profile: session.profile, bilibili: session.bilibili.profile ?? null, qq: session.qq.profile ?? null });
  if (route.startsWith('/api/qq/')) {
    try {
      const mid = url.searchParams.get('id');
      if (route === '/api/qq/login/qr' && req.method === 'POST') {
        const marker = {}; session.qq.pending = marker;
        const data = await qqCall('qr');
        if (session.qq.pending !== marker) throw new Error('二维码已更新');
        session.qq.identifier = data.identifier; session.qq.created = Date.now();
        return send(res, { image: data.image });
      }
      if (route === '/api/qq/login/check') {
        const key = session.qq.identifier;
        if (!key || Date.now() - session.qq.created > 180000) return send(res, { code: 'TIMEOUT' });
        const data = await qqCall('check', { identifier: key });
        if (session.qq.identifier !== key) return send(res, { code: 'TIMEOUT' });
        if (data.code === 'DONE') { session.qq.credential = data.credential; session.qq.profile = data.profile; delete session.qq.identifier; persist(); }
        return send(res, { code: data.code, ...(data.code === 'DONE' ? { profile: data.profile } : {}) });
      }
      if (route === '/api/qq/logout' && req.method === 'POST') { session.qq = {}; persist(); return send(res, { ok: true }); }
      if (route === '/api/qq/search') {
        const q = trim(url.searchParams.get('q'));
        if (!q) throw new Error('请输入歌曲或 P 主名');
        return send(res, await qqCall('search', { q, offset: Math.min(1000, Math.max(0, Number(url.searchParams.get('offset')) || 0)) }, session.qq));
      }
      if (!/^[A-Za-z0-9]{1,30}$/.test(mid ?? '')) throw new Error('QQ 音乐歌曲编号无效');
      if (route === '/api/qq/lyrics') return send(res, await qqCall('lyrics', { id: mid }, session.qq));
      if (route === '/api/qq/url' || route === '/api/qq/audio') {
        const quality = url.searchParams.get('quality') ?? 'standard';
        if (!['standard', 'higher', 'lossless'].includes(quality)) throw new Error('音质无效');
        if (quality !== 'standard' && !session.qq.profile) throw new ApiError('请登录 QQ 音乐解锁对应音质', 401);
        session.qq.streams ??= new Map();
        const streamKey = `${mid}:${quality}`;
        let source = session.qq.streams.get(streamKey);
        if (!source || Date.now() > source.expires) {
          source = { ...await qqCall('url', { id: mid, quality }, session.qq), expires: Date.now() + 240000 };
          if (!mediaUrl(source.url)) throw new Error('QQ 音乐未返回可用媒体地址');
          if (session.qq.streams.size >= 100) session.qq.streams.delete(session.qq.streams.keys().next().value);
          session.qq.streams.set(streamKey, source);
        }
        if (route === '/api/qq/url') return send(res, { path: `/api/qq/audio?id=${mid}&quality=${quality}`, preview: source.preview, quality });
        const headers = req.headers.range && /^bytes=\d*-\d*$/.test(req.headers.range) ? { Range: req.headers.range } : {};
        return pipeResponse(await fetchSafe(source.url, { headers }, 'audio'), res, 'audio');
      }
    } catch (error) { throw new ApiError(error.message, error.status || 502); }
    finally { persist(); }
    throw new ApiError('接口不存在', 404);
  }
  if (route === '/api/music/roam') {
    const provider = url.searchParams.get('provider') === 'qq' ? 'qq' : 'netease';
    let pool = roamPools.get(provider);
    if (!pool || Date.now() - pool.time > 600000) {
      let songs;
      if (provider === 'qq') {
        const results = await Promise.allSettled(['初音未来', 'VOCALOID', '重音テト'].map(q => qqCall('search', { q }, session.qq)));
        songs = results.flatMap(r => r.status === 'fulfilled' ? r.value.songs : []);
      } else {
        const search = await call('cloudsearch', { keywords: 'VOCALOID', type: 1000, limit: 8 }, session);
        const lists = search.body.result?.playlists ?? [];
        const chosen = roamBatch(lists.map(p => ({ ...p, id: String(p.id) })), [], 3);
        const results = await Promise.allSettled(chosen.map(p => call('playlist_track_all', { id: p.id, limit: 100 }, session)));
        songs = results.flatMap(r => r.status === 'fulfilled' ? (r.value.body.songs ?? []).map(songView) : []);
      }
      if (songs.length < 20) throw new ApiError('漫游曲库暂未加载完整，请稍后刷新');
      pool = { songs, time: Date.now() }; roamPools.set(provider, pool);
    }
    const previous = (url.searchParams.get('previous') ?? '').slice(0, 3000).split(',');
    return send(res, { songs: roamBatch(pool.songs, previous), total: new Set(pool.songs.map(s => s.id)).size });
  }
  if (route === '/api/pv/player' && req.method === 'POST') {
    const input = await readBody(req);
    try { return send(res, { url: pvPlayback.create(session, input.bvid) }); }
    catch (error) { throw new ApiError(error.message, 400); }
  }
  if (['/api/pv/playback', '/api/pv/manifest', '/api/pv/stream'].includes(route)) {
    const token = url.searchParams.get('token');
    try {
      if (route === '/api/pv/playback') {
        if (url.searchParams.get('mode') === 'mp4') return send(res, await pvPlayback.progressive(token, url.searchParams.get('quality')));
        const source = await pvPlayback.source(token, url.searchParams.get('quality'));
        const player = pvPlayback.get(token);
        const key = randomBytes(12).toString('hex');
        player.manifests ??= new Map();
        if (player.manifests.size >= 20) player.manifests.delete(player.manifests.keys().next().value);
        player.manifests.set(key, source.mpd);
        return send(res, { bvid: source.bvid, quality: source.quality, qualities: source.qualities, manifest: `/api/pv/manifest?token=${token}&source=${key}` });
      }
      if (route === '/api/pv/manifest') {
        const manifest = pvPlayback.get(token).manifests?.get(url.searchParams.get('source'));
        if (!manifest) throw new Error('播放源已失效，请重新打开 PV');
        res.writeHead(200, { 'Content-Type': 'application/dash+xml', 'Cache-Control': 'no-store' });
        return res.end(manifest);
      }
      return pipeResponse(await pvPlayback.stream(token, url.searchParams.get('stream'), req.headers.range), res, 'video');
    } catch (error) { throw new ApiError(error.message); }
  }
  if (route.startsWith('/api/bilibili/')) {
    try {
      if (route === '/api/bilibili/login/qr' && req.method === 'POST') return send(res, await bilibiliAuth.generate(session.bilibili));
      if (route === '/api/bilibili/login/check' && req.method === 'GET') { const result = await bilibiliAuth.check(session.bilibili); if (result.code === 0) persist(); return send(res, result); }
      if (route === '/api/bilibili/logout' && req.method === 'POST') { const result = bilibiliAuth.logout(session.bilibili); persist(); return send(res, result); }
      if (route === '/api/bilibili/profile' && req.method === 'GET') {
        if (!session.bilibili.cookies) return send(res, { profile: null });
        try { session.bilibili.profile = await bilibiliAuth.profile(session.bilibili.cookies); }
        catch (error) { throw new ApiError(`${error.message}；已保留本机登录数据，请稍后刷新，必要时重新扫码`); }
        return send(res, { profile: session.bilibili.profile });
      }
    } catch (error) { throw new ApiError(error.message); }
    throw new ApiError('接口不存在', 404);
  }
  if (route === '/api/logout' && req.method === 'POST') {
    session.cookie = {}; session.uid = null; session.profile = null; session.key = null;
    persist();
    return send(res, { ok: true });
  }
  if (route === '/api/login/qr' && req.method === 'POST') {
    const { body } = await call('login_qr_key', {}, session);
    session.key = body.data?.unikey;
    if (!session.key) throw new ApiError('暂时无法生成登录二维码');
    session.keyCreated = Date.now();
    return send(res, { url: `https://music.163.com/login?codekey=${encodeURIComponent(session.key)}` });
  }
  if (route === '/api/login/check' && req.method === 'GET') {
    if (!session.key || Date.now() - session.keyCreated > 180000) return send(res, { code: 800 });
    const { body, cookies } = await call('login_qr_check', { key: session.key }, session);
    if (body.code === 803) {
      const cookie = {};
      for (const item of cookies) {
        const first = item.split(';')[0]; const split = first.indexOf('=');
        if (split > 0) cookie[first.slice(0, split)] = first.slice(split + 1);
      }
      if (!cookie.MUSIC_U) throw new ApiError('登录凭证未返回，请重新扫码');
      session.cookie = cookie;
      const result = await call('login_status', {}, session);
      const profile = result.body.data?.profile;
      if (!profile) throw new ApiError('无法读取登录状态，请重新扫码');
      session.uid = profile.userId;
      session.profile = { uid: String(profile.userId), nickname: profile.nickname, avatar: profile.avatarUrl };
      session.key = null;
      persist();
      return send(res, { code: 803, profile: session.profile });
    }
    return send(res, { code: body.code ?? 800 });
  }
  if (route === '/api/music/search') {
    const keyword = trim(url.searchParams.get('q'));
    if (!keyword) throw new ApiError('请输入歌曲或 P 主名', 400);
    const offset = Math.min(Math.max(Number(url.searchParams.get('offset')) || 0, 0), 1000);
    const { body } = await call('cloudsearch', { keywords: keyword, type: 1, limit: 30, offset }, session);
    return send(res, { songs: (body.result?.songs ?? []).map(songView), total: body.result?.songCount ?? 0 });
  }
  if (route === '/api/music/discover') {
    const { body } = await call('cloudsearch', { keywords: 'VOCALOID', type: 1000, limit: 8 }, session);
    const playlists = (body.result?.playlists ?? []).map(p => playlistView(p, session.uid));
    let songs = [];
    let kind = 'vocaloid';
    if (session.uid) {
      try {
        const daily = await call('recommend_songs', {}, session);
        songs = (daily.body.data?.dailySongs ?? []).map(songView); kind = 'daily';
      } catch { /* Fall back to explicitly labelled theme search playlists. */ }
    }
    if (!songs.length && playlists.length) {
      const list = await call('playlist_track_all', { id: playlists[0].id, limit: 24 }, session);
      songs = (list.body.songs ?? []).map(songView);
    }
    return send(res, { songs, playlists, kind });
  }
  if (route === '/api/music/url') {
    if (!digit(id)) throw new ApiError('歌曲 ID 无效', 400);
    const quality = url.searchParams.get('quality') ?? 'standard';
    if (!['standard','higher','lossless'].includes(quality)) throw new ApiError('音质无效',400);
    if (quality !== 'standard') authenticated(session);
    const { body } = await call('song_url_v1', { id, level: quality === 'higher' ? 'exhigh' : quality, crypto: 'eapi' }, session);
    const track = body.data?.[0];
    if (!track?.url || !mediaUrl(track.url)) throw new ApiError('当前账号或地区无法播放这首歌，请更换歌曲或登录后重试', 403);
    if (quality === 'lossless' && !['flac','FLAC'].includes(track.type) || quality === 'higher' && Number(track.br) < 320000) throw new ApiError('账号或此歌曲未提供该音质，请选择可用音质',403);
    return send(res, { path: `/api/audio?id=${id}&quality=${quality}`, preview: Boolean(track.freeTrialInfo),
      expires: track.expi ?? 0 });
  }
  if (route === '/api/audio') {
    if (!digit(id)) throw new ApiError('歌曲 ID 无效', 400);
    const quality = url.searchParams.get('quality') ?? 'standard';
    if (!['standard','higher','lossless'].includes(quality)) throw new ApiError('音质无效',400);
    if (quality !== 'standard') authenticated(session);
    const { body } = await call('song_url_v1', { id, level: quality === 'higher' ? 'exhigh' : quality, crypto: 'eapi' }, session);
    const track = body.data?.[0];
    if (!track?.url) throw new ApiError('此歌曲暂不可播放', 403);
    const headers = {};
    if (req.headers.range && /^bytes=\d*-\d*$/.test(req.headers.range)) headers.Range = req.headers.range;
    return pipeResponse(await fetchSafe(track.url, { headers }, 'audio'), res, 'audio');
  }
  if (route === '/api/music/lyrics') {
    if (!digit(id)) throw new ApiError('歌曲 ID 无效', 400);
    const { body } = await call('lyric', { id }, session);
    return send(res, { original: body.lrc?.lyric ?? '', translated: body.tlyric?.lyric ?? '' });
  }
  if (route === '/api/playlists' && req.method === 'GET') {
    authenticated(session);
    const { body } = await call('user_playlist', { uid: session.uid, limit: 100 }, session);
    return send(res, { playlists: (body.playlist ?? []).map(p => playlistView(p, session.uid)) });
  }
  if (route === '/api/playlist' && req.method === 'GET') {
    if (!digit(id)) throw new ApiError('歌单 ID 无效', 400);
    const offset = Math.min(Math.max(Number(url.searchParams.get('offset')) || 0, 0), 10000);
    const { body } = await call('playlist_track_all', { id, limit: 50, offset }, session);
    return send(res, { songs: (body.songs ?? []).map(songView) });
  }
  if (route === '/api/playlists' && req.method === 'POST') {
    authenticated(session);
    const input = await readBody(req);
    const name = trim(input.name, 40);
    if (!name) throw new ApiError('请填写歌单名称', 400);
    const { body } = await call('playlist_create', { name, privacy: input.private === false ? 0 : 10 }, session);
    if (!body.playlist) throw new ApiError('歌单创建未确认，请刷新检查后再试');
    return send(res, { playlist: playlistView(body.playlist, session.uid) });
  }
  if (route === '/api/playlist/tracks' && req.method === 'POST') {
    authenticated(session);
    const input = await readBody(req);
    if (!digit(input.playlist) || !digit(input.song)) throw new ApiError('歌曲或歌单 ID 无效', 400);
    const detail = await call('playlist_detail', { id: input.playlist }, session);
    if (String(detail.body.playlist?.creator?.userId) !== String(session.uid)) throw new ApiError('只能修改自己创建的歌单', 403);
    await call('playlist_tracks', { pid: input.playlist, tracks: String(input.song), op: 'add' }, session);
    return send(res, { ok: true });
  }
  if (route === '/api/image') {
    const target = url.searchParams.get('url');
    const safe = mediaUrl(target, 'image');
    if (!safe) throw new ApiError('图片来源不可用', 400);
    const headers = { 'User-Agent': 'Mozilla/5.0', Referer: safe.hostname.endsWith('pximg.net') ? 'https://www.pixiv.net/' : `${safe.origin}/` };
    if (process.env.VOCALO1NG_ANDROID === '1' && safe.hostname === 'voca.wiki') {
      const nativeImage = await windowsWikiImage(safe).catch(()=>null);
      if (nativeImage) {
        if (/image\/svg\+xml/i.test(nativeImage.type)) res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox");
        res.writeHead(200,{'Content-Type':nativeImage.type,'Content-Length':nativeImage.body.length,'Cache-Control':'public, max-age=86400'});
        return res.end(nativeImage.body);
      }
    }
    let response = await fetchSafe(safe, { headers }, 'image').catch(error=> {
      if (safe.hostname === 'voca.wiki') return new Response(null,{status:502});
      throw error;
    });
    if (!response.ok && safe.hostname === 'voca.wiki') {
      await response.body?.cancel();
      const systemImage = await windowsWikiImage(safe).catch(()=>null);
      if(systemImage) {
        if (/image\/svg\+xml/i.test(systemImage.type)) res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox");
        res.writeHead(200,{'Content-Type':systemImage.type,'Content-Length':systemImage.body.length,'Cache-Control':'public, max-age=86400'});
        return res.end(systemImage.body);
      }
      const original = await wikiSourceImage(safe).catch(() => null);
      if (original) response = await fetchSafe(original, { headers: { 'User-Agent': 'Mozilla/5.0', Referer: new URL(original).hostname.endsWith('pximg.net')?'https://www.pixiv.net/':`${new URL(original).origin}/` } }, 'image');
      else throw new ApiError('原站暂未允许加载此图片，可打开原文查看', 502);
    }
    return pipeResponse(response, res, 'image');
  }
  if (route === '/api/pv/search') {
    const title = trim(url.searchParams.get('title'));
    const artist = trim(url.searchParams.get('artist'));
    if (!title) throw new ApiError('歌曲名不能为空', 400);
    const order = url.searchParams.get('order') === 'default' ? 'totalrank' : 'click';
    const key = `${title}\0${artist}\0${order}\0${session.bilibili.profile?.uid ?? 'anonymous'}`;
    if (url.searchParams.get('refresh') !== '1' && pvCache.has(key) && Date.now() - pvCache.get(key).time < 3600_000) return send(res, pvCache.get(key).value);
    const target = new URL('https://api.bilibili.com/x/web-interface/search/type');
    target.search = new URLSearchParams({ search_type: 'video', keyword: `${title} ${artist} PV`, page_size: '20', order });
    const body = await retryRead(async()=>{
    const response = await fetch(target, { headers: { 'User-Agent': biliUserAgent, Referer: 'https://www.bilibili.com/',
      ...(session.bilibili.cookies ? { Cookie: biliCookieHeader(session.bilibili.cookies) } : {}),
    }, signal: AbortSignal.timeout(8000) });
    if (!response.ok) throw new ApiError(`B 站暂时限制搜索请求（HTTP ${response.status}），请稍后或确认 B 站账号登录后重试`);
    const value = await response.json();
    if (value.code !== 0) throw new ApiError('B 站暂未提供搜索结果，请稍后重试');
    return value;
    }, {attempts:2});
    const videos = (body.data?.result ?? []).filter(v => /^BV[A-Za-z0-9]{10}$/.test(v.bvid)).slice(0, 12)
      .map(v => ({ bvid: v.bvid, title: v.title.replace(/<[^>]*>/g, ''), author: v.author,
        cover: v.pic.startsWith('//') ? `https:${v.pic}` : v.pic,
        duration: v.duration, cover: mediaUrl(v.pic?.startsWith('//') ? `https:${v.pic}` : v.pic, 'image')?.href ?? '', plays: Number(v.play) || 0, score: pvScore(v, title, artist) }));
    const value = { videos };
    if (pvCache.size > 100) pvCache.delete(pvCache.keys().next().value);
    pvCache.set(key, { time: Date.now(), value });
    return send(res, value);
  }
  throw new ApiError('接口不存在', 404);
}

const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.otf': 'font/otf' };

const server = http.createServer(async (req, res) => {
  try {
    const host = req.headers.host ?? '';
    const localHost = /^(127\.0\.0\.1|localhost)(:\d+)?$/.test(host);
    const lanHost = /^(10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})(:\d+)?$/.test(host);
    if (!localHost && !(bindHost === '0.0.0.0' && lanHost)) throw new ApiError('请求地址不被允许', 403);
    const url = new URL(req.url, `http://${host}`);
    const origin = req.headers.origin;
    const permittedOrigin = !origin || origin === `http://${host}` || ['http://127.0.0.1:5417', 'http://localhost:5417'].includes(origin);
    if (!permittedOrigin) throw new ApiError('请求来源不被允许', 403);
    if (origin) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Access-Control-Allow-Credentials', 'true'); res.setHeader('Vary', 'Origin'); }
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-VocaShelf, X-VocaShelf-Native, X-VocaShelf-Session');
    res.setHeader('Access-Control-Expose-Headers', 'X-VocaShelf-Session');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
    if (url.pathname.startsWith('/api/')) {
      if (!['GET', 'POST'].includes(req.method)) throw new ApiError('不支持此方法', 405);
      if (req.method === 'POST' && req.headers['x-vocashelf'] !== '1') throw new ApiError('请求缺少客户端标识', 403);
      return await api(req, res, url);
    }
    const playerAssets = {
      '/player.html': [path.resolve('server/player.html'), 'text/html; charset=utf-8'],
      '/live.html': [path.resolve('server/live.html'), 'text/html; charset=utf-8'],
      '/live.js': [path.resolve('server/live.js'), 'text/javascript'],
      '/player.js': [path.resolve('server/player.js'), 'text/javascript'],
      '/vendor/dash.all.min.js': [path.join(path.dirname(require.resolve('dashjs/package.json')), 'dist/dash.all.min.js'), 'text/javascript'],
    };
    if (playerAssets[url.pathname]) {
      const [asset, type] = playerAssets[url.pathname];
      res.setHeader('Referrer-Policy', 'no-referrer');
      res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
      return createReadStream(asset).pipe(res);
    }
    const target = path.resolve(root, `.${decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname)}`);
    if (!target.startsWith(root + path.sep)) throw new ApiError('无效路径', 403);
    const info = await stat(target).catch(() => null);
    if (!info?.isFile()) { res.writeHead(404); return res.end('Not found. Build the Flutter web app first.'); }
    res.writeHead(200, { 'Content-Type': mime[path.extname(target)] ?? 'application/octet-stream', 'Cache-Control': 'no-cache' });
    createReadStream(target).pipe(res);
  } catch (error) {
    if (!res.headersSent) send(res, { error: error instanceof ApiError ? error.message : '服务暂时不可用，请稍后重试' }, error.status || 502);
    else res.destroy();
  }
});

server.listen(port, bindHost, () => console.log(`Vocalo1ng: http://127.0.0.1:${port}${bindHost === '127.0.0.1' ? ' (local only)' : ' (LAN enabled)'}`));
