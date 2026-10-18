import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/widgets/music_explorer.dart';
import 'package:vocashelf/widgets/music_login.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'online discover searches provider songs and opens journal actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((request) async {
          final song = {
            'id': '1',
            'title': 'Online song',
            'artist': 'Producer',
            'cover': '',
            'album': 'Album',
          };
          if (request.url.path == '/api/music/roam') {
            return http.Response(
              jsonEncode({
                'songs': List.generate(24, (i) => {...song, 'id': 'roam-$i'}),
                'total': 100,
              }),
              200,
            );
          }
          if (request.url.path == '/api/music/discover') {
            return http.Response(
              jsonEncode({
                'kind': 'vocaloid',
                'songs': [song],
                'playlists': [],
              }),
              200,
            );
          }
          expect(request.url.queryParameters['q'], '初音未来');
          return http.Response(
            jsonEncode({
              'songs': [song],
              'total': 1,
            }),
            200,
          );
        }),
      );
      String? journalId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MusicExplorer(
              music: music,
              playback: null,
              onJournal: (track, {lyrics = '', share = false}) =>
                  journalId = track.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '初音未来');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.byTooltip('搜索网易云'));
      await tester.pumpAndSettle();
      expect(find.text('“初音未来”的搜索结果'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('歌曲操作'));
      await tester.tap(find.byTooltip('歌曲操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('听后感 / 分享手记'));
      await tester.pumpAndSettle();
      expect(journalId, '1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      music.dispose();
    },
  );
  testWidgets(
    'switching audio provider from a playlist replaces the old provider tracks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final music = MusicService(
        base: 'http://localhost:5418',
        client: MockClient((r) async {
          final cloud = {'id': '1', 'title': 'NetEase track', 'artist': 'P'};
          final qq = {'id': 'qq:MID', 'title': 'QQ track', 'artist': 'P'};
          if (r.url.path.endsWith('/roam')) {
            return http.Response('{"songs":[],"total":0}', 200);
          }
          if (r.url.path.endsWith('/discover')) {
            return http.Response(
              jsonEncode({
                'songs': [cloud],
                'playlists': [
                  {'id': 'list', 'title': 'Cloud list'},
                ],
                'kind': 'vocaloid',
              }),
              200,
            );
          }
          if (r.url.path == '/api/playlist') {
            return http.Response(
              jsonEncode({
                'songs': [cloud],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'songs': [qq],
              'total': 1,
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MusicExplorer(
              music: music,
              playback: null,
              onJournal: (track, {lyrics = '', share = false}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cloud list'));
      await tester.tap(find.text('Cloud list'));
      await tester.pumpAndSettle();
      expect(find.text('当前载入前 50 首歌曲'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'QQ 音乐'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'QQ 音乐'));
      await tester.pumpAndSettle();
      expect(find.text('QQ 音乐 · 术曲精选'), findsOneWidget);
      expect(find.text('NetEase track'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      music.dispose();
    },
  );
  testWidgets('QR login stops polling after confirmed login', (tester) async {
    var checks = 0;
    final music = MusicService(
      base: 'http://localhost:5418',
      client: MockClient((request) async {
        if (request.url.path == '/api/login/qr') {
          return http.Response(
            '{"url":"https://music.163.com/login?codekey=test"}',
            200,
          );
        }
        checks++;
        return http.Response(
          '{"code":803,"profile":{"uid":"1","nickname":"listener"}}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMusicLogin(context, music),
              child: const Text('connect'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('连接网易云音乐'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(music.loggedIn, isTrue);
    expect(find.text('连接网易云音乐'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(checks, 1);
    await tester.pumpWidget(const SizedBox());
    music.dispose();
  });
}
