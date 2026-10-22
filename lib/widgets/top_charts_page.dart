import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/export.dart';
import '../services/top_charts.dart';
import 'top_chart_art.dart';
import 'top_chart_editors.dart';
import 'top_text_format.dart';
import 'top_blurred_cover.dart';
import 'wiki_reader.dart';

class TopChartsPage extends StatefulWidget {
  const TopChartsPage({
    super.key,
    this.store,
    this.exporter,
    this.active = true,
  });
  final TopCharts? store;
  final bool active;
  final Future<bool> Function(Uint8List bytes, String name, String mime)?
  exporter;
  @override
  State<TopChartsPage> createState() => _TopChartsPageState();
}

class _TopChartsPageState extends State<TopChartsPage>
    with WidgetsBindingObserver {
  late final store = widget.store ?? topCharts;
  final boundary = GlobalKey();
  String? selectedId;
  int previewPage = 0;
  int numberRevision = 0;
  bool showPreview = false, exporting = false;
  String? status;
  bool _missingImages = false;
  TopChart get chart =>
      store.charts.where((c) => c.id == selectedId).firstOrNull ??
      store.charts.first;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(store.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(store.flush());
    topBlurCache.clear();
    super.dispose();
  }

  void changed() {
    previewPage = previewPage.clamp(0, chart.pageCount - 1);
    store.changed();
  }

  @override
  void didHaveMemoryPressure() {
    clearTopImageBytes();
    topBlurCache.clear();
  }

  void message(String text) {
    if (mounted) setState(() => status = text);
  }

  Future<void> editEntry([TopEntry? entry, bool wiki = false]) async {
    final target = chart;
    if (entry == null && target.entries.length >= 100) {
      message('每份榜单最多100个条目，可新建另一份榜单。');
      return;
    }
    var source = entry;
    if (wiki) {
      source = await showDialog<TopEntry>(
        context: context,
        builder: (_) => const TopWikiPicker(),
      );
      if (source == null || !mounted) return;
    }
    if (!mounted) return;
    final result = await showDialog<TopEntry>(
      context: context,
      builder: (_) => TopEntryEditor(
        entry: source ?? TopEntry(),
        inherited: target.typography,
      ),
    );
    if (result == null || !mounted) return;
    final index = target.entries.indexWhere((e) => e.id == result.id);
    if (index < 0) {
      target.entries.add(result);
    } else {
      target.entries[index] = result;
    }
    changed();
  }

  void move(int from, int to) {
    final entries = chart.entries;
    if (to < 0 || to >= entries.length || from == to) return;
    entries.insert(to, entries.removeAt(from));
    changed();
  }

  void removeEntry(TopEntry entry) {
    final target = chart, index = chart.entries.indexOf(entry);
    target.entries.remove(entry);
    changed();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已移除条目'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            if (target.entries.length < 100) {
              target.entries.insert(
                math.min(index, target.entries.length),
                entry,
              );
              store.changed();
            }
          },
        ),
      ),
    );
  }

  Future<void> boardAction(String action) async {
    if (action == 'new' || action == 'copy') {
      if (store.charts.length >= 30) {
        message('最多保存30份榜单，请先导出备份或删除不需要的榜单。');
        return;
      }
      final next = action == 'copy' ? chart.copy(newId: true) : TopChart();
      if (action == 'copy') next.title = '${next.title} · 副本';
      store.charts.add(next);
      selectedId = next.id;
      previewPage = 0;
      changed();
      return;
    }
    if (action == 'json') {
      try {
        await exportFile(
          utf8.encode(encodeTopCharts([chart])),
          'Vocalo1ng-TOP.json',
          'application/json',
        );
      } catch (_) {
        message('榜单文件导出失败，请重试。');
      }
    } else if (action == 'import') {
      try {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: '榜单 JSON',
              extensions: ['json'],
              mimeTypes: ['application/json'],
            ),
          ],
        );
        if (file == null) return;
        if (await file.length() > 8 * 1024 * 1024) {
          throw const FormatException('文件超过8MB');
        }
        final imported = decodeTopCharts(await file.readAsString());
        if (store.charts.length + imported.length > 30) {
          throw const FormatException('导入后超过30份榜单');
        }
        final copies = imported.map((c) => c.copy(newId: true)).toList();
        if (!mounted || copies.isEmpty) return;
        store.charts.addAll(copies);
        selectedId = copies.first.id;
        previewPage = 0;
        changed();
        message('已导入${copies.length}份榜单，原有榜单保留。');
      } catch (e) {
        message('导入未完成：$e');
      }
    } else if (action == 'delete') {
      final target = chart;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除这份榜单？'),
          content: Text('“${target.title}”将被删除，其他榜单保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      store.charts.remove(target);
      if (store.charts.isEmpty) store.charts.add(TopChart());
      selectedId = store.charts.first.id;
      previewPage = 0;
      changed();
    }
  }

  Future<void> warmImages(TopChart c, int index) async {
    final providers = <ImageProvider>[];
    for (final entry in c.page(index)) {
      if (!c.showCover) continue;
      if (entry.coverData.isNotEmpty) {
        providers.add(
          ResizeImage(MemoryImage(topImageBytes(entry.coverData)), width: 320),
        );
      } else if (topImageUrl(entry.coverUrl).isNotEmpty) {
        providers.add(
          ResizeImage(NetworkImage(topImageUrl(entry.coverUrl)), width: 320),
        );
      }
    }
    if (c.backgroundData.isNotEmpty) {
      providers.add(
        ResizeImage(MemoryImage(topImageBytes(c.backgroundData)), width: 1200),
      );
    } else if (topImageUrl(c.backgroundUrl).isNotEmpty)
      providers.add(
        ResizeImage(NetworkImage(topImageUrl(c.backgroundUrl)), width: 1200),
      );
    await Future.wait(
      providers.map((p) async {
        try {
          await precacheImage(
            p,
            context,
            onError: (_, _) {
              _missingImages = true;
              message('部分图片加载失败，导出会显示占位图；可检查网址或上传本地图片。');
            },
          ).timeout(const Duration(seconds: 8));
        } catch (_) {
          _missingImages = true;
          message('部分图片未能及时加载，导出会显示占位图。');
        }
      }),
    );
  }

  Future<ui.Image> captureTopPage() async {
    await WidgetsBinding.instance.endOfFrame;
    if (topBlurCache.isPending) {
      await topBlurCache.settle();
      await WidgetsBinding.instance.endOfFrame;
    }
    final box =
        boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) throw StateError('预览尚未准备好');
    final pixels = box.size.width * box.size.height;
    final ratio = math.min(
      2.0,
      math.min(8192 / box.size.height, math.sqrt(12000000 / pixels)),
    );
    if (ratio < .75) throw StateError('本页内容过长，请减少每张条目数或缩短推荐理由');
    return box.toImage(pixelRatio: ratio);
  }

  Future<void> exportImages(bool all) async {
    final target = chart;
    if (target.entries.isEmpty) {
      message('先添加至少一个榜单条目。');
      return;
    }
    final original = previewPage;
    setState(() {
      exporting = true;
      showPreview = true;
      status = null;
      _missingImages = false;
    });
    final archive = Archive();
    var bytesTotal = 0;
    try {
      await store.flush();
      for (
        var i = all ? 0 : previewPage;
        i < (all ? target.pageCount : original + 1);
        i++
      ) {
        if (!mounted) return;
        setState(() => previewPage = i);
        await warmImages(target, i);
        if (!mounted) return;
        if (!widget.active) {
          throw StateError('导出已停止，请保持TOP页面打开后重试');
        }
        final image = await captureTopPage();
        final Uint8List bytes;
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('图片生成失败');
          bytes = data.buffer.asUint8List();
        } finally {
          image.dispose();
        }
        final name =
            'TOP-${target.limit}-${(i + 1).toString().padLeft(2, '0')}.png';
        if (!all) {
          final saved = await (widget.exporter ?? exportFile)(
            bytes,
            name,
            'image/png',
          );
          if (saved)
            message('当前榜单页已导出为 PNG。${_missingImages ? '部分图片未加载，已使用占位图。' : ''}');
        } else {
          bytesTotal += bytes.length;
          if (bytesTotal > 32 * 1024 * 1024) {
            throw StateError('图片总量超过32MB，请逐页导出，或减少背景图片');
          }
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
      if (all) {
        final data = ZipEncoder().encodeBytes(archive, level: 0);
        final saved = await (widget.exporter ?? exportFile)(
          data,
          'Vocalo1ng-TOP-${target.limit}.zip',
          'application/zip',
        );
        if (saved)
          message(
            '已导出${target.pageCount}张连续排名图片，保存在 ZIP 中。${_missingImages ? '部分图片未加载，已使用占位图。' : ''}',
          );
      }
    } catch (e) {
      message('导出未完成：$e');
    } finally {
      archive.clear();
      if (mounted) {
        setState(() {
          exporting = false;
          previewPage = original.clamp(0, target.pageCount - 1);
        });
      }
    }
  }

  Widget textField(
    String label,
    String value,
    void Function(String) assign, {
    int max = 300,
  }) {
    final role = {
      '表格大标题': 'title',
      '副标题': 'subtitle',
      '署名': 'author',
      '页脚文字': 'footer',
    }[label]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('${chart.id}:$label'),
              initialValue: value,
              decoration: InputDecoration(labelText: label, counterText: ''),
              maxLength: max,
              minLines: 1,
              maxLines: 4,
              onChanged: (v) {
                assign(v);
                changed();
              },
            ),
          ),
          TopTextFormatButton(
            label: label,
            style: chart.typography[role]!,
            onChanged: (v) {
              chart.typography[role] = v;
              changed();
            },
          ),
        ],
      ),
    );
  }

  Widget number(String label, int value, int max, void Function(int) assign) =>
      TextFormField(
        key: ValueKey('${chart.id}:$label:$numberRevision'),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, helperText: '1–$max'),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (v) =>
            (int.tryParse(v ?? '') ?? 0) < 1 ||
                (int.tryParse(v ?? '') ?? 0) > max
            ? '请输入1–$max'
            : null,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 1 && n <= max) {
            assign(n);
            changed();
          }
        },
      );

  Widget editor() => CustomScrollView(
    key: const PageStorageKey('top-editor'),
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '把喜欢，排成一份榜单。',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('编辑内容 → 搭配样式 → 导出图片。草稿自动保存在本机。'),
              const SizedBox(height: 18),
              textField('表格大标题', chart.title, (v) => chart.title = v),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('副标题、署名与页脚'),
                children: [
                  textField(
                    '副标题',
                    chart.subtitle,
                    (v) => chart.subtitle = v,
                    max: 500,
                  ),
                  textField(
                    '署名',
                    chart.author,
                    (v) => chart.author = v,
                    max: 200,
                  ),
                  textField(
                    '页脚文字',
                    chart.footer,
                    (v) => chart.footer = v,
                    max: 1000,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in [3, 10, 100])
                    ChoiceChip(
                      label: Text('Top $value'),
                      selected: chart.limit == value,
                      onSelected: (_) {
                        chart.limit = value;
                        numberRevision++;
                        changed();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: number(
                      '自定义数量',
                      chart.limit,
                      100,
                      (v) => chart.limit = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: number(
                      '每张条目数',
                      chart.perPage,
                      20,
                      (v) => chart.perPage = v,
                    ),
                  ),
                ],
              ),
              Text(
                '已编辑 ${chart.entries.length} 项 · 展示 ${chart.visible.length} 项 · 分为 ${chart.pageCount} 张\n切换数量会保留展示范围以外的条目。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      TopDesignEditor(chart: chart, onChanged: changed),
                ),
                icon: const Icon(Icons.palette_outlined),
                label: Text('样式与字体 · ${topStyleNames[chart.style]}'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => editEntry(null, true),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('从 VocaWiki 添加'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => editEntry(),
                    icon: const Icon(Icons.add),
                    label: const Text('手动添加'),
                  ),
                  TextButton(
                    onPressed: chart.entries.length >= chart.limit
                        ? null
                        : () {
                            while (chart.entries.length < chart.limit) {
                              chart.entries.add(
                                TopEntry(
                                  title: '待编辑条目 ${chart.entries.length + 1}',
                                ),
                              );
                            }
                            changed();
                          },
                    child: const Text('补足空白项'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('长按拖动排序；菜单可复制、移动到指定名次或移除。'),
            ],
          ),
        ),
      ),
      SliverReorderableList(
        itemCount: chart.entries.length,
        onReorderItem: move,
        itemBuilder: (context, i) {
          final entry = chart.entries[i];
          return Padding(
            key: ValueKey(entry.id),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              color: i >= chart.limit
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : null,
              child: ReorderableDelayedDragStartListener(
                index: i,
                child: ListTile(
                  leading: SizedBox(
                    width: 42,
                    height: 42,
                    child: TopCover(entry: entry),
                  ),
                  title: Text(
                    '${i + 1}. ${entry.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    i >= chart.limit
                        ? '暂不展示 · 内容已保留'
                        : entry.reason.isEmpty
                        ? '点击编辑推荐理由'
                        : entry.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => editEntry(entry),
                  trailing: PopupMenuButton<String>(
                    tooltip: '条目操作',
                    onSelected: (action) async {
                      if (action == 'remove') removeEntry(entry);
                      if (action == 'up') move(i, i - 1);
                      if (action == 'down') move(i, i + 1);
                      if (action == 'copy' && chart.entries.length < 100) {
                        chart.entries.insert(i + 1, entry.copy(newId: true));
                        changed();
                      }
                      if (action == 'source' && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => WikiReader(pageId: entry.pageId),
                          ),
                        );
                      }
                      if (action == 'position' && mounted) {
                        var rank = '${i + 1}';
                        final value = await showDialog<int>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('移动到名次'),
                            content: TextFormField(
                              initialValue: rank,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => rank = v,
                              decoration: InputDecoration(
                                helperText: '1–${chart.entries.length}',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  final n = int.tryParse(rank);
                                  if (n != null &&
                                      n >= 1 &&
                                      n <= chart.entries.length) {
                                    Navigator.pop(context, n - 1);
                                  }
                                },
                                child: const Text('移动'),
                              ),
                            ],
                          ),
                        );
                        if (value != null && mounted) move(i, value);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'up', child: Text('上移')),
                      const PopupMenuItem(value: 'down', child: Text('下移')),
                      const PopupMenuItem(
                        value: 'position',
                        child: Text('移动到名次…'),
                      ),
                      const PopupMenuItem(value: 'copy', child: Text('复制条目')),
                      if (entry.pageId > 0)
                        const PopupMenuItem(
                          value: 'source',
                          child: Text('查看百科原文'),
                        ),
                      const PopupMenuItem(value: 'remove', child: Text('移除条目')),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ],
  );

  Widget preview() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: '上一张',
              onPressed: previewPage == 0 || exporting
                  ? null
                  : () => setState(() => previewPage--),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '第 ${previewPage + 1} / ${chart.pageCount} 张',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: '下一张',
              onPressed: previewPage + 1 >= chart.pageCount || exporting
                  ? null
                  : () => setState(() => previewPage++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            key: const PageStorageKey('top-preview'),
            child: SizedBox(
              width: box.maxWidth,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: boundary,
                  child: TopChartArt(chart: chart, page: previewPage),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (!store.ready) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (store.error == null)
                const CircularProgressIndicator()
              else ...[
                Text(store.error!),
                TextButton(onPressed: store.reload, child: const Text('重试')),
              ],
            ],
          ),
        );
      }
      previewPage = previewPage.clamp(0, chart.pageCount - 1);
      return LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 940;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: chart.id,
                        isExpanded: true,
                        underline: const SizedBox(),
                        onChanged: exporting
                            ? null
                            : (id) => setState(() {
                                selectedId = id;
                                previewPage = 0;
                              }),
                        items: [
                          for (final c in store.charts)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.title.isEmpty ? '未命名榜单' : c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !exporting,
                      tooltip: '榜单管理',
                      onSelected: boardAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'new', child: Text('新建榜单')),
                        PopupMenuItem(value: 'copy', child: Text('复制榜单')),
                        PopupMenuItem(value: 'json', child: Text('导出可编辑 JSON')),
                        PopupMenuItem(
                          value: 'import',
                          child: Text('导入榜单 JSON'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('删除当前榜单')),
                      ],
                      icon: const Icon(Icons.more_horiz),
                    ),
                    if (!wide)
                      IconButton(
                        tooltip: showPreview ? '编辑榜单' : '预览榜单',
                        onPressed: exporting
                            ? null
                            : () => setState(() => showPreview = !showPreview),
                        icon: Icon(
                          showPreview
                              ? Icons.edit_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    PopupMenuButton<bool>(
                      enabled: !exporting,
                      tooltip: '导出榜单图片',
                      onSelected: exportImages,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: false, child: Text('当前页高清 PNG')),
                        PopupMenuItem(value: true, child: Text('全部图片 ZIP')),
                      ],
                      icon: const Icon(Icons.ios_share),
                    ),
                  ],
                ),
              ),
              if (exporting) const LinearProgressIndicator(),
              if (status != null || store.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.error ?? status!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.error != null)
                        TextButton(
                          onPressed: store.flush,
                          child: const Text('重试保存'),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: exporting,
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 360, child: editor()),
                            const VerticalDivider(width: 1),
                            Expanded(child: preview()),
                          ],
                        )
                      : IndexedStack(
                          index: showPreview ? 1 : 0,
                          children: [editor(), preview()],
                        ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
