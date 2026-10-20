import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vocashelf/models/music.dart';
import 'package:vocashelf/services/playback.dart';
import 'package:vocashelf/services/lyrics.dart';
import 'package:vocashelf/services/lyric_menu.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/widgets/now_playing.dart';
import 'package:vocashelf/widgets/desktop_mode.dart';
import 'package:vocashelf/services/desktop_overlay.dart';
import 'package:vocashelf/widgets/immersive_stage.dart';
import 'package:vocashelf/widgets/immersive_scene.dart';
import 'package:vocashelf/widgets/lyric_text_motion.dart';
import 'package:vocashelf/services/audio_analysis.dart';
import 'package:vocashelf/widgets/audio_visualizer.dart';

class _Stream extends Fake implements PlayerStream {
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
}

class _Player extends Fake implements Player {
  bool isPlaying = false;
  final seeks = <Duration>[];
  @override
  Future<void> seek(Duration value) async {
    seeks.add(value);
  }

  @override
  PlayerState get state => PlayerState(
    playing: isPlaying,
    duration: Duration(minutes: 4),
    position: Duration(seconds: 30),
  );
  @override
  PlayerStream get stream => _Stream();
}

class _Playback extends Fake implements Playback {
  final testPlayer = _Player();
  final testMusic = _Music();
  @override
  Player get player => testPlayer;
  @override
  MusicService get music => testMusic;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  String? get analysisSource => 'test-audio.wav';
  @override
  bool get loading => false;
  @override
  String? get error => null;
  @override
  PlayMode get mode => PlayMode.sequential;
  @override
  MusicTrack get current =>
      const MusicTrack(id: 'test', title: '沉浸式歌词', artist: '初音未来');
}

