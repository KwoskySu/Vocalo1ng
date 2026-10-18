import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/models/song.dart';
import 'package:vocashelf/widgets/share_card.dart';

void main() {
  testWidgets(
    'all share templates fit a narrow phone without rendering errors',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareCardDialog(
              song: seedSongs.first.copyWith(
                lyrics: '世界で一番おひめさま\n世界第一的公主殿下',
                review: 'A short personal review.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in [
        '黑白海报',
        '唱片票根',
        '霓虹舞台',
        '杂志封面',
        '极简便笺',
        '乐评卡',
        '收藏卡',
        '歌词卡',
      ]) {
        await tester.tap(find.byType(DropdownButton<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
