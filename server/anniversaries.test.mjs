import {test} from 'node:test';
import assert from 'node:assert/strict';
import {anniversaryDate, parseAnniversaries, AnniversarySource} from './anniversaries.mjs';
test('anniversary dates reject impossible dates and arbitrary paths', () => {
  assert.equal(anniversaryDate('02/29'), '0229');
  for (const input of ['0230','0000','1331','../../secret','https://evil.test','2/9']) assert.throws(() => anniversaryDate(input));
});
test('Vocabirth tab data preserves titles and filters bad IDs, years, duplicates and image hosts', () => {
  const data = parseAnniversaries('sm1\tSong, one\t123/123.45\t2012\nsm1\tDuplicate\tx\t2012\nnm2\tTwo\thttps://evil.test/a\t2020\nbad\tThree\tx\t2020\nsm3\tBad year\tx\tx');
  assert.equal(data.length, 2);assert.equal(data[0].title, 'Song, one');
  assert.equal(data[0].thumbnail,'https://nicovideo.cdn.nimg.jp/thumbnails/123/123.45');
  assert.equal(data[1].thumbnail,'');
});
test('date source retries transient failures and coalesces concurrent reads', async () => {
  let calls=0;
  const source=new AnniversarySource(async url=>{assert.equal(url,'https://vocabirth.melodynade.com/data/1019.csv');calls++;if(calls===1)throw Error('timeout');return new Response('sm1\tSong\t1/1\t2012');});
  const [a,b]=await Promise.all([source.query('1019'),source.query('10/19')]);
  assert.equal(a,b);assert.equal(a.items.length,1);await source.query('1019');assert.equal(calls,2);
});
