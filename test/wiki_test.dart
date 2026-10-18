import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocashelf/services/wiki.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  for (final legacyStatus in [404, 200]) {
    test(
      'legacy wiki gateway $legacyStatus falls back and remains usable',
      () async {
        var proxyCalls = 0, directCalls = 0;
        final service = WikiService(
          useGateway: true,
          client: MockClient((request) async {
            if (request.url.host == '127.0.0.1') {
              proxyCalls++;
              return http.Response(
                legacyStatus == 404 ? '{}' : '<html>old app</html>',
                legacyStatus,
              );
            }
            directCalls++;
            expect(request.url.host, 'voca.wiki');
            if (request.url.queryParameters['action'] == 'parse') {
              return http.Response(
                '{"parse":{"title":"Miku","pageid":6,"text":"<p>article</p>"}}',
                200,
              );
            }
            return http.Response(
              '{"query":{"search":[{"title":"Miku","pageid":6}]}}',
              200,
            );
          }),
        );
        expect((await service.search('Miku')).single.pageId, 6);
        expect((await service.article(pageId: 6)).title, 'Miku');
        expect(proxyCalls, 1);
        expect(directCalls, 2);
        service.dispose();
      },
    );
  }
  test('wiki retains table typography and editorial alignment safely', () {
    final document = html_parser.parseFragment(
      sanitizeWikiHtml(
        '<table class="wikitable" style="width:320px;background-color:#fff;font-family:serif;border-width:;border-color:">'
        '<tr><td align="center" style="font-size:20px;color:red;position:fixed;background-image:url(https://invalid.example)">text</td></tr></table>'
        '<center>heading</center>',
      ),
    );
    final table = document.querySelector('table')!;
    expect(table.attributes['style'], contains('font-family:serif'));
    expect(table.attributes['style'], contains('width:320px'));
    expect(table.attributes['style'], isNot(contains('border-width:')));
    expect(table.attributes['style'], isNot(contains('border-color:')));
    final cell = document.querySelector('td')!;
    expect(cell.attributes['style'], contains('text-align:center'));
    expect(cell.attributes['style'], contains('font-size:20px'));
    expect(cell.attributes['style'], isNot(contains('fixed')));
    expect(cell.attributes['style'], isNot(contains('url(')));
    expect(
      document.querySelector('center')!.attributes['style'],
      contains('text-align:center'),
    );
  });
  test(
    'wiki portrait keeps both dimensions and removes decorative page backgrounds',
    () {
      final html = sanitizeWikiHtml(
        '<table width="900"><tr><td>'
        '<img src="/images/miku.png" width="300" height="414" style="width:100%;height:414px">'
        '</td></tr></table><div class="sidebar-character"><img class="moe-img-function" src="/images/background.jpg"></div>',
      );
      final document = html_parser.parseFragment(html);
      final portrait = document.querySelector('img')!;
      expect(portrait.attributes['width'], '300');
      expect(portrait.attributes['height'], '414');
      expect(portrait.attributes['style'], contains('object-fit:contain'));
      expect(document.querySelectorAll('img'), hasLength(1));
    },
  );
  test('wiki keeps actual Nico covers and proxies native SVG icons', () {
    final html = html_parser.parseFragment(
      sanitizeWikiHtml(
        '<div class="famed-song-imgbox"><img class="moe-img-function" src="https://nicovideo.cdn.nimg.jp/thumbnails/20565926/20565926"></div><img src="/images/7/72/Disambig.svg" width="25" height="20">',
      ),
    );
    final images = html.querySelectorAll('img');
    expect(images.length, 2);
    expect(images.first.attributes['width'], '320');
    expect(Uri.parse(images.first.attributes['src']!).path, '/api/image');
    expect(
      Uri.parse(images.last.attributes['src']!).queryParameters['url'],
      endsWith('Disambig.svg'),
    );
  });
  test('in-app wiki reader removes active content and unsafe links', () {
    final html = sanitizeWikiHtml(
      '<h2>初音未来</h2><script>bad()</script><iframe src="https://example.com"></iframe>'
      '<a href="javascript:bad()" onclick="bad()">link</a><a href="/wowaka">wiki</a>',
    );
    expect(html, contains('初音未来'));
    expect(html, contains('https://voca.wiki/wowaka'));
    expect(html, isNot(contains('<script')));
    expect(html, isNot(contains('<iframe')));
    expect(html, isNot(contains('javascript:')));
    expect(html, isNot(contains('onclick')));
  });
  test(
    'wiki retrieves text snippets for matching and caches repeated queries',
    () async {
      var calls = 0;
      final service = WikiService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'voca.wiki');
          expect(request.url.queryParameters['srsearch'], 'wowaka');
          expect(request.url.queryParameters['srprop'], 'snippet');
          return http.Response(
            '{"query":{"search":[{"title":"wowaka","pageid":12376}]}}',
            200,
          );
        }),
      );
      final entries = await service.search(' wowaka ');
      expect(entries.single.title, 'wowaka');
      expect(entries.single.uri.queryParameters['curid'], '12376');
      await service.search('wowaka');
      expect(calls, 1);
      service.dispose();
    },
  );
  test('wiki reports service failures instead of inventing results', () async {
    final service = WikiService(
      client: MockClient(
        (_) async => http.Response('{"error":{"code":"maxlag"}}', 200),
      ),
    );
    await expectLater(service.search('初音未来'), throwsStateError);
    service.dispose();
  });
}
