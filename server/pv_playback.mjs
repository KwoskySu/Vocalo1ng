import { randomBytes } from 'node:crypto';
import { biliCookieHeader, biliUserAgent } from './bilibili.mjs';
import { fetchMedia } from './media_fetch.mjs';
import { retryRead } from './read_retry.mjs';

const headers = { 'User-Agent': biliUserAgent, Referer: 'https://www.bilibili.com/' };
const validBvid = value => /^BV[A-Za-z0-9]{10}$/.test(value);
const sources = stream => [...new Set([stream.baseUrl ?? stream.base_url, ...(stream.backupUrl ?? stream.backup_url ?? [])])]
  .map(videoUrl).filter(Boolean).sort((a, b) => Number(b.hostname.endsWith('.bilivideo.com')) - Number(a.hostname.endsWith('.bilivideo.com'))).map(url => url.href);
export function videoUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443') ||
        !['bilivideo.com', 'bilivideo.cn'].some(host => url.hostname === host || url.hostname.endsWith(`.${host}`))) return null;
    return url;
  } catch { return null; }
}
const xml = value => String(value).replace(/[<>&"']/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;' })[c]);
function representation(stream, source, type) {
  const segment = stream.SegmentBase ?? stream.segment_base;
  const range = segment?.indexRange ?? segment?.index_range;
  const init = segment?.Initialization ?? segment?.initialization;
  if (!/^\d+-\d+$/.test(range) || !/^\d+-\d+$/.test(init)) throw new Error('视频索引不可用');
  return `<AdaptationSet contentType="${type}" mimeType="${type}/mp4" segmentAlignment="true"><Representation id="${type}-${xml(stream.id)}" bandwidth="${Number(stream.bandwidth) || 100000}" codecs="${xml(stream.codecs)}" ${type === 'video' ? `width="${Number(stream.width)}" height="${Number(stream.height)}"` : `audioSamplingRate="${Number(stream.sampleRate ?? stream.sample_rate) || 44100}"`}><BaseURL>${xml(source)}</BaseURL><SegmentBase indexRange="${range}"><Initialization range="${init}"/></SegmentBase></Representation></AdaptationSet>`;
}
export function makeMpd(video, audio, duration, videoPath, audioPath) {
  return `<?xml version="1.0" encoding="utf-8"?><MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" minBufferTime="PT1.5S" mediaPresentationDuration="PT${Number(duration)}S"><Period duration="PT${Number(duration)}S">${representation(video, videoPath, 'video')}${representation(audio, audioPath, 'audio')}</Period></MPD>`;
}

export class BilibiliPlayback {
  constructor({ fetcher = fetch, now = Date.now } = {}) { this.fetcher = fetcher; this.now = now; this.players = new Map(); }
  create(session, bvid) {
    if (!validBvid(bvid)) throw new Error('视频编号无效');
    for (const [key, player] of this.players) if (player.expires < this.now()) this.players.delete(key);
    if (this.players.size >= 100) this.players.delete(this.players.keys().next().value);
    const token = randomBytes(24).toString('hex');
    this.players.set(token, { session, bvid, uid: session.bilibili.profile?.uid ?? '', expires: this.now() + 2 * 3600_000, streams: new Map() });
    return `/player.html?token=${token}`;
  }
  get(token) {
    const player = this.players.get(token);
    if (!player || player.expires < this.now() || player.uid !== (player.session.bilibili.profile?.uid ?? '')) throw new Error('播放会话已更新，请重新打开 PV');
    return player;
  }
  async api(route, params, player) {
    return retryRead(async () => {
    const response = await this.fetcher(`https://api.bilibili.com${route}?${new URLSearchParams(params)}`, {
      headers: { ...headers, ...(player.session.bilibili.cookies ? { Cookie: biliCookieHeader(player.session.bilibili.cookies) } : {}) },
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error(`B 站暂时无法响应（HTTP ${response.status}），请稍后重试`);
    const body = await response.json();
    if (body.code !== 0) {
      const error = new Error(`B 站：${body.message || '暂未提供播放权限'}（${body.code}）`);
      error.retryable = [-352, -412, -509, -500, -503].includes(body.code);
      throw error;
    }
    return body.data;
    }, {attempts: 2});
  }
  async source(token, requested) {
    const player = this.get(token);
    const quality = Number(requested || 80);
    if (![6, 16, 32, 64, 74, 80, 100, 112, 116, 120, 125, 126, 127].includes(quality)) throw new Error('画质参数无效');
    if (!player.cid) {
      const info = await this.api('/x/web-interface/view', { bvid: player.bvid }, player);
      player.cid = info.cid;
    }
    const data = await this.api('/x/player/playurl', { bvid: player.bvid, cid: String(player.cid), qn: String(quality), fnval: '16', fourk: '1' }, player);
    this.get(token); // An account change while resolving must not retain the previous account's stream.
    const videos = (data.dash?.video ?? []).filter(v => /^avc1\./.test(v.codecs) && sources(v).length);
    const audio = (data.dash?.audio ?? []).filter(a => /^mp4a\./.test(a.codecs) && sources(a).length).sort((a, b) => b.bandwidth - a.bandwidth)[0];
    if (!videos.length || !audio) throw new Error('该视频暂无兼容的播放格式，请切换其他 PV 版本');
    const levels = [...new Set(videos.map(v => v.id))].sort((a, b) => b - a);
    const selected = videos.find(v => v.id === quality) ?? videos.find(v => v.id === levels.find(id => id <= quality)) ?? videos[videos.length - 1];
    const add = stream => {
      const key = randomBytes(12).toString('hex');
      player.streams.set(key, sources(stream));
      return `/api/pv/stream?token=${token}&stream=${key}`;
    };
    // Keep several recent sources for requests already in flight during a switch.
    while (player.streams.size > 40) player.streams.delete(player.streams.keys().next().value);
    return {
      bvid: player.bvid,
      quality: selected.id,
      qualities: levels.map(id => ({ id, label: data.support_formats?.find(f => f.quality === id)?.new_description ?? ({ 16: '360P', 32: '480P', 64: '720P', 80: '1080P', 112: '1080P 高码率' })[id] ?? String(id) })),
      mpd: makeMpd(selected, audio, data.dash.duration, add(selected), add(audio)),
    };
  }
  async progressive(token, requested) {
    const player = this.get(token);
    if (!player.cid) player.cid = (await this.api('/x/web-interface/view', {bvid:player.bvid}, player)).cid;
    const data = await this.api('/x/player/playurl', {bvid:player.bvid,cid:String(player.cid),qn:String(Number(requested)||32),fnval:'1',platform:'html5'}, player);
    this.get(token);
    const item = data.durl?.length === 1 ? data.durl[0] : null;
    const urls = item ? [...new Set([item.url,...(item.backup_url||[])])].map(videoUrl).filter(Boolean).map(x=>x.href) : [];
    if (!urls.length) throw new Error('此视频未提供兼容 MP4，请切换 PV 版本或在 B 站查看');
    const key = randomBytes(12).toString('hex'); player.streams.set(key, urls);
    const quality = Number(data.quality)||32;
    return {bvid:player.bvid, quality, qualities:[{id:quality,label:`${({16:'360P',32:'480P',64:'720P',80:'1080P'})[quality]||quality} · 兼容播放`}],url:`/api/pv/stream?token=${token}&stream=${key}`};
  }
  async stream(token, key, range) {
    const player = this.get(token);
    const candidates = player.streams.get(key);
    let target = videoUrl(Array.isArray(candidates) ? candidates[0] : candidates);
    if (!target) throw new Error('播放地址已失效，请重新打开 PV');
    if (range && !/^bytes=\d*-\d*$/.test(range)) throw new Error('无效媒体范围');
    for (let i = 0; i < Math.min(8, (Array.isArray(candidates) ? candidates.length : 1) + 4); i++) {
      let response;
      try {
      response = await fetchMedia(this.fetcher, target, { headers: { ...headers, ...(range ? { Range: range } : {}) }, redirect: 'manual' });
      } catch (error) {
        const backup = Array.isArray(candidates) && candidates[i+1];
        if (!backup) throw error;
        target = videoUrl(backup); continue;
      }
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        await response.body?.cancel();
        target = videoUrl(new URL(response.headers.get('location'), target).href);
        if (!target) throw new Error('媒体跳转来源不可用');
      } else if ([403,404,410,429,500,502,503,504].includes(response.status) && Array.isArray(candidates) && candidates[i+1]) {
        await response.body?.cancel(); target = videoUrl(candidates[i+1]);
      } else return response;
    }
    throw new Error('媒体跳转次数过多');
  }
}
