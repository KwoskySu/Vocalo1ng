import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/music.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native startup requests wait for one initial session and reuse it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((r) async {
          calls++;
          if (calls == 1) {
            started.complete();
            return first.future;
          }
          expect(r.headers['X-VocaShelf-Session'], 'stable-session');
          return http.Response(
            '{}',
            200,
            headers: {'x-vocashelf-session': 'stable-session'},
          );
        }),
      );
      final a = music.request('/first');
      final b = music.request('/second');
      await started.future;
      expect(calls, 1);
      first.complete(
        http.Response(
          '{}',
          200,
          headers: {'x-vocashelf-session': 'stable-session'},
        ),
      );
      await Future.wait([a, b]);
      expect(calls, 2);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'session:http://localhost:5418',
        ),
        'stable-session',
      );
      music.dispose();
    },
  );
}
