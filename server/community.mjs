import { retryRead } from './read_retry.mjs';
import { inflateSync, inflateRawSync, gunzipSync } from 'node:zlib';
import { biliCookieHeader, biliUserAgent } from './bilibili.mjs';
import { readDanmaku } from './danmaku.mjs';
import { pagedBiliComments } from './bili_comments.mjs';

export const commentView = c => ({id: String(c.commentId ?? c.rpid), author: c.user?.nickname ?? c.member?.uname ?? '',
  avatar: c.user?.avatarUrl ?? c.member?.avatar ?? '', text: c.content?.message ?? c.content ?? '',
  likes: Number(c.likedCount ?? c.like ?? 0), time: Number(c.time ?? c.ctime * 1000 ?? 0)});

export function parseDanmaku(buffer) {
  if (buffer.length > 8_000_000) throw new Error('弹幕数据过大');
  let xml = buffer.toString('utf8');
  if (!xml.trimStart().startsWith('<')) {
    let decoded;
    for (const inflate of [inflateSync, inflateRawSync, gunzipSync]) {
      try { decoded = inflate(buffer, {maxOutputLength: 16_000_000}).toString('utf8'); break; } catch {}
    }
    if (!decoded) throw new Error('弹幕数据无法解析，请刷新');
    xml = decoded;
  }
  if (!/<i(?:\s|>)/.test(xml) || !xml.includes('</i>')) throw new Error('B 站未返回有效弹幕，可能受到访问限制，请登录后重试');
  const decode = s => s.replace(/&#(x[\da-f]+|\d+);/gi, (_, n) => {const c = n[0].toLowerCase() === 'x' ? parseInt(n.slice(1),16) : Number(n); return c <= 0x10ffff ? String.fromCodePoint(c) : '';}).replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&amp;/g,'&');
  return [...xml.matchAll(/<d\s+p=["']([^"']+)["'][^>]*>([\s\S]*?)<\/d>/g)].slice(0,6000).map(m => {
    const p=m[1].split(','); return {time:Number(p[0]),text:decode(m[2]).slice(0,180),color:Number(p[3]),mode:Number(p[1])};
  }).filter(c=>Number.isFinite(c.time)).sort((a,b)=>a.time-b.time);
}

export async function community(route, url, session, {call, qqCall, fetcher = fetch}) {
  const id = url.searchParams.get('id') ?? '';
  const order = url.searchParams.get('sort') === 'latest' ? 'latest' : 'hot';
  const page = Math.max(1, Math.min(100, Number(url.searchParams.get('page')) || 1));
  const bili = async (path, params) => retryRead(async () => {
    const response = await fetcher(`https://api.bilibili.com${path}?${new URLSearchParams(params)}`, {
      headers: {'User-Agent': biliUserAgent, Referer: 'https://www.bilibili.com/',
        ...(session.bilibili.cookies ? {Cookie: biliCookieHeader(session.bilibili.cookies)} : {})}, signal: AbortSignal.timeout(15000)});
    if (!response.ok) throw new Error(`B 站请求受限（HTTP ${response.status}），请登录后刷新或稍后重试`);
    const result = await response.json();
    if (result.code !== 0) {
      const error = new Error(result.code === -352 || result.code === -412
        ? `B 站暂时限制了此请求（${result.code}），请稍后刷新；已登录账号会继续保留`
        : `B 站：${result.message || '内容暂不可用'}（${result.code}）`);
      error.retryable = ![-352, -412, -400, -403, -404].includes(result.code);
      throw error;
    }
    return result.data;
  }, {attempts:2});
  if (route === '/api/comments') {
    if (id.startsWith('qq:')) {
      if(!/^[A-Za-z0-9]{1,30}$/.test(id.slice(3)))throw new Error('歌曲编号无效');
      return qqCall('comments', {id: id.slice(3), sort: order, page}, session.qq);
    }
    if (!/^\d{1,20}$/.test(id)) throw new Error('歌曲编号无效');
    const {body} = await call('comment_music', {id, limit: 50, offset: (page - 1) * 50}, session);
    const values = order === 'hot' && page === 1 ? [...(body.hotComments ?? []), ...(body.comments ?? [])] : body.comments ?? [];
    const comments = [...new Map(values.map(c => [c.commentId, commentView(c)])).values()];
    comments.sort((a, b) => order === 'hot' ? b.likes - a.likes : b.time - a.time);
    return {comments, total: body.total ?? comments.length, more: Boolean(body.more), source: `https://music.163.com/song?id=${id}`};
  }
  if (route === '/api/pv/comments' || route === '/api/pv/danmaku') {
    const bvid = url.searchParams.get('bvid');
    if (!/^BV[A-Za-z0-9]{10}$/.test(bvid ?? '')) throw new Error('视频编号无效');
    const info = await bili('/x/web-interface/view', {bvid});
    if (route.endsWith('comments')) {
      const cursor=url.searchParams.get('cursor') || '';
      let data, paginated=false, notice='';
      const size = 20;
      try {
        data=await pagedBiliComments(info,bvid,order,cursor,session.bilibili.cookies,fetcher);
        paginated=true;
      }
      catch (original) {
        // The legacy route may expose only three preview comments. Never
        // advertise paging merely because its metadata reports a larger total.
        if(page!==1 || cursor) throw original;
        data = await bili('/x/v2/reply', {type:'1',oid:String(info.aid),sort:order==='hot'?'2':'0',pn:'1',ps:String(size)});
        notice=`${original.message}。当前仅显示平台返回的评论预览，可稍后刷新。`;
      }
      const replies = [...(page === 1 ? data.top_replies ?? [] : []), ...(data.replies ?? [])];
      const comments = [...new Map(replies.map(c=>[String(c.rpid),commentView(c)])).values()];
      const total = data.page?.count ?? data.cursor?.all_count ?? comments.length;
      const nextCursor=paginated ? data.cursor?.pagination_reply?.next_offset ?? '' : '';
      return {comments, total, notice, nextCursor,
        more: paginated && data.cursor?.is_end===false && Boolean(nextCursor) && nextCursor!==cursor,
        source: `https://www.bilibili.com/video/${bvid}`};
    }
    const items = await readDanmaku(info, bvid, session.bilibili.cookies, {fetcher, parseXml:parseDanmaku});
    return {items};
  }
  return null;
}
