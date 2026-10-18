import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/services/lyrics.dart';
import 'package:vocashelf/services/queue_order.dart';
import 'package:vocashelf/widgets/lyric_stage.dart';

void main() {
  test('translation follows timestamps across missing lines and metadata', () {
    final original = parseLyrics('[00:01]one\n[00:04]two\n[00:08]three');
    expect(alignTranslations(original, '[ar:artist]\n[00:01.20]一\n[00:08]三'), [
      '一',
      null,
      '三',
    ]);
    expect(alignTranslations(original, 'untimed translation'), [
      null,
      null,
      null,
    ]);
  });
  test(
    'completion respects stop, loop and single while manual next advances',
    () {
      final order = QueueOrder();
      expect(order.next(2, 3, completed: true), isNull);
      order.mode = PlayMode.loop;
      expect(order.next(2, 3, completed: true), 0);
      expect(order.previous(0, 3), 2);
      order.mode = PlayMode.single;
      expect(order.next(1, 3, completed: true), 1);
      expect(order.next(1, 3), 2);
      expect(order.next(-1, 0), isNull);
    },
  );
  test('shuffle visits remaining tracks once and retains previous history', () {
    final order = QueueOrder(random: Random(12))..mode = PlayMode.shuffle;
    final visited = [0];
    for (var i = 0; i < 5; i++) {
      visited.add(order.next(visited.last, 6)!);
    }
    expect(visited.toSet().length, 6);
    expect(order.previous(visited.last, 6), visited[4]);
    order.reset();
    expect(order.previous(0, 6), isNull);
  });
  testWidgets('all lyric layouts retain bilingual text on a narrow screen', (
    tester,
  ) async {
    final lines = parseLyrics('[00:01]原文第一句\n[00:04]原文第二句');
    for (var style = 0; style < 13; style++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 342,
                height: 250,
                child: LyricStage(
                  key: ValueKey(style),
                  lines: lines,
                  translations: const ['Translation one', 'Translation two'],
                  bilingual: true,
                  active: 0,
                  style: style,
                  foreground: Colors.white,
                  accent: Colors.cyan,
                  onSeek: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('原文第一句'), findsOneWidget);
      expect(find.text('Translation one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
