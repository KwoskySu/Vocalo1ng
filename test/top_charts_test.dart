import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/main.dart';
import 'package:vocashelf/services/library.dart';
import 'package:vocashelf/services/portable_data.dart';
import 'package:vocashelf/services/top_charts.dart';
import 'package:vocashelf/services/wiki.dart';
import 'package:vocashelf/widgets/top_chart_art.dart';
import 'package:vocashelf/widgets/top_chart_editors.dart';
import 'package:vocashelf/widgets/top_charts_page.dart';
import 'package:vocashelf/widgets/top_blurred_cover.dart';

TopChart fixture([int count = 17]) => TopChart()
  ..title = '我最喜欢的声音'
  ..author = '我的推荐'
  ..limit = count
  ..perPage = 4
  ..entries.addAll(
    List.generate(
      count,
      (i) => TopEntry(
        title: '作品 ${i + 1}',
        subtitle: '创作者 / 歌姬',
        reason: '这首歌的声音与故事，让我想一次次按下播放。',
        badge: '特别推荐',
      ),
    ),
  );

class _TopWiki extends WikiService {
  @override
  Future<List<WikiEntry>> search(String query) async => [
    const WikiEntry('百科测试歌曲', 123, '歌曲与创作者信息'),
  ];
  @override
  Future<WikiDocument> article({int? pageId, String? title}) async =>
      const WikiDocument(
        '百科测试歌曲',
        123,
        '<img width="500" src="https://voca.wiki/test-cover.jpg">',
        1,
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'custom counts preserve hidden entries and page ranks through persistence',
    () async {
      final store = TopCharts();
      await store.load();
      final chart = fixture(100);
      store.charts
        ..clear()
        ..add(chart);
      chart.limit = 17;
      expect(chart.pageCount, 5);
      expect(chart.page(4).single.title, '作品 17');
      chart.limit = 3;
      expect(chart.visible.length, 3);
      expect(chart.entries.length, 100);
      chart.limit = 100;
      expect(chart.page(24).last.title, '作品 100');
      await store.flush();
      final restored = TopCharts();
      await restored.load();
      expect(restored.charts.single.entries.length, 100);
      expect(restored.charts.single.pageCount, 25);
      store.dispose();
      restored.dispose();
    },
  );
  test(
    'all text roles and editable content survive JSON and malformed data stays intact',
    () async {
      final chart = fixture();
      for (final entry in chart.typography.entries) {
        entry.value
          ..font = 2
          ..size = 27
          ..color = '#112233'
          ..bold = true;
      }
      chart
        ..customColor = '#F2EEDC'
        ..backgroundUrl = 'https://voca.wiki/photo.png'
        ..columns = 3
        ..format = 2;
      final raw = encodeTopCharts([chart]);
      final copy = decodeTopCharts(raw).single;
      expect(copy.title, chart.title);
      expect(copy.entries.first.reason, chart.entries.first.reason);
      expect(
        copy.typography.values.every(
          (t) => t.font == 2 && t.size == 27 && t.bold,
        ),
        true,
      );
      expect(copy.backgroundUrl, chart.backgroundUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(topChartsKey, '{broken');
      final store = TopCharts();
      await store.load();
      await store.flush();
      expect(store.ready, false);
      expect(store.error, isNotNull);
      expect(prefs.getString(topChartsKey), '{broken');
      store.dispose();
      expect(
        parsePortableData(
          jsonEncode({
            'format': 'vocalo1ng',
            'version': 1,
            'data': {topChartsKey: raw},
          }),
        )[topChartsKey],
        raw,
      );
    },
  );
  test(
    'reload after external import does not overwrite newly imported charts',
    () async {
      final store = TopCharts();
      await store.load();
      await store.flush();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        topChartsKey,
        encodeTopCharts([fixture(9)..title = '导入的榜单']),
      );
      await store.reload();
      expect(store.charts.single.title, '导入的榜单');
      expect(store.charts.single.entries.length, 9);
      store.dispose();
    },
  );
  test(
    'wiki covers retain canonical originals while skipping icons and duplicates',
    () {
      const doc = WikiDocument(
        '测试',
        42,
        '<img width="48" src="https://voca.wiki/icon.png">'
            '<img width="400" src="http://127.0.0.1:5418/api/image?url=https%3A%2F%2Fvoca.wiki%2Fcover.png">'
            '<img src="https://voca.wiki/cover.png"><img src="https://voca.wiki/second.jpg">',
        1,
      );
      expect(topWikiCovers(doc), [
        'https://voca.wiki/cover.png',
        'https://voca.wiki/second.jpg',
      ]);
      final entry = TopEntry(
        title: '显示名',
        wikiTitle: doc.title,
        pageId: doc.pageId,
      );
      entry.title = '自定义显示标题';
      expect(entry.pageId, 42);
      expect(entry.wikiTitle, '测试');
    },
  );
  testWidgets(
    'wiki selection fills the title, source identity and chosen cover',
    (tester) async {
      TopEntry? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showDialog<TopEntry>(
                    context: context,
                    builder: (_) => TopWikiPicker(service: _TopWiki()),
                  );
                },
                child: const Text('选取百科'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('选取百科'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '测试');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.text('百科测试歌曲'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用标题与选定封面'));
      await tester.pumpAndSettle();
      expect(selected!.title, '百科测试歌曲');
      expect(selected!.pageId, 123);
      expect(selected!.coverUrl, 'https://voca.wiki/test-cover.jpg');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('style editor and independent typography fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chart = fixture(3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopDesignEditor(chart: chart, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('颁奖台'));
    await tester.pumpAndSettle();
    expect(chart.style, 1);
    await tester.scrollUntilVisible(
      find.text('表格大标题'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('表格大标题'));
    await tester.pumpAndSettle();
    expect(find.text('表格大标题字体'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'legacy automatic copy is removed while authored text and source data survive',
    () {
      final raw = fixture(1).toJson()..remove('canvasVersion');
      raw['title'] = '那些值得反复播放的歌';
      raw['subtitle'] = 'MY VOCALOID SELECTION';
      raw['footer'] = '每一份喜欢，都值得被记录。';
      final c = TopChart.fromJson(raw);
      expect(c.title, isEmpty);
      expect(c.subtitle, isEmpty);
      expect(c.footer, isEmpty);
      raw['title'] = '我的私人年度榜单';
      raw['footer'] = '写给自己的备注';
      final authored = TopChart.fromJson(raw);
      expect(authored.title, '我的私人年度榜单');
      expect(authored.footer, '写给自己的备注');
      authored.entries.first
        ..pageId = 714
        ..wikiTitle = '原始条目';
      authored.entries.first.typography['item'] = TopTypography(
        font: 2,
        size: 29,
        color: '#F01020',
        italic: true,
        tracking: 2,
      );
      authored.entries.first.frame = 9;
      final copy = decodeTopCharts(encodeTopCharts([authored])).single;
      expect(copy.entries.first.pageId, 714);
      expect(copy.entries.first.typography['item']!.italic, true);
      expect(copy.entries.first.frame, 9);
    },
  );
  testWidgets(
    'output canvas contains only authored copy and per-entry formatting is isolated',
    (tester) async {
      final c = fixture(2)
        ..footer = ''
        ..subtitle = ''
        ..author = '';
      c.typography['item']!.color = '#2233AA';
      c.entries.first
        ..pageId = 714
        ..wikiTitle = '来源条目';
      c.entries.first.typography['item'] = TopTypography(
        size: 24,
        color: '#CC0022',
        italic: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TopChartArt(chart: c)),
          ),
        ),
      );
      expect(find.textContaining('PERSONAL SELECTION'), findsNothing);
      expect(find.textContaining('ENTRIES'), findsNothing);
      expect(find.textContaining('资料选自'), findsNothing);
      expect(find.textContaining('voca.wiki'), findsNothing);
      expect(find.text('每一份喜欢，都值得被记录。'), findsNothing);
      expect(
        tester.widget<Text>(find.text('作品 1')).style!.color,
        const Color(0xffcc0022),
      );
      expect(
        tester.widget<Text>(find.text('作品 2')).style!.color,
        const Color(0xff2233aa),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'one text box can change its color and italic style without changing its peers',
    (tester) async {
      TopEntry? saved;
      final c = fixture(2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showDialog<TopEntry>(
                    context: context,
                    builder: (_) => TopEntryEditor(
                      entry: c.entries.first,
                      inherited: c.typography,
                    ),
                  );
                },
                child: const Text('编辑条目'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('编辑条目'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('设置「标题」字体与颜色'));
      await tester.tap(find.byTooltip('设置「标题」字体与颜色'));
      await tester.pumpAndSettle();
      final color = find.widgetWithText(TextFormField, '自定义颜色 #RRGGBB，留空自动');
      await tester.scrollUntilVisible(
        color,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(color, '#CC0022');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('斜体'),
        -150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('斜体'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存条目'));
      await tester.pumpAndSettle();
      expect(saved!.typography['item']!.color, '#CC0022');
      expect(saved!.typography['item']!.italic, true);
      expect(saved!.typography.containsKey('reason'), false);
      expect(c.entries[1].typography, isEmpty);
      expect(c.typography['item']!.color, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'blur thumbnails differ from originals and cached raster resources remain bounded',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 32, 64),
          Paint()..color = Colors.red,
        );
        canvas.drawRect(
          const Rect.fromLTWH(32, 0, 32, 64),
          Paint()..color = Colors.blue,
        );
        final pic = recorder.endRecording();
        final image = await pic.toImage(64, 64);
        pic.dispose();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final bytes = png!.buffer.asUint8List();
        final pool = TopBlurCache();
        final plain = await pool.request(MemoryImage(bytes), 0);
        final blurred = await pool.request(MemoryImage(bytes), 8);
        final p = await plain!.toByteData();
        final b = await blurred!.toByteData();
        expect(
          p!.buffer.asUint8List(),
          isNot(orderedEquals(b!.buffer.asUint8List())),
        );
        plain.dispose();
        blurred.dispose();
        for (var i = 0; i < 30; i++) {
          final sample = await pool.request(
            MemoryImage(Uint8List.fromList(bytes)),
            6,
          );
          sample?.dispose();
          expect(pool.length, lessThanOrEqualTo(24));
        }
        pool.clear();
        expect(pool.length, 0);
      });
    },
  );
  testWidgets(
    'TOP replaces the old navigation slot and settings open from upper right',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = Library(await SharedPreferences.getInstance())..load();
      await tester.pumpWidget(
        VocaShelfApp(library: library, showAudio: false, online: false),
      );
      await tester.tap(find.byIcon(Icons.emoji_events_outlined));
      await tester.pumpAndSettle();
      expect(find.text('TOP 榜单工坊'), findsOneWidget);
      final settings = find.byTooltip('设置');
      expect(tester.getCenter(settings).dx, greaterThan(330));
      expect(tester.getCenter(settings).dy, lessThan(90));
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.text('偏好与数据'), findsOneWidget);
      await tester.tap(find.byType(CloseButton).last);
      await tester.pumpAndSettle();
      expect(find.text('TOP 榜单工坊'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  testWidgets(
    'custom quantity accepts consecutive edits and editable title persists',
    (tester) async {
      final store = TopCharts();
      await store.load();
      store.charts
        ..clear()
        ..add(fixture(100));
      final id = store.charts.single.id;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TopChartsPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(ValueKey('$id:自定义数量:0'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '17');
      await tester.pump();
      await tester.enterText(field, '18');
      await tester.pump();
      expect(store.charts.single.limit, 18);
      expect(store.charts.single.entries.length, 100);
      final title = find.byKey(ValueKey('$id:表格大标题'));
      await tester.ensureVisible(title);
      await tester.enterText(title, '年度私人推荐');
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.charts.single.title, '年度私人推荐');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await store.flush();
      store.dispose();
      final restored = TopCharts();
      await restored.load();
      expect(restored.charts.single.limit, 18);
      restored.dispose();
    },
  );
  testWidgets(
    'eighteen chart styles adapt to all formats and large fonts without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chart = fixture(3);
      for (var format = 0; format < 4; format++) {
        chart.format = format;
        for (var style = 0; style < topStyleNames.length; style++) {
          chart.style = style;
          if (style == 1) chart.typography['rank']!.size = 72;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(child: TopChartArt(chart: chart)),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${topStyleNames[style]} / $format',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('multi-page image export produces a ZIP of complete PNG images', (
    tester,
  ) async {
    final store = TopCharts();
    await store.load();
    final glass = fixture(7)
      ..perPage = 3
      ..style = 12
      ..coverBackdrop = true;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawCircle(const Offset(32, 32), 30, Paint()..color = Colors.pink);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      picture.dispose();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      for (final entry in glass.entries) {
        entry.coverData = base64Encode(png!.buffer.asUint8List());
      }
    });
    store.charts
      ..clear()
      ..add(glass);
    Uint8List? exported;
    final done = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopChartsPage(
            store: store,
            exporter: (bytes, name, mime) async {
              expect(name, 'Vocalo1ng-TOP-7.zip');
              expect(mime, 'application/zip');
              exported = bytes;
              done.complete();
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('导出榜单图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部图片 ZIP'));
    await tester.runAsync(() async {
      for (var i = 0; i < 150 && !done.isCompleted; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(done.isCompleted, true);
    final zip = ZipDecoder().decodeBytes(exported!);
    expect(zip.files.map((f) => f.name), [
      'TOP-7-01.png',
      'TOP-7-02.png',
      'TOP-7-03.png',
    ]);
    for (final f in zip.files) {
      final bytes = f.content as List<int>;
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(Uint8List.fromList(bytes));
      expect(header.getUint32(16), 1280);
      expect(header.getUint32(20), greaterThan(1000));
    }
    expect(store.charts.single.entries.length, 7);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await store.flush();
    store.dispose();
  });
}
