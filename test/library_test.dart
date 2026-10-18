import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/models/song.dart';
import 'package:vocashelf/services/library.dart';
import 'package:vocashelf/services/sources.dart';

void main() {
  test('search supports multilingual aliases, producer and voice', () {
    expect(seedSongs.first.matches('world is mine'), isTrue);
    expect(seedSongs.first.matches(' 初音未来 '), isTrue);
    expect(seedSongs[1].matches('WOWAKA'), isTrue);
    expect(seedSongs.first.matches('Neru'), isFalse);
  });
  test('favorites and user writing survive a new library instance', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = Library(prefs)..load();
    final first = library.songs.first;
    await Future.wait([
      library.update(first.copyWith(favorite: true)),
      library.update(
        first.copyWith(
          favorite: true,
          review: '我的听后感',
          lyrics: '我的摘录',
          rating: 5,
        ),
      ),
    ]);
    final reloaded = Library(prefs)..load();
    expect(reloaded.songs.first.favorite, isTrue);
    expect(reloaded.songs.first.review, '我的听后感');
    expect(reloaded.songs.first.rating, 5);
    expect(
      jsonDecode(Song.encode(reloaded.songs)),
      hasLength(seedSongs.length),
    );
  });
  test('invalid stored data stays available for recovery', () async {
    SharedPreferences.setMockInitialValues({
      'vocashelf.library.v1': 'broken-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final library = Library(prefs)..load();
    expect(library.recovered, isTrue);
    expect(prefs.getString('vocashelf.library.v1'), 'broken-json');
  });
  test(
    'source links reject lookalike hosts, credentials and non-song URLs',
    () {
      expect(
        Sources.parseLink(Source.netease, '123456')?.host,
        'music.163.com',
      );
      expect(
        Sources.parseLink(
          Source.netease,
          'https://music.163.com/#/song?id=123',
        ),
        isNotNull,
      );
      expect(
        Sources.parseLink(Source.bilibili, 'BV1B7411m7LV')?.path,
        '/video/BV1B7411m7LV',
      );
      for (final value in [
        'javascript:alert(1)',
        'https://music.163.com.evil.com/song?id=1',
        'https://evil.com@music.163.com/song?id=1',
        'https://music.163.com/playlist?id=1',
        'http://music.163.com/song?id=1',
      ]) {
        expect(Sources.parseLink(Source.netease, value), isNull, reason: value);
      }
      expect(
        Sources.parseLink(
          Source.bilibili,
          'https://www.bilibili.com/video/BV1B7411m7LV?p=2',
        )?.queryParameters['p'],
        '2',
      );
      expect(
        Sources.search(Source.wiki, '初音未来 & wowaka').queryParameters['search'],
        '初音未来 & wowaka',
      );
    },
  );
}
