import test from 'node:test';
import assert from 'node:assert/strict';
import { mediaUrl, playlistView, pvScore, songView, unwrap } from './core.mjs';
test('media proxy accepts only known CDN hosts', () => {
  assert.equal(mediaUrl('http://m8.music.126.net/a.mp3').protocol, 'https:');
  for (const url of ['http://127.0.0.1/a', 'https://music.126.net.evil.test/a', 'file:///a',
    'https://user@music.126.net/a', 'https://music.126.net:8080/a']) assert.equal(mediaUrl(url), null);
});
test('provider song and playlist fields normalize without losing identity', () => {
  assert.deepEqual(songView({ id: 1, name: 'song', ar: [{ name: 'P' }], al: { name: 'album', picUrl: 'cover' }, dt: 123 }),
    { id: '1', title: 'song', artist: 'P', album: 'album', cover: 'cover', duration: 123, alias: '' });
  assert.equal(playlistView({ id: 1, creator: { userId: 2 } }, '2').own, true);
  assert.equal(playlistView({ id: 1, creator: { userId: 3 } }, '2').own, false);
  assert.equal(unwrap({ body: { body: { code: 200 } } }).code, 200);
});
test('PV ranking favors matching work and producer while retaining alternatives', () => {
  assert.ok(pvScore({ title: 'wowaka Rolling Girl 原曲 PV' }, 'Rolling Girl', 'wowaka') >
    pvScore({ title: 'Rolling Girl cover' }, 'Rolling Girl', 'wowaka'));
});
