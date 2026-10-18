import test from 'node:test';
import assert from 'node:assert/strict';
import { wikiFileName, pixivId, wikiSourceImage } from './wiki_image.mjs';

test('wiki thumbnails resolve the original filename; source IDs require the real Pixiv host', () => {
  assert.equal(wikiFileName(new URL('https://voca.wiki/images/thumb/4/46/898570.jpg/280px-898570.jpg.webp')), '898570.jpg');
  assert.equal(pixivId('https://www.pixiv.net/artworks/898570'), '898570');
  assert.equal(pixivId('http://www.pixiv.net/member_illust.php?illust_id=898570'), '898570');
  assert.equal(pixivId('https://www.pixiv.net.attacker.test/artworks/898570'), null);
});

test('source fallback accepts only public, unrestricted artwork from the credited file', async () => {
  const requests = [];
  const fetcher = async url => {
    requests.push(String(url));
    return {ok: true, json: async () => requests.length === 1
      ? {parse: {externallinks: ['https://www.pixiv.net/artworks/123456789']}}
      : {error: false, body: {xRestrict: 0, urls: {regular: 'https://i.pximg.net/test.jpg'}}}};
  };
  assert.equal(await wikiSourceImage(new URL('https://voca.wiki/images/a/ab/test-public.jpg'), fetcher), 'https://i.pximg.net/test.jpg');
  assert.match(requests[0], /File%3Atest-public.jpg/);
  const restricted = async url => ({ok: true, json: async () => String(url).includes('voca.wiki')
    ? {parse: {externallinks: ['https://www.pixiv.net/artworks/123456789']}}
    : {error: false, body: {xRestrict: 1, urls: {regular: 'https://i.pximg.net/private.jpg'}}}});
  assert.equal(await wikiSourceImage(new URL('https://voca.wiki/images/a/ab/test-restricted.jpg'), restricted), null);
});
