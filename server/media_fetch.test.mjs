import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchMedia } from './media_fetch.mjs';

test('media timeout ends when headers arrive so paused playback can remain open', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let signal;
  const response = await fetchMedia(async (_, options) => { signal = options.signal; return new Response('media'); }, 'https://upos.bilivideo.com/a');
  t.mock.timers.tick(60000);
  assert.equal(signal.aborted, false);
  assert.equal(await response.text(), 'media');
});
test('media requests still abort when headers never arrive', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const pending = fetchMedia((_, options) => new Promise((_, reject) => options.signal.addEventListener('abort', () => reject(new Error('timeout')))), 'https://upos.bilivideo.com/a');
  const rejected = assert.rejects(pending, /timeout/);
  t.mock.timers.tick(20001);
  await rejected;
});
