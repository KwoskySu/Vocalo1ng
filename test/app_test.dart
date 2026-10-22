import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/main.dart';
import 'package:vocashelf/services/library.dart';
import 'package:vocashelf/models/song.dart';
import 'package:vocashelf/widgets/share_card.dart';

void main() {
  testWidgets('share card fits a narrow phone with a long lyric excerpt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final song = seedSongs.first.copyWith(
      lyrics: '分享摘录\n' * 20,
      review: '个人听后感。' * 40,
      lyricCredit: '歌词来源',
      rating: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShareCardDialog(song: song)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['乐评卡', '收藏卡']) {
      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'mobile can favorite, search personal notes and add a real user entry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final library = Library(await SharedPreferences.getInstance())..load();
      await tester.pumpWidget(
        VocaShelfApp(library: library, showAudio: false, online: false),
      );
      await tester.ensureVisible(find.byTooltip('收藏歌曲').first);
      await tester.tap(find.byTooltip('收藏歌曲').first);
      await tester.pumpAndSettle();
      expect(library.songs.first.favorite, isTrue);
      final journalSearch = find.widgetWithText(TextField, '搜索个人手记');
      await tester.ensureVisible(journalSearch);
      await tester.enterText(journalSearch, 'ワールドイズマイン');
      await tester.pumpAndSettle();
      expect(
        find
            .text('ワールドイズマイン', findRichText: false)
            .evaluate()
            .where((e) => e.widget is Text)
            .length,
        1,
      );
      expect(find.text('ローリンガール'), findsNothing);
      await tester.tap(find.byTooltip('添加歌曲'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '我的测试歌曲');
      await tester.enterText(fields.at(1), '创作者');
      await tester.enterText(fields.at(2), '初音未来');
      await tester.ensureVisible(find.text('添加到曲库'));
      await tester.tap(find.text('添加到曲库'));
      await tester.pumpAndSettle();
      expect(library.songs.first.title, '我的测试歌曲');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop detail saves notes and renders all share templates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final library = Library(await SharedPreferences.getInstance())..load();
    await tester.pumpWidget(
      VocaShelfApp(library: library, showAudio: false, online: false),
    );
    await tester.tap(find.text('ワールドイズマイン'));
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, '写下你的听后感，只有你能看到…');
    await tester.ensureVisible(note);
    await tester.enterText(note, '这是一份自己的听歌记录。');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(library.songs.first.review, '这是一份自己的听歌记录。');
    await tester.ensureVisible(find.text('生成分享卡'));
    await tester.tap(find.text('生成分享卡'));
    await tester.pumpAndSettle();
    expect(find.text('导出高清 PNG'), findsOneWidget);
    for (final label in ['乐评卡', '收藏卡', '歌词卡']) {
      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
