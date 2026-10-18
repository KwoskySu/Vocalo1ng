// Recover the same illustration from the public source credited by VocaWiki.
// No login, challenge solving, mirror scraping or arbitrary remote proxying.
import {mediaUrl} from './core.mjs';
export function wikiFileName(url) {
  const parts = url.pathname.split('/');
  const file = parts[2] === 'thumb' ? parts[5] : parts.at(-1);
  if (!file) return null;
  try { return decodeURIComponent(file); } catch { return null; }
}

export function pixivId(value) {
  try {
    const url = new URL(value);
    if (!['pixiv.net', 'www.pixiv.net'].includes(url.hostname)) return null;
    const id = url.pathname.match(/\/artworks\/(\d+)/)?.[1] ?? url.searchParams.get('illust_id');
    return /^\d{1,12}$/.test(id ?? '') ? id : null;
  } catch { return null; }
}

const cache = new Map();
export async function wikiSourceImage(url, fetcher = fetch) {
  const file = wikiFileName(url);
  if (url.hostname !== 'voca.wiki' || !file || !/\.(jpe?g|png|webp)$/i.test(file)) return null;
  const cached = cache.get(file);
  if (cached && cached.until > Date.now()) return cached.url;
  const request = async target => {
    const response = await fetcher(target, {headers: {'User-Agent': 'Mozilla/5.0', Referer: 'https://www.pixiv.net/'}, signal: AbortSignal.timeout(10000)});
    if (!response.ok) return null;
    return response.json();
  };
  const api = new URL('https://voca.wiki/api.php');
  api.search = new URLSearchParams({action: 'parse', page: `File:${file}`, prop: 'externallinks', format: 'json', formatversion: '2'});
  const info = await request(api);
  const direct=info?.parse?.externallinks?.map(value=>mediaUrl(value,'image')).find(value=>value&&value.hostname!=='voca.wiki'&&(/\.(jpe?g|png|webp|gif)$/i.test(value.pathname)||['jpg','png','webp'].includes(value.searchParams.get('format'))));
  if(direct){if(cache.size>=100)cache.delete(cache.keys().next().value);cache.set(file,{url:direct.href,until:Date.now()+3600000});return direct.href;}
  const id = info?.parse?.externallinks?.map(pixivId).find(Boolean);
  if (!id) return null;
  const work = await request(`https://www.pixiv.net/ajax/illust/${id}`);
  if (work?.error || work?.body?.xRestrict !== 0) return null;
  const source = work.body.urls?.regular;
  if (!source || new URL(source).hostname !== 'i.pximg.net') return null;
  if (cache.size >= 100) cache.delete(cache.keys().next().value);
  cache.set(file, {url: source, until: Date.now() + 3600000});
  return source;
}
