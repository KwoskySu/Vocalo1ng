import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/widgets/bilibili_login.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('platform logouts leave the other account connected', () async {
    final music = MusicService(
      base: 'http://localhost:5418',
      client: MockClient((_) async => http.Response('{"ok":true}', 200)),
    );
    music.profile = {'uid': '1', 'nickname': 'netease'};
    music.bilibiliProfile = {'uid': '2', 'nickname': 'bilibili'};
    await music.logout();
    expect(music.bilibiliLoggedIn, isTrue);
    music.profile = {'uid': '1', 'nickname': 'netease'};
    await music.logoutBilibili();
    expect(music.loggedIn, isTrue);
    expect(music.bilibiliLoggedIn, isFalse);
    music.dispose();
  });
  testWidgets('Bilibili QR confirms profile and stops polling', (tester) async {
    var checks = 0;
    final music = MusicService(
      base: 'http://localhost:5418',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/qr')) {
          return http.Response(
            '{"url":"https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=test"}',
            200,
          );
        }
        checks++;
        return http.Response(
          '{"code":0,"profile":{"uid":"42","nickname":"Bili listener"}}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBilibiliLogin(context, music),
              child: const Text('connect'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('连接 B 站账号'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Bili listener'), findsOneWidget);
    expect(find.textContaining('内置播放器直接使用此账号'), findsOneWidget);
    expect(find.text('登录 B 站播放器'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(checks, 1);
    await tester.pumpWidget(const SizedBox());
    music.dispose();
  });
}
