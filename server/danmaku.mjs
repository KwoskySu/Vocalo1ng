import { biliCookieHeader, biliUserAgent } from './bilibili.mjs';

// Read only the fields needed by the renderer. Unknown protobuf fields are
// skipped, including 64-bit IDs; no dependency on ICU or browser APIs.
function fields(buffer, visit) {
  let offset = 0;
  const number = () => {
    let value = 0;
    for (let n = 0; n < 10; n++) {
      if (offset >= buffer.length) throw new Error('弹幕分段不完整');
      const byte = buffer[offset++]; value += (byte & 127) * 2 ** (7 * n);
      if (!(byte & 128)) return value;
    }
    throw new Error('弹幕分段格式无效');
  };
  while (offset < buffer.length) {
    const tag = number(), field = Math.floor(tag / 8), wire = tag % 8;
    if (!field) throw new Error('弹幕分段格式无效');
    if (wire === 0) visit(field, number());
    else if (wire === 2) {
      const length = number();
      if (!Number.isSafeInteger(length) || length < 0 || length > buffer.length - offset) throw new Error('弹幕分段长度无效');
      visit(field, buffer.subarray(offset, offset + length)); offset += length;
    } else if (wire === 1 || wire === 5) {
      offset += wire === 1 ? 8 : 4;
      if (offset > buffer.length) throw new Error('弹幕分段不完整');
    } else throw new Error('弹幕分段格式无效');
  }
}

export function parseDanmakuSegment(buffer) {
  if (buffer.length > 8_000_000) throw new Error('弹幕数据过大');
  const items = [];
  fields(buffer, (field, value) => {
    if (field !== 1 || !Buffer.isBuffer(value) || items.length >= 12000) return;
    const d = {time:0, mode:1, color:16777215, text:''};
    fields(value, (key, v) => {
      if (key === 2 && typeof v === 'number') d.time = v / 1000;
      if (key === 3 && typeof v === 'number') d.mode = v;
      if (key === 5 && typeof v === 'number') d.color = v;
      if (key === 7 && Buffer.isBuffer(v)) d.text = v.toString('utf8').slice(0,180);
    });
    if (d.text && Number.isFinite(d.time) && d.time >= 0 && [1,2,3,4,5,6].includes(d.mode)) items.push(d);
  });
  return items.sort((a,b)=>a.time-b.time);
}

async function bytes(response) {
  if (!response.ok) throw new Error(`弹幕请求失败（HTTP ${response.status}）`);
  const reader = response.body?.getReader();
  if (!reader) return Buffer.alloc(0);
  const chunks = []; let size = 0;
  try {
    while (true) {
      const {done,value} = await reader.read(); if (done) break;
      size += value.length;
      if (size > 8_000_000) { await reader.cancel(); throw new Error('弹幕数据过大'); }
      chunks.push(Buffer.from(value));
    }
  } finally { reader.releaseLock(); }
  return Buffer.concat(chunks);
}

export async function readDanmaku(info, bvid, cookies, {fetcher = fetch, parseXml}) {
  if (!/^\d+$/.test(String(info.cid))) throw new Error('视频弹幕编号无效');
  const headers = {'User-Agent':biliUserAgent, Referer:`https://www.bilibili.com/video/${bvid}`,
    ...(biliCookieHeader(cookies) ? {Cookie:biliCookieHeader(cookies)} : {})};
  const started = Date.now();
  const read = async url => {
    const remaining = 18000 - (Date.now() - started);
    if (remaining <= 0) throw new Error('弹幕连接超时');
    return bytes(await fetcher(url, {headers, signal:AbortSignal.timeout(Math.min(6500,remaining)), redirect:'error'}));
  };
  let failure;
  // Public XML CDN avoids relying on the legacy API route as the only source.
  try {
    const items = parseXml(await read(`https://comment.bilibili.com/${info.cid}.xml`));
    if (items.length || !info.stat?.danmaku) return items;
  } catch (e) { failure = e; }
  try {
    const count = Math.min(24, Math.max(1, Math.ceil((Number(info.duration)||360)/360)));
    const groups = new Array(count); let next = 0;
    await Promise.all(Array.from({length:Math.min(count,3)}, async () => {
      while (next < count) {
        const i = next++;
        groups[i] = parseDanmakuSegment(await read(`https://api.bilibili.com/x/v2/dm/web/seg.so?type=1&oid=${info.cid}&segment_index=${i+1}`));
      }
    }));
    const items = groups.flat().sort((a,b)=>a.time-b.time);
    if (items.length || !info.stat?.danmaku) {
      const step = Math.max(1,Math.ceil(items.length/6000));
      return items.filter((_,i)=>i%step===0);
    }
  } catch (e) { failure = e; }
  try { return parseXml(await read(`https://api.bilibili.com/x/v1/dm/list.so?oid=${info.cid}`)); }
  catch (e) { throw new Error(`弹幕加载失败：${(failure || e).message}。可点击“重新加载弹幕”`); }
}
