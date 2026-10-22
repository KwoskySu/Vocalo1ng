import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/models/top_chart.dart';
import 'package:vocashelf/widgets/top_chart_art.dart';
import 'package:vocashelf/widgets/top_blurred_cover.dart';

void main() {
  testWidgets(
    'render eighteen TOP styles with bundled fonts and local sample covers',
    (tester) async {
      await tester.runAsync(() async {
        for (final family in [
          'NotoSansSC',
          'NotoSerifSC',
          'ZCOOLKuaiLe',
          'monospace',
        ]) {
          final font = FontLoader(family)
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    'assets/fonts/${family == 'monospace' ? 'NotoSansSC' : family}.ttf',
                  ).readAsBytes(),
                ),
              ),
            );
          await font.load();
        }
      });
      await tester.runAsync(() async {
        final font = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
        await font.load();
      });
      final images = <String>[];
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 256, 256),
            Paint()
              ..color = [
                const Color(0xff327f7b),
                const Color(0xffd17983),
                const Color(0xff40548b),
              ][i],
          );
          canvas.drawCircle(
            const Offset(175, 90),
            100,
            Paint()..color = Colors.white.withValues(alpha: .17),
          );
          canvas.drawCircle(
            const Offset(80, 210),
            100,
            Paint()..color = const Color(0xfff3ce82).withValues(alpha: .7),
          );
          final text = TextPainter(
            text: TextSpan(
              text: ['聲', '光', '夜'][i],
              style: const TextStyle(
                fontFamily: 'NotoSerifSC',
                color: Colors.white,
                fontSize: 115,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset((256 - text.width) / 2, 45));
          text.dispose();
          final picture = recorder.endRecording();
          final image = await picture.toImage(256, 256);
          picture.dispose();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          images.add(base64Encode(data!.buffer.asUint8List()));
        }
      });
      tester.view.physicalSize = const Size(1440, 3180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final charts = [
        for (var style = 0; style < topStyleNames.length; style++)
          TopChart()
            ..style = style
            ..coverBackdrop = [12, 13, 14, 15].contains(style)
            ..palette = style % 8
            ..limit = 3
            ..perPage = 3
            ..title = '把喜欢，排成一首诗。'
            ..subtitle = 'PERSONAL TOP 3 / 示例排版'
            ..author = 'MUSIC JOURNAL'
            ..entries.addAll([
              for (var i = 0; i < 3; i++)
                TopEntry(
                  title: ['穿过声音的森林', '属于我们的光', '把夜晚唱成星河'][i],
                  subtitle: '创作者 / 歌姬',
                  reason: '喜欢它的旋律，也喜欢故事里的自己。',
                  badge: ['心动首选', '循环播放', '私藏推荐'][i],
                  coverData: images[i],
                ),
            ]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: const Color(0xffdbe3df),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOP / 十八种喜欢的形状',
                        style: TextStyle(
                          fontFamily: 'NotoSansSC',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '样式示例 · 所有文字、封面、背景与分图均可编辑',
                        style: TextStyle(
                          fontFamily: 'NotoSansSC',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (var i = 0; i < charts.length; i++)
                            SizedBox(
                              width: 336,
                              height: 588,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      topStyleNames[i],
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansSC',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                      child: TopChartArt(chart: charts[i]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final data in images) {
          await precacheImage(
            ResizeImage(MemoryImage(topImageBytes(data)), width: 320),
            boundary.currentContext!,
          );
        }
      });
      await tester.runAsync(() async {
        await topBlurCache.settle();
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final target = File('E:/gpt-vocal/qa/0418/top-styles.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(data!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('TOP_VISUAL_QA'),
  );
}
