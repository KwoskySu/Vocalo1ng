import { randomInt } from 'node:crypto';
export function roamBatch(pool, previous = [], count = 24) {
  const unique = [...new Map(pool.map(s => [s.id, s])).values()];
  const previousIds = new Set(previous);
  const fresh = unique.filter(s => !previousIds.has(s.id));
  const fallback = unique.filter(s => previousIds.has(s.id));
  const shuffle = list => { for (let i = list.length - 1; i > 0; i--) { const j = randomInt(i+1); [list[i], list[j]] = [list[j], list[i]]; } return list; };
  return [...shuffle(fresh), ...shuffle(fallback)].slice(0, count);
}
