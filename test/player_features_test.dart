import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/models/music.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/services/song_theme.dart';
import 'package:vocashelf/services/song_wiki.dart';
import 'package:vocashelf/services/wiki.dart';
import 'package:vocashelf/services/lyrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'QQ track identity routes audio and lyrics through QQ independently of current search source',
    () async {
      final paths = <String>[];
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((r) async {
          paths.add(r.url.path);
          expect(r.url.queryParameters['id'], 'MID123');
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/url')
                  ? {'path': '/api/qq/audio?id=MID123', 'preview': false}
                  : {'original': '[00:01]QQ lyric', 'translated': ''},
            ),
            200,
          );
        }),
      );
      final source = await music.stream('qq:MID123');
      final lyric = await music.lyrics('qq:MID123');
      expect(paths, ['/api/qq/url', '/api/qq/lyrics']);
      expect(source.url, contains('/api/qq/audio'));
      expect(lyric.original, contains('QQ lyric'));
      music.dispose();
    },
  );
  test(
    'native session and audio source restore after a new service instance',
    () async {
      SharedPreferences.setMockInitialValues({
        'session:http://localhost:5418': 'saved-session',
        'audioProvider': 'qq',
      });
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((r) async {
          expect(r.headers['X-VocaShelf-Session'], 'saved-session');
          return http.Response(
            '{"profile":{"uid":"1"},"qq":{"uid":"2"},"bilibili":{"uid":"3"}}',
            200,
          );
        }),
      );
      await music.restoreSession();
      expect(music.audioProvider, 'qq');
      expect(music.loggedIn, true);
      expect(music.qqProfile!['uid'], '2');
      expect(music.bilibiliLoggedIn, true);
      music.dispose();
    },
  );
  test(
    '32 distinct presets and nearest-cover adaptation with durable manual override',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(songThemes.length, greaterThanOrEqualTo(30));
      expect(songThemes.map((p) => p.name).toSet().length, songThemes.length);
      for (var i = 0; i < songThemes.length; i++) {
        expect(nearestTheme(songThemes[i].seed), i);
      }
      expect(stableThemeIndex('Miku'), stableThemeIndex('Miku'));
      final appearance = SongAppearance();
      appearance.select(9);
      await appearance.save();
      await appearance.adapt('other song', '');
      expect(appearance.index, 9);
      final restored = SongAppearance();
      await restored.load();
      expect(restored.automatic, false);
      expect(restored.index, 9);
      appearance.dispose();
      restored.dispose();
    },
  );
  test(
    'wiki ranking prefers song and producer and recognizes translated title brackets',
    () {
      const song = MusicTrack(
        id: '1',
        title: '神のまにまに (神的随波逐流)',
        artist: 'れるりり / 初音ミク',
      );
      expect(wikiQueries(song), contains('神的随波逐流'));
      expect(wikiMatchScore(const WikiEntry('神的随波逐流', 1), song), 100);
      expect(
        wikiMatchScore(const WikiEntry('神的随波逐流(れるりり)', 2), song),
        greaterThan(wikiMatchScore(const WikiEntry('神的随波逐流(翻唱)', 3), song)),
      );
      expect(wikiMatchScore(const WikiEntry('初音未来', 4), song), 0);
      const world = MusicTrack(
        id: 'qq:MID',
        title: 'ワールドイズマイン (World is Mine)',
        artist: 'supercell / 初音未来',
      );
      expect(
        wikiMatchScore(const WikiEntry('世界第一的公主殿下', 5, 'World is Mine'), world),
        greaterThan(
          wikiMatchScore(
            const WikiEntry('World is Mine(CPKI Remix)', 6),
            world,
          ),
        ),
      );
    },
  );
  test(
    'lyric index follows playback and seeking backwards including untimed lines',
    () {
      final lines = parseLyrics(
        '[ar:Producer]\n[00:01]first\n[00:03]second\n[00:07]last',
      );
      expect(activeLyricIndex(lines, Duration.zero), -1);
      expect(activeLyricIndex(lines, const Duration(seconds: 4)), 1);
      expect(activeLyricIndex(lines, const Duration(seconds: 2)), 0);
    },
  );
}
