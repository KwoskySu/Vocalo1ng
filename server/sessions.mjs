import {randomBytes} from 'node:crypto';
export const hasAccount = s => Boolean(s.profile || s.uid || s.cookie?.MUSIC_U || s.bilibili?.profile || s.bilibili?.cookies?.SESSDATA || s.qq?.profile || s.qq?.credential);
export function resolveSession(sessions, sid, {now = Date.now(), anonymousLimit = 100} = {}) {
  const existing = sessions.get(sid);
  if (existing && (hasAccount(existing) || now - existing.updated < 180 * 86400_000)) {
    existing.updated = now; existing.bilibili ??= {}; existing.qq ??= {};
    return existing;
  }
  // Anonymous traffic must never evict credentials. Images and token-scoped
  // media do not call this function at all.
  const anonymous = [...sessions.values()].filter(s => !hasAccount(s)).sort((a,b)=>a.updated-b.updated);
  while (anonymous.length >= anonymousLimit) sessions.delete(anonymous.shift().id);
  const id = randomBytes(32).toString('hex');
  const session = {id,updated:now,cookie:{},uid:null,profile:null,bilibili:{},qq:{}};
  sessions.set(id,session);
  return session;
}
