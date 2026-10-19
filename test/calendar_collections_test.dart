import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/birthdays.dart';
import 'package:vocashelf/services/collections.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/widgets/birthday_calendar.dart';
import 'package:vocashelf/widgets/collections.dart';

void main() {
  test(
    'birthday countdown includes today and handles year boundary without timezone drift',
    () {
      final miku = singerBirthdays.first;
      expect(miku.days(DateTime(2026, 8, 31, 23, 59)), 0);
      expect(miku.days(DateTime(2026, 9, 1)), 364);
      expect(
        singerBirthdays
            .firstWhere((s) => s.id == 'luka')
            .days(DateTime(2026, 12, 31)),
        30,
      );
    },
  );
  testWidgets(
    'saved wiki and comments remain accessible inside the collection tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'vocalo1ng.collections.v1': jsonEncode({
          'tracks': [],
          'liked': [],
          'folders': {},
          'wikis': {
            '1': {'id': 1, 'title': '保留的百科'},
          },
          'comments': {
            '1': {'text': '保留的评论', 'author': '作者', 'likes': 3},
          },
        }),
      });
      await collections.load();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CollectionsPage(playback: null)),
        ),
      );
      await tester.tap(find.text('百科'));
      await tester.pumpAndSettle();
      expect(find.text('保留的百科'), findsOneWidget);
      await tester.tap(find.text('评论收藏'));
      await tester.pumpAndSettle();
      expect(find.text('保留的评论'), findsOneWidget);
      expect(collections.wikis.length, 1);
      expect(collections.comments.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'selected birthday cards and anniversary results fit Android portrait and landscape',
    (tester) async {
      final pixel =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==';
      for (final size in [const Size(320, 700), const Size(800, 360)]) {
        SharedPreferences.setMockInitialValues({
          'birthdays.selected': ['miku', 'kaito'],
          'birthdays.images': jsonEncode({'miku': pixel, 'kaito': pixel}),
        });
        final client = MockClient(
          (r) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'sm1',
                  'title': '今日纪念曲',
                  'thumbnail': '',
                  'year': 2012,
                  'url': 'https://www.nicovideo.jp/watch/sm1',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        final music = MusicService(client: client, base: 'http://localhost');
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(size),
            theme: ThemeData(platform: TargetPlatform.android),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.2),
              ),
              child: Scaffold(body: BirthdayCalendar(music: music)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(PageView),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(PageView), findsOneWidget);
        expect(find.textContaining('初音未来'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        music.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
