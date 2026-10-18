// Manual network regression check against an already-running legacy gateway.
// It reads public wiki content only; it does not touch accounts or preferences.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/services/wiki.dart';

class _RealTransport extends HttpOverrides {}

void main() {
  test('real legacy gateway supports wiki search, article and random after fallback', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final service=WikiService();
      try {
        final found=await service.search('Miku');
        expect(found,isNotEmpty);
        final article=await service.article(pageId:found.first.pageId);
        expect(article.html,isNotEmpty);
        final random=await service.randomEntries(5);
        expect(random.length,5);
        // Counts/titles only: no accounts, tokens or full article text in logs.
        print('Search: ${found.first.title}; article characters: ${article.html.length}; random: ${random.length}; covers: ${random.where((e)=>e.image.isNotEmpty).length}');
      } finally {service.dispose();}
    },_RealTransport());
  },timeout:const Timeout(Duration(minutes:2)));
}
