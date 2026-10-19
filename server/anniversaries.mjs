// Public, date-scoped Vocabirth data. Fetch on demand; never mirror the dataset.
export function anniversaryDate(value) {
  const key = String(value ?? '').replace('/', '');
  if (!/^\d{4}$/.test(key)) throw new Error('请输入有效月日');
  const month = Number(key.slice(0, 2)), day = Number(key.slice(2));
  const date = new Date(Date.UTC(2000, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) throw new Error('请输入有效月日');
  return key;
}
export function parseAnniversaries(text) {
  const seen = new Set();
  return text.replace(/^\uFEFF/, '').split(/\r?\n/).flatMap(line => {
    const [id, title, image, rawYear] = line.split('\t').map(s => s.trim());
    const year = Number(rawYear);
    if (!/^(sm|nm|so)\d+$/.test(id ?? '') || !title || !Number.isInteger(year) || year < 2000 || year > 2100 || seen.has(id)) return [];
    seen.add(id);
    let thumbnail = '';
    if (/^\d+\/[\d.]+$/.test(image ?? '')) thumbnail = `https://nicovideo.cdn.nimg.jp/thumbnails/${image}`;
    else { try { const u = new URL(image); if (u.protocol === 'https:' && ['nicovideo.cdn.nimg.jp', 'tn.smilevideo.jp'].includes(u.hostname)) thumbnail = u.href; } catch {} }
    return [{id, title: title.slice(0, 600), thumbnail, year, url: `https://www.nicovideo.jp/watch/${id}`}];
  }).slice(0, 5000);
}
export class AnniversarySource {
  constructor(fetcher = fetch, now = Date.now) { this.fetcher = fetcher; this.now = now; this.cache = new Map(); this.pending = new Map(); }
  async query(value) {
    const date = anniversaryDate(value), old = this.cache.get(date);
    if (old && this.now() - old.at < 21600000) return old.data;
    if (this.pending.has(date)) return this.pending.get(date);
    const task = this.load(date).finally(() => this.pending.delete(date));
    this.pending.set(date, task);
    return task;
  }
  async load(date) {
    let last;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await this.fetcher(`https://vocabirth.melodynade.com/data/${date}.csv`, {signal: AbortSignal.timeout(12000)});
        if (!response.ok && response.status !== 404) throw new Error(`纪念数据源暂时不可用（${response.status}）`);
        const text = response.status === 404 ? '' : await response.text();
        if (text.length > 3000000 || /<html/i.test(text.slice(0, 300))) throw new Error('纪念数据格式异常');
        const data = {date, source: 'https://vocabirth.melodynade.com/', items: parseAnniversaries(text)};
        if (this.cache.size >= 16) this.cache.delete(this.cache.keys().next().value);
        this.cache.set(date, {at: this.now(), data});
        return data;
      } catch (error) { last = error; }
    }
    throw last;
  }
}