class _Music extends MusicService {
  @override
  String image(String url) => '';
  @override
  Future<({String original, String translated})> lyrics(String id) async => (
    original: '[00:00]前の言葉\n[00:04]この歌声\n[00:08]次の言葉',
    translated: '[00:00]上一句\n[00:04]愿歌声传达到明日的天空\n[00:08]下一句',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    lyricMenu.immersiveMotion = true;
    lyricMenu.textMotion = 0;
  });
  test('text cache evicts paragraphs and releases on exit', () {
    final cache = SceneTextCache();
    for (var i = 0; i < 500; i++) {
      cache.get('歌词 $i', 32, 400, Colors.white);
      expect(cache.length, lessThanOrEqualTo(36));
    }
    cache.dispose();
    expect(cache.length, 0);
  });
  testWidgets(
    'reduced motion displays the complete lyric instead of a frozen entrance',
    (tester) async {
      final playback = _Playback()..testPlayer.isPlaying = true;
      final key = GlobalKey();
      lyricMenu.textMotion = 1;
      Future<List<int>> pixels({
        required bool motion,
        required bool reduced,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: RepaintBoundary(
                key: key,
                child: ImmersiveScene(
                  playback: playback,
                  lines: [LyricLine(Duration.zero, 'Complete lyric')],
                  translations: const ['完整歌词'],
                  active: 0,
                  mode: 0,
                  fontScale: 1,
                  motion: motion,
                  bilingual: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return (await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData();
          final bytes = data!.buffer.asUint8List().toList();
          image.dispose();
          return bytes;
        }))!;
      }

      final staticPixels = await pixels(motion: false, reduced: false);
      final reduced = await pixels(motion: true, reduced: true);
      expect(reduced, staticPixels);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'nine scenes survive portrait landscape and 4K with bounded layers',
    (tester) async {
      final playback = _Playback();
      playback.testPlayer.isPlaying = true;
      lyricMenu.immersiveStars = true;
      final semantics = tester.ensureSemantics();

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final size in [
        const Size(320, 700),
        const Size(800, 360),
        const Size(3840, 2160),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = size.width > 2000 ? 2 : 1;
        for (var mode = 0; mode < 9; mode++) {
          lyricMenu.immersiveStyle = mode;
          for (var i = 0; i < 15; i++) {
            lyricMenu.textMotion = i % textMotionNames.length;
            await tester.pumpWidget(
              MaterialApp(
                home: ImmersivePlayer(
                  playback: playback,
                  lines: [
                    for (var n = 0; n < 40; n++)
                      LyricLine(Duration(seconds: n), '声の向こうへ $n'),
                  ],
                  translations: [for (var n = 0; n < 40; n++) '让歌声穿过光 $n'],
                  active: i,
                  animation: const AlwaysStoppedAnimation(.2),
                  onExit: () {},
                  menu: const SizedBox(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.layers.length, lessThan(40));
            expect(
              tester.takeException(),
              isNull,
              reason: '$size / $mode / $i',
            );
          }
          expect(find.bySemanticsLabel('声の向こうへ 14\n让歌声穿过光 14'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }
      }
      semantics.dispose();
      lyricMenu.immersiveStars = false;
    },
  );
  testWidgets(
    'desktop resize updates native view before disk debounce; progress dimensions persist',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('vocalo1ng/desktop');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'show' ? true : null;
      });
      final overlay = desktopOverlayFor(_Playback());
      await overlay.load();
      await overlay.toggle(true);
      calls.clear();
      for (var i = 0; i < 12; i++) {
        overlay.layout['lyrics']![2] = .3 + i * .02;
        overlay.progressThickness = 12;
        overlay.progressThumb = 9;
        overlay.layout['progress']![2] = .7;
        overlay.save();
        await tester.pump(const Duration(milliseconds: 30));
      }
      final shows = calls.where((c) => c.method == 'show').toList();
      expect(shows.length, greaterThan(2));
      expect(shows.length, lessThan(12));
      expect((shows.last.arguments as Map)['autoFont'], true);
      expect((shows.last.arguments as Map)['progressThickness'], 12);
      await tester.pump(const Duration(milliseconds: 250));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('desktop.progressThickness'), 12);
      expect(prefs.getDouble('desktop.progressThumb'), 9);
      await overlay.close();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('all text motion previews paint', (tester) async {
    for (var i = 0; i < textMotionNames.length; i++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: TextMotionPreview(effect: i, speed: 1, amount: 1),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'audio analyzer sanitizes frames, shares leases and stops on last exit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <String>[];
      const channel = MethodChannel('vocalo1ng/audio');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'read')
          return {
            'available': true,
            'bands': [double.nan, 2.0, -1.0, .5],
            'waveform': [double.infinity, -2.0, .7],
          };
        return null;
      });
      final p = _Playback();
      p.testPlayer.isPlaying = true;
      final signal = audioAnalysisFor(p);
      final a = Object(), b = Object();
      signal.acquire(a);
      signal.acquire(b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls.where((m) => m == 'start'), hasLength(1));
      expect(signal.bands.take(4), [0, 1, 0, .5]);
      expect(signal.waveform[0], 0);
      expect(signal.waveform[1], -1);
      expect(signal.waveform[2], closeTo(.7, 1e-6));
      signal.release(a);
      expect(calls.where((m) => m == 'stop'), isEmpty);
      signal.release(b);
      await tester.pump();
      expect(calls.where((m) => m == 'stop'), hasLength(1));
      final count = calls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(calls.length, count);
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    },
  );
  testWidgets(
    'visualizer enters fullscreen and restores original state on close',
    (tester) async {
      const channel = MethodChannel('vocalo1ng/window');
      final calls = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.arguments as bool);
        return true;
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('vocalo1ng/audio'),
        (call) async => call.method == 'read' ? {'available': false} : null,
      );
      final p = _Playback();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showAudioVisualizer(c, p),
                child: const Text('频谱'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('频谱'));
      await tester.pumpAndSettle();
      expect(find.byType(AudioVisualizer), findsOneWidget);
      expect(calls, [true]);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(calls, [true, false]);
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('vocalo1ng/audio'),
        null,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop left click opens settings before activation and passes independent display options',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('vocalo1ng/desktop');
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'show' ? true : null;
      });
      final playback = _Playback();
      final overlay = desktopOverlayFor(playback);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DesktopQuickToggle(playback: playback)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('桌面模式 · 设置并开启'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopModeSettings), findsOneWidget);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('字体大小')),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('字体大小'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('字体大小')),
        const Offset(90, 0),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(FilterChip, '歌手'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(FilterChip, '歌手'));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, '开启桌面展示'));
      await tester.pump();
      final config =
          calls.firstWhere((c) => c.method == 'show').arguments as Map;
      expect(config['transparentBackground'], isTrue);
      expect(config['showArtist'], isFalse);
      expect(config['fontScale'], greaterThan(1));
      await tester.pumpWidget(const SizedBox());
      await overlay.close();
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('scrubbing previews locally and seeks exactly once on release', (
    tester,
  ) async {
    final playback = _Playback();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImmersiveTransport(
            playback: playback,
            ink: Colors.white,
            accent: Colors.teal,
            compact: false,
            onInteraction: () {},
            onSeek: () {},
          ),
        ),
      ),
    );
    final slider = find.byKey(const ValueKey('immersive-seek'));
    final box = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(box.left + box.width * .25, box.center.dy),
    );
    for (int i = 0; i < 25; i++) {
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(playback.testPlayer.seeks, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(playback.testPlayer.seeks, hasLength(1));
    expect(playback.testPlayer.seeks.single.inSeconds, greaterThan(60));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'immersion automatically enters fullscreen and restores it across repeated exits',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('vocalo1ng/window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NowPlaying(playback: _Playback(), onShare: (_, _) {}),
        ),
      );
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('歌词页菜单'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('进入沉浸模式'));
        await tester.pumpAndSettle();
        expect(find.byType(ImmersivePlayer), findsOneWidget);
        await tester.tap(find.byTooltip('退出沉浸模式'));
        await tester.pumpAndSettle();
        expect(find.byType(ImmersivePlayer), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(calls.map((c) => c.arguments).toList(), [
        for (int i = 0; i < 5; i++) ...[true, false],
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
