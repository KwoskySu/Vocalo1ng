import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/services/song_theme.dart';
import 'package:vocashelf/widgets/comments.dart';
import 'package:vocashelf/widgets/player_layout.dart';
import 'package:vocashelf/widgets/player_visuals.dart';

void main() {
  testWidgets(
    'landscape phone gives lyrics most of the width and keeps controls below',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 844,
            height: 260,
            child: PhoneLandscapePlayer(
              album: const SizedBox(key: ValueKey('album'), height: 180),
              lyrics: const SizedBox.expand(key: ValueKey('lyrics')),
              controls: const SizedBox(key: ValueKey('controls'), height: 48),
            ),
          ),
        ),
      );
      final left = tester.getRect(find.byKey(const ValueKey('album')));
      final right = tester.getRect(find.byKey(const ValueKey('lyrics')));
      final controls = tester.getRect(find.byKey(const ValueKey('controls')));
      expect(right.width, greaterThan(left.width * 1.7));
      expect(controls.top, greaterThanOrEqualTo(right.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all phone cover effects fit the same thumbnail including stacked effects',
    (tester) async {
      final old = Set<String>.of(songAppearance.coverEffects);
      addTearDown(() {
        songAppearance.coverEffects
          ..clear()
          ..addAll(old);
      });
      for (final effects in [
        ...coverEffectNames.keys.map((e) => {e}),
        coverEffectNames.keys.toSet(),
      ]) {
        songAppearance.coverEffects
          ..clear()
          ..addAll(effects);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 800)),
              child: const Center(
                child: SizedBox.square(
                  dimension: 88,
                  child: MotionCover(
                    url: '',
                    size: 88,
                    motion: AlwaysStoppedAnimation(.3),
                    style: 0,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(MotionCover)), const Size(88, 88));
        expect(
          find.descendant(
            of: find.byType(MotionCover),
            matching: find.byType(FittedBox),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: effects.join(','));
      }
    },
  );

  testWidgets(
    'comment continuation sends cursor and deduplicates overlapping pages',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final calls = <Uri>[];
      final music = MusicService(
        base: 'http://test',
        client: MockClient((request) async {
          calls.add(request.url);
          final next = request.url.queryParameters['cursor'] == 'opaque-next';
          return http.Response(
            jsonEncode({
              'comments': [
                {'id': '1', 'author': '作者一', 'text': '评论一', 'likes': 3},
                {
                  'id': next ? '3' : '2',
                  'author': '作者二',
                  'text': next ? '下一页评论' : '评论二',
                  'likes': 2,
                },
              ],
              'more': !next,
              'nextCursor': next ? '' : 'opaque-next',
              'total': 40,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(music.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentPanel(music: music, bvid: 'BV1B7411m7LV'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(SongCommentCard),
        findsNWidgets(2),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      final more = find.text('加载更多 · 已加载 2 / 40');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(calls.last.queryParameters['cursor'], 'opaque-next');
      expect(calls.last.queryParameters['page'], '2');
      expect(find.byType(SongCommentCard), findsNWidgets(3));
      expect(find.text('下一页评论'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
