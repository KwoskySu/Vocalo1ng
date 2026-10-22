import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import '../models/top_chart.dart';
import '../services/wiki.dart';
import 'adaptive_dialog.dart';
import 'player_visuals.dart' show lyricFontFamilies, lyricFontNames;
import 'top_chart_art.dart';
import 'top_text_format.dart';

Future<String?> pickTopImage({bool background = false}) async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: '图片',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
        mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 8 * 1024 * 1024) {
    throw const FormatException('请选择8MB以内的图片');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40000000) {
      throw const FormatException('图片尺寸过大');
    }
    for (final target in background ? [1200, 768, 512] : [320, 192, 128]) {
      final ratio = math.min(
        1.0,
        target / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * ratio).round()),
        targetHeight: math.max(1, (descriptor.height * ratio).round()),
      );
      ui.Image? image;
      try {
        image = (await codec.getNextFrame()).image;
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null &&
            bytes.lengthInBytes <= (background ? 1024 * 1024 : 128 * 1024)) {
          return base64Encode(bytes.buffer.asUint8List());
        }
      } finally {
        image?.dispose();
        codec.dispose();
      }
    }
    throw const FormatException('图片无法压缩至合适大小，请换一张图片');
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

List<String> topWikiCovers(WikiDocument document) {
  final seen = <String>{};
  for (final image
      in html.parseFragment(document.html).querySelectorAll('img')) {
    final source = image.attributes['src'] ?? '';
    final uri = Uri.tryParse(source);
    final original = uri?.queryParameters['url'] ?? source;
    final target = Uri.tryParse(original);
    final width = int.tryParse(image.attributes['width'] ?? '') ?? 0;
    final height = int.tryParse(image.attributes['height'] ?? '') ?? 0;
    if (target == null ||
        !['http', 'https'].contains(target.scheme) ||
        target.userInfo.isNotEmpty ||
        target.path.toLowerCase().endsWith('.svg') ||
        (width > 0 && width < 100) ||
        (height > 0 && height < 70)) {
      continue;
    }
    seen.add(original);
    if (seen.length == 12) break;
  }
  return seen.toList();
}

class TopWikiPicker extends StatefulWidget {
  const TopWikiPicker({super.key, this.service});
  final WikiService? service;
  @override
  State<TopWikiPicker> createState() => _TopWikiPickerState();
}

class _TopWikiPickerState extends State<TopWikiPicker> {
  late final service = widget.service ?? WikiService();
  final query = TextEditingController();
  List<WikiEntry> results = [];
  bool busy = false;
  String? error;
  int revision = 0;
  WikiEntry? selected;
  List<String> images = [];
  int cover = 0;
  @override
  void dispose() {
    revision++;
    query.dispose();
    if (widget.service == null) service.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final keyword = query.text.trim();
    if (keyword.isEmpty) return;
    final request = ++revision;
    setState(() {
      busy = true;
      error = null;
      selected = null;
    });
    try {
      final found = await service.search(keyword);
      if (mounted && request == revision) setState(() => results = found);
    } catch (_) {
      if (mounted && request == revision) {
        setState(() => error = '百科搜索暂不可用，请重试；也可以手动添加条目。');
      }
    } finally {
      if (mounted && request == revision) setState(() => busy = false);
    }
  }

