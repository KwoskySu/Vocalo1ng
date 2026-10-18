export function songView(song) {
  const artists = song.ar ?? song.artists ?? [];
  const album = song.al ?? song.album ?? {};
  return {
    id: String(song.id), title: song.name ?? '',
    artist: artists.map(a => a.name).filter(Boolean).join(' / '),
    album: album.name ?? '', cover: album.picUrl ?? song.picUrl ?? '',
    duration: song.dt ?? song.duration ?? 0,
    alias: [...(song.alia ?? song.alias ?? []), ...(song.tns ?? [])].join(' / '),
  };
}

export function playlistView(list, uid) {
  return { id: String(list.id), title: list.name ?? '',
    cover: list.coverImgUrl ?? list.picUrl ?? '', count: list.trackCount ?? 0,
    own: String(list.creator?.userId) === String(uid),
    private: list.privacy === 10, creator: list.creator?.nickname ?? '' };
}

export function mediaUrl(value, kind = 'audio') {
  let url;
  try { url = new URL(value); } catch { return null; }
  const suffixes = kind === 'image'
    ? ['music.126.net', 'music.163.com', 'hdslb.com', 'voca.wiki', 'gtimg.cn', 'qpic.cn', 'qlogo.cn', 'piapro.net', 'pximg.net', 'cdn.piapro.jp', 'pbs.twimg.com', 'upload.wikimedia.org', 'static.wikia.nocookie.net', 'nicovideo.cdn.nimg.jp', 'tn.smilevideo.jp']
    : ['music.126.net', 'music.163.com', 'stream.qqmusic.qq.com'];
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password ||
      (url.port && !['80', '443'].includes(url.port)) ||
      !suffixes.some(host => url.hostname === host || url.hostname.endsWith(`.${host}`))) return null;
  url.protocol = 'https:';
  url.port = '';
  return url;
}

export function pvScore(video, title, artist) {
  // Mobile Node is built without ICU; property escapes would fail at parse time.
  const plain = value => value.toLowerCase().replace(/<[^>]*>/g, '').replace(/[\s\u0021-\u002f\u003a-\u0040\u005b-\u0060\u007b-\u007e\u2000-\u206f\u3000-\u303f\uff01-\uff0f\uff1a-\uff20\uff3b-\uff40\uff5b-\uff65]/g, '');
  const text = plain(video.title ?? '');
  const name = plain(title);
  const producer = plain(artist);
  let score = name && text.includes(name) ? 12 : 0;
  if (producer && text.includes(producer)) score += 5;
  if (/pv|mv|原曲|本家|官方|中字|字幕/i.test(video.title ?? '')) score += 2;
  if (/翻唱|翻调|cover|remix|现场|live/i.test(video.title ?? '')) score -= 3;
  return score;
}

export function unwrap(result) {
  let body = result.body;
  if (body?.body && typeof body.body === 'object') body = body.body;
  return body;
}
