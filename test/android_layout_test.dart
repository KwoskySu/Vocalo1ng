import 'package:vocashelf/widgets/player_visual_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/lyrics.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/services/song_theme.dart';
import 'package:vocashelf/widgets/lyric_stage.dart';
import 'package:vocashelf/widgets/player_visuals.dart';
import 'package:vocashelf/widgets/accounts.dart';
import 'package:vocashelf/main.dart';
import 'package:vocashelf/services/library.dart';
import 'package:vocashelf/models/song.dart';
import 'package:vocashelf/widgets/share_card.dart';

void main() {
  testWidgets('visual editor keeps live preview visible while effects scroll', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: VisualOptions(
              previewBuilder: (_) => const PlayerVisualPreview(
                key: ValueKey('preview'),
                url: '',
                lines: [
                  LyricLine(Duration.zero, '歌声在这里流动'),
                  LyricLine(Duration(seconds: 4), '让喜欢拥有自己的形状'),
                ],
                translations: ['The song keeps flowing', 'A shape of your own'],
                active: 0,
              ),
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byKey(const ValueKey('preview')));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byKey(const ValueKey('preview'))), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'all navigation pages and share editor fit Android portrait and landscape with large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = Library(await SharedPreferences.getInstance())..load();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(360, 800), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.3),
            ),
            child: VocaShelfApp(
              key: ValueKey(size),
              library: library,
              showAudio: false,
              online: false,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        for (final icon in [
          Icons.explore_outlined,
          Icons.favorite_outline,
          Icons.menu_book_outlined,
          Icons.bookmarks_outlined,
          Icons.tune_rounded,
        ]) {
          final nav = find.byType(NavigationBar);
          await tester.tap(
            nav.evaluate().isEmpty
                ? find.byIcon(icon).first
                : find.descendant(of: nav, matching: find.byIcon(icon)).first,
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(
            tester.takeException(),
            isNull,
            reason: 'navigation $icon $size',
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShareCardDialog(
                song: seedSongs.first.copyWith(
                  lyrics: '长歌词分享。' * 20,
                  review: '一段听后感。' * 30,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'share $size');
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'bilingual lyric effects fit narrow and landscape Android panes',
    (tester) async {
      final lines = List.generate(
        8,
        (i) => LyricLine(Duration(seconds: i * 5), '世界で一番のお姫様、聞こえていますか？'),
      );
      for (final size in [const Size(320, 320), const Size(370, 170)]) {
        for (var style = 0; style < 13; style++) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: LyricStage(
                        key: ValueKey('$size:$style'),
                        lines: lines,
                        translations: List.filled(8, '世界第一的公主殿下，你听见了吗？'),
                        bilingual: true,
                        active: 3,
                        style: style,
                        foreground: Colors.white,
                        accent: Colors.cyan,
                        onSeek: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            tester.takeException(),
            isNull,
            reason: 'style=$style size=$size',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('3D covers respond to a finger drag without mouse hover', (
    tester,
  ) async {
    songAppearance.coverEffects.add('tilt');
    addTearDown(() => songAppearance.coverEffects.remove('tilt'));
    final animation = AnimationController(vsync: const TestVSync(), value: .2);
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: MotionCover(url: '', size: 140, motion: animation, style: 0),
        ),
      ),
    );
    final before = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.toString())
        .join();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MotionCover)),
    );
    await gesture.moveBy(const Offset(45, 25));
    await tester.pump();
    final after = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.toString())
        .join();
    expect(after, isNot(before));
    await gesture.up();
  });
  testWidgets('account tabs fit a short Android landscape viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final music = MusicService();
    addTearDown(music.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAccounts(context, music),
              child: const Text('accounts'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('accounts'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
