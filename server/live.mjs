import { randomBytes } from 'node:crypto';

// A read-only, expiring capability exposes only the explicitly published song.
export class LiveStore {
  constructor(now = Date.now) { this.now = now; this.items = new Map(); }
  publish(owner, input) {
    for (const [key, item] of this.items) if (this.now() - item.updated > 7200000) this.items.delete(key);
    let item = [...this.items.values()].find(v => v.owner === owner);
    if (!item) {
      if (this.items.size >= 100) throw new Error('直播窗口数量已达上限');
      item = {owner, token: randomBytes(24).toString('hex')};
      this.items.set(item.token, item);
    }
    const text = (key, max = 500) => String(input[key] ?? '').slice(0, max);
    const cover = text('cover', 2500);
    item.state = {title: text('title'), artist: text('artist'), cover: /^https:\/\//.test(cover) ? cover : '',
      line: text('line'), translation: text('translation'), next: text('next'), previous: text('previous'),
      playing: input.playing === true, position: Math.max(0, Number(input.position) || 0), duration: Math.max(0, Number(input.duration) || 0),
      mode: Math.max(0, Math.min(11, Number(input.mode) || 0)), size: Math.max(18, Math.min(64, Number(input.size) || 32)),
      opacity: Math.max(0, Math.min(1, Number(input.opacity) || 0)), hide: input.hide === true,
      align: ['left','center','right'].includes(input.align) ? input.align : 'center',
      color: /^#[a-f\d]{6}$/i.test(input.color) ? input.color : '#ffffff',
      coverSize: Math.max(40, Math.min(260, Number(input.coverSize) || 160)),
      coverShape: Math.max(0, Math.min(4, Math.floor(Number(input.coverShape) || 0))),
      backgroundStyle: Math.max(0, Math.min(5, Math.floor(Number(input.backgroundStyle) || 0))),
      translationScale: Math.max(.3, Math.min(1, Number(input.translationScale) || .57)),
      titleScale: Math.max(.3, Math.min(1, Number(input.titleScale) || .55)),
      textEffect: Math.max(0, Math.min(4, Math.floor(Number(input.textEffect) || 0))),
      coverVisible: input.coverVisible !== false,
      font: ['sans-serif','serif','monospace','cursive','display','rounded'].includes(input.font) ? input.font : 'sans-serif', translationVisible: input.translationVisible !== false};
    item.updated = this.now();
    return {token: item.token, path: `/live.html?token=${item.token}`};
  }
  read(token) {
    const item = this.items.get(token);
    return !item || this.now() - item.updated > 15000 ? {offline: true} : item.state;
  }
  stop(owner) { for (const [token, item] of this.items) if (item.owner === owner) this.items.delete(token); }
}
