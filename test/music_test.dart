import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/services/lyrics.dart';

void main() {
  test(
    'QR login keeps platform credentials out of frontend and uses local session',
    () async {
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((request) async {
          if (request.url.path == '/api/login/qr') {
            expect(request.method, 'POST');
            expect(request.headers['X-VocaShelf'], '1');
            return http.Response(
              '{"url":"https://music.163.com/login?codekey=test"}',
              200,
              headers: {'x-vocashelf-session': 'local-session'},
            );
          }
          expect(request.headers['X-VocaShelf-Session'], 'local-session');
          return http.Response(
            '{"code":803,"profile":{"uid":"123","nickname":"listener"}}',
            200,
          );
        }),
      );
      expect(await music.startLogin(), contains('codekey=test'));
      expect(await music.checkLogin(), 803);
      expect(music.loggedIn, isTrue);
      expect(music.profile!.containsKey('cookie'), isFalse);
      music.dispose();
    },
  );
  test(
    'cloud playlist creation and adding tracks use explicit POST requests',
    () async {
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body);
          if (request.url.path == '/api/playlists') {
            expect(body['private'], isTrue);
            expect(body['name'], '术曲收藏');
            return http.Response(
              '{"playlist":{"id":"10","title":"playlist","own":true}}',
              200,
            );
          }
          expect(body['playlist'], '10');
          expect(body['song'], '20');
          return http.Response('{"ok":true}', 200);
        }),
      );
      expect((await music.createPlaylist('术曲收藏')).id, '10');
      await music.addToPlaylist('10', '20');
      music.dispose();
    },
  );
  test(
    'unavailable playback is reported without fabricating a playable URL',
    () async {
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient(
          (_) async => http.Response('{"error":"当前账号无法播放"}', 403),
        ),
      );
      await expectLater(music.stream('123'), throwsA(isA<MusicApiException>()));
      music.dispose();
    },
  );
  test('LRC supports repeated timestamps, fractions and metadata', () {
    final lines = parseLyrics(
      '[ar:artist]\n[00:02.50]second\n[00:01.005][00:03.10]repeat\nplain',
    );
    expect(lines.map((e) => e.text), ['plain', 'repeat', 'second', 'repeat']);
    expect(lines[1].time!.inMilliseconds, 1005);
    expect(lines[2].time!.inMilliseconds, 2500);
  });
}