  Future<void> choose(WikiEntry entry) async {
    final request = ++revision;
    setState(() {
      selected = entry;
      busy = true;
      images = [];
      cover = 0;
      error = null;
    });
    try {
      final doc = await service.article(pageId: entry.pageId);
      if (mounted && request == revision) {
        setState(() => images = topWikiCovers(doc));
      }
    } catch (_) {
      if (mounted && request == revision) {
        setState(() => error = '封面暂未读取到，可选用标题后自行上传封面。');
      }
    } finally {
      if (mounted && request == revision) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: SizedBox(
      width: 660,
      height: 660,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '从 VocaWiki 选取',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                CloseButton(),
              ],
            ),
            TextField(
              controller: query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '搜索歌曲、作者或声库',
                suffixIcon: IconButton(
                  onPressed: search,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => search(),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
            Expanded(
              child: ListView(
                children: [
                  if (selected == null && results.isEmpty && !busy)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('搜索并选择条目后，可从正文图片中挑选封面。'),
                    ),
                  if (selected != null) ...[
                    ListTile(
                      title: Text(selected!.title),
                      subtitle: Text('VocaWiki · #${selected!.pageId}'),
                      trailing: TextButton(
                        onPressed: () {
                          revision++;
                          setState(() {
                            selected = null;
                            busy = false;
                          });
                        },
                        child: const Text('重新选择'),
                      ),
                    ),
                    if (images.isEmpty && !busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('没有合适图片，之后可手动设置封面。'),
                      ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          InkWell(
                            onTap: () => setState(() => cover = i),
                            child: Container(
                              width: 112,
                              height: 112,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: cover == i ? 3 : 1,
                                  color: cover == i
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TopCover(
                                entry: TopEntry(coverUrl: images[i]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    for (final entry in results)
                      ListTile(
                        title: Text(entry.title),
                        subtitle: Text(
                          entry.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => choose(entry),
                      ),
                  ],
                ],
              ),
            ),
            if (selected != null)
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.pop(
                        context,
                        TopEntry(
                          title: selected!.title,
                          wikiTitle: selected!.title,
                          pageId: selected!.pageId,
                          coverUrl: images.isEmpty ? '' : images[cover],
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('使用标题与选定封面'),
              ),
          ],
        ),
      ),
    ),
  );
}

class TopEntryEditor extends StatefulWidget {
  const TopEntryEditor({super.key, required this.entry, this.inherited});
  final TopEntry entry;
  final Map<String, TopTypography>? inherited;
  @override
  State<TopEntryEditor> createState() => _TopEntryEditorState();
}

class _TopEntryEditorState extends State<TopEntryEditor> {
  late TopEntry draft = widget.entry.copy();
  bool busy = false;
  String? error;
  final form = GlobalKey<FormState>();
  Future<void> image() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await pickTopImage();
      if (mounted && data != null) setState(() => draft.coverData = data);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  late final defaults = TopChart().typography;
  TopTypography textStyle(String role) =>
      draft.typography[role] ?? widget.inherited?[role] ?? defaults[role]!;
  Widget format(String label, String role) => TopTextFormatButton(
    label: label,
    style: textStyle(role),
    onChanged: (v) => setState(() => draft.typography[role] = v),
    onReset: () => setState(() => draft.typography.remove(role)),
  );
  Widget field(
    String label,
    String value,
    void Function(String) change, {
    int lines = 1,
    int max = 300,
  }) {
    final role = {
      '标题': 'item',
      '副标题 / 作者 / 声库': 'detail',
      '推荐理由': 'reason',
      '标签 / 自定义评分': 'badge',
    }[label];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('${draft.id}:$label:$revision'),
              initialValue: value,
              maxLength: max,
              decoration: InputDecoration(labelText: label),
              minLines: lines,
              maxLines: lines + 3,
              onChanged: change,
            ),
          ),
          if (role != null) format(label, role),
        ],
      ),
    );
  }

  int revision = 0;
  Future<void> wiki() async {
    final selected = await showDialog<TopEntry>(
      context: context,
      builder: (_) => const TopWikiPicker(),
    );
    if (selected != null && mounted) {
      setState(() {
        draft.title = selected.title;
        draft.wikiTitle = selected.wikiTitle;
        draft.pageId = selected.pageId;
        draft.coverUrl = selected.coverUrl;
        draft.coverData = '';
        revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: SizedBox(
      width: 640,
      height: 760,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: form,
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑榜单条目',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CloseButton(),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: TopCover(entry: draft),
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: busy ? null : image,
                          icon: const Icon(Icons.upload),
                          label: const Text('上传封面'),
                        ),
                        TextButton.icon(
                          onPressed: wiki,
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('从百科选取'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            draft.coverData = '';
                            draft.coverUrl = '';
                            revision++;
                          }),
                          child: const Text('清除封面'),
                        ),
                      ],
                    ),
                    if (error != null) Text(error!),
                    field('标题', draft.title, (v) => draft.title = v),
                    field(
                      '副标题 / 作者 / 声库',
                      draft.subtitle,
                      (v) => draft.subtitle = v,
                      max: 500,
                    ),
                    field(
                      '推荐理由',
                      draft.reason,
                      (v) => draft.reason = v,
                      lines: 3,
                      max: 3000,
                    ),
                    field(
                      '标签 / 自定义评分',
                      draft.badge,
                      (v) => draft.badge = v,
                      max: 80,
                    ),
                    field('封面图片网址', draft.coverUrl, (v) {
                      draft.coverUrl = v;
                      draft.coverData = '';
                    }, max: 3000),
                    Row(children: [const Text('名次数字样式'), format('名次', 'rank')]),
                    DropdownButtonFormField<int>(
                      initialValue: draft.frame,
                      decoration: const InputDecoration(labelText: '这个条目的边框样式'),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('沿用榜单全局'),
                        ),
                        for (final (i, name) in topFrameNames.indexed)
                          DropdownMenuItem(value: i, child: Text(name)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => draft.frame = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (draft.pageId > 0)
                      Text(
                        '选取自 VocaWiki #${draft.pageId} · ${draft.wikiTitle}\n修改显示标题、封面不会改写原条目。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(context, draft);
                        }
                      },
                icon: const Icon(Icons.check),
                label: const Text('保存条目'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TopDesignEditor extends StatefulWidget {
  const TopDesignEditor({
    super.key,
    required this.chart,
    required this.onChanged,
  });
  final TopChart chart;
  final VoidCallback onChanged;
  @override
  State<TopDesignEditor> createState() => _TopDesignEditorState();
}

class _TopDesignEditorState extends State<TopDesignEditor> {
  TopChart get c => widget.chart;
  String? status;
  bool busy = false;
  void change(VoidCallback action) {
    setState(action);
    widget.onChanged();
  }

  Widget swatch(int style) {
    final sample = TopChart()
      ..style = style
      ..coverBackdrop = [12, 13, 14, 15].contains(style)
      ..palette = c.palette
      ..title = c.title.isEmpty ? '我的 TOP' : c.title
      ..subtitle = 'STYLE PREVIEW'
      ..limit = 3
      ..perPage = 3
      ..footer = '';
    sample.entries.addAll(
      c.entries.isEmpty
          ? [TopEntry(title: '我的推荐', reason: '每一份喜欢，都值得被记录。')]
          : c.entries.take(3),
    );
    return SizedBox(
      width: 138,
      height: 196,
      child: InkWell(
        onTap: () => change(() {
          c.style = style;
          c.frame = 0;
          c.coverBackdrop = [12, 13, 14, 15].contains(style);
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: c.style == style ? 3 : 1,
              color: c.style == style
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: TopChartArt(chart: sample),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(topStyleNames[style], style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget select(
    String label,
    int value,
    List<String> items,
    void Function(int) apply,
  ) => DropdownButtonFormField<int>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final (i, name) in items.indexed)
        DropdownMenuItem(value: i, child: Text(name)),
    ],
    onChanged: (v) {
      if (v != null) change(() => apply(v));
    },
  );
  Widget slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) apply,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(value.toStringAsFixed(1)),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) => change(() => apply(v)),
      ),
    ],
  );
  Future<void> background() async {
    setState(() => busy = true);
    try {
      final data = await pickTopImage(background: true);
      if (data != null && mounted) {
        change(() {
          c.backgroundData = data;
          status = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: SizedBox(
      width: 740,
      height: 760,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '样式与字体',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                CloseButton(),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < topStyleNames.length; i++) swatch(i),
                    ],
                  ),
                  const SizedBox(height: 18),
                  select(
                    '配色',
                    c.palette,
                    topPaletteNames,
                    (v) => c.palette = v,
                  ),
                  const SizedBox(height: 14),
                  select('画幅（高度随内容适配）', c.format, [
                    '竖版',
                    '方形',
                    '横版',
                    '紧凑随内容',
                  ], (v) => c.format = v),
                  const SizedBox(height: 14),
                  select('列数', c.columns, [
                    '随样式适配',
                    '单列',
                    '双列',
                    '三列',
                    '四列',
                  ], (v) => c.columns = v),
                  const SizedBox(height: 14),
                  select('文字对齐', c.align, [
                    '左对齐',
                    '居中',
                    '右对齐',
                  ], (v) => c.align = v),
                  const SizedBox(height: 14),
                  select('封面形状', c.coverShape, [
                    '圆角',
                    '方形',
                    '圆形',
                  ], (v) => c.coverShape = v),
                  SwitchListTile(
                    title: const Text('显示封面'),
                    value: c.showCover,
                    onChanged: (v) => change(() => c.showCover = v),
                  ),
                  SwitchListTile(
                    title: const Text('完整显示封面（不裁切）'),
                    value: c.coverContain,
                    onChanged: (v) => change(() => c.coverContain = v),
                  ),
                  SwitchListTile(
                    title: const Text('显示名次'),
                    value: c.showRank,
                    onChanged: (v) => change(() => c.showRank = v),
                  ),
                  SwitchListTile(
                    title: const Text('显示推荐理由'),
                    value: c.showReason,
                    onChanged: (v) => change(() => c.showReason = v),
                  ),
                  slider('条目间距', c.gap, 4, 32, (v) => c.gap = v),
                  slider('卡片圆角', c.radius, 0, 32, (v) => c.radius = v),
                  slider(
                    '画布留白',
                    c.outerPadding,
                    8,
                    64,
                    (v) => c.outerPadding = v,
                  ),
                  const Divider(),
                  const Text(
                    '条目边框与玻璃材质',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  select('条目边框', c.frame, topFrameNames, (v) => c.frame = v),
                  slider(
                    '描边粗细',
                    c.borderWidth,
                    .5,
                    5,
                    (v) => c.borderWidth = v,
                  ),
                  slider(
                    '卡片内边距',
                    c.cardPadding,
                    6,
                    32,
                    (v) => c.cardPadding = v,
                  ),
                  SwitchListTile(
                    title: const Text('封面放大为模糊背景'),
                    value: c.coverBackdrop,
                    onChanged: (v) => change(() => c.coverBackdrop = v),
                  ),
                  slider(
                    '背景模糊',
                    c.backdropBlur,
                    0,
                    12,
                    (v) => c.backdropBlur = v,
                  ),
                  slider(
                    '背景放大',
                    c.backdropZoom,
                    1,
                    3,
                    (v) => c.backdropZoom = v,
                  ),
                  slider(
                    '封面背景可见度',
                    c.backdropOpacity,
                    0,
                    1,
                    (v) => c.backdropOpacity = v,
                  ),
                  slider(
                    '玻璃表面可见度',
                    c.glassOpacity,
                    .05,
                    .9,
                    (v) => c.glassOpacity = v,
                  ),
                  SwitchListTile(
                    title: const Text('显示标题分隔线'),
                    value: c.showDivider,
                    onChanged: (v) => change(() => c.showDivider = v),
                  ),
                  const Divider(),
                  const Text(
                    '榜单图背景',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    initialValue: c.customColor,
                    decoration: const InputDecoration(
                      labelText: '背景底色，例如 #F2EFE8（留空沿用样式）',
                    ),
                    onChanged: (v) {
                      if (v.isEmpty || topHex(v) != null) {
                        change(() => c.customColor = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: c.backgroundUrl,
                    decoration: const InputDecoration(labelText: '背景图片网址'),
                    maxLength: 3000,
                    onChanged: (v) => change(() {
                      c.backgroundUrl = v;
                      c.backgroundData = '';
                    }),
                  ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : background,
                        icon: const Icon(Icons.wallpaper),
                        label: const Text('上传背景图片'),
                      ),
                      TextButton(
                        onPressed: () => change(() {
                          c.backgroundData = '';
                          c.backgroundUrl = '';
                        }),
                        child: const Text('移除图片背景'),
                      ),
                    ],
                  ),
                  if (status != null) Text(status!),
                  slider(
                    '背景图片可见度',
                    c.backgroundOpacity,
                    0,
                    .8,
                    (v) => c.backgroundOpacity = v,
                  ),
                  const Divider(),
                  const Text(
                    '每部分字体独立修改',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final part in topTextParts.entries)
                    ExpansionTile(
                      title: Text(part.value),
                      trailing: TopTextFormatButton(
                        label: part.value,
                        style: c.typography[part.key]!,
                        onChanged: (v) =>
                            change(() => c.typography[part.key] = v),
                      ),
                      subtitle: Text(
                        '${lyricFontNames[c.typography[part.key]!.font]} · ${c.typography[part.key]!.size.round()}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              select(
                                '${part.value}字体',
                                c.typography[part.key]!.font,
                                lyricFontNames,
                                (v) => c.typography[part.key]!.font = v,
                              ),
                              slider(
                                '${part.value}字号',
                                c.typography[part.key]!.size,
                                9,
                                72,
                                (v) => c.typography[part.key]!.size = v,
                              ),
                              SwitchListTile(
                                title: const Text('加粗'),
                                value: c.typography[part.key]!.bold,
                                onChanged: (v) => change(
                                  () => c.typography[part.key]!.bold = v,
                                ),
                              ),
                              TextFormField(
                                key: ValueKey('color:${part.key}'),
                                initialValue: c.typography[part.key]!.color,
                                decoration: const InputDecoration(
                                  labelText: '文字颜色 #RRGGBB（留空自动）',
                                ),
                                onChanged: (v) {
                                  if (v.isEmpty || topHex(v) != null) {
                                    change(
                                      () => c.typography[part.key]!.color = v,
                                    );
                                  }
                                },
                              ),
                              Text(
                                '歌声与喜欢，都有自己的形状。',
                                style: TextStyle(
                                  fontFamily:
                                      lyricFontFamilies[c
                                          .typography[part.key]!
                                          .font],
                                  fontSize: 18,
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
          ],
        ),
      ),
    ),
  );
}
