import 'adaptive_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/playback.dart';
import '../services/live_feed.dart';
import 'song_detail.dart';
import 'desktop_mode.dart';

const liveModes = [
  '歌曲信息卡',
  '透明双语字幕',
  '聚焦三行 · 渐隐',
  '电台信息条',
  '旋转唱片',
  '纵向海报',
  '描边聚光',
  '黑白切片',
  '霓虹边界',
  '透明磁带',
  '磨砂玻璃',
  '极简进度',
];
Future<void> showLiveMode(BuildContext context, Playback playback) =>
    showDialog<void>(
      context: context,
      builder: (_) => AdaptiveDialog(
        child: SizedBox(
          width: 980,
          height: 720,
          child: LiveMode(playback: playback),
        ),
      ),
    );

class LiveMode extends StatefulWidget {
  const LiveMode({super.key, required this.playback});
  final Playback playback;
  @override
  State<LiveMode> createState() => _LiveModeState();
}

class _LiveModeState extends State<LiveMode> {
  Timer? timer;
  late final LiveFeed feed;
  String? url, error;
  String line = '', translation = '', next = '', previous = '';
  int mode = 0,
      color = 0,
      font = 0,
      alignment = 1,
      coverShape = 0,
      backgroundStyle = 0,
      textEffect = 0;
  double size = 32,
      opacity = 0,
      coverSize = 160,
      translationScale = .57,
      titleScale = .55;
  bool hide = false, bilingual = true, coverVisible = true;
  static const colors = [
    Colors.white,
    Color(0xffa2f4ed),
    Color(0xffffe594),
    Color(0xffffa2d5),
    Color(0xffc4afff),
  ];
  @override
  void initState() {
    super.initState();
    feed = liveFeedFor(widget.playback);
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      mode = (prefs.getInt('live.mode') ?? 0).clamp(0, liveModes.length - 1);
      size = (prefs.getDouble('live.size') ?? 32).clamp(18, 64);
      opacity = (prefs.getDouble('live.opacity') ?? 0).clamp(0, 1);
      hide = prefs.getBool('live.hide') ?? false;
      bilingual = prefs.getBool('live.bilingual') ?? true;
      color = (prefs.getInt('live.color') ?? 0).clamp(0, 4);
      font = (prefs.getInt('live.font') ?? 0).clamp(0, 5);
      coverSize = (prefs.getDouble('live.coverSize') ?? 160).clamp(40, 260);
      translationScale = (prefs.getDouble('live.translationScale') ?? .57)
          .clamp(.3, 1);
      titleScale = (prefs.getDouble('live.titleScale') ?? .55).clamp(.3, 1);
      coverShape = (prefs.getInt('live.coverShape') ?? 0).clamp(0, 4);
      backgroundStyle = (prefs.getInt('live.backgroundStyle') ?? 0).clamp(0, 5);
      textEffect = (prefs.getInt('live.textEffect') ?? 0).clamp(0, 4);
      coverVisible = prefs.getBool('live.coverVisible') ?? true;
      alignment = (prefs.getInt('live.align') ?? 1).clamp(0, 2);
    });
    configureFeed();
    feed.start();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => sync());
    sync();
  }

  void configureFeed() {
    feed.settings = {
      'mode': mode,
      'size': size,
      'opacity': opacity,
      'hide': hide,
      'translationVisible': bilingual,
      'color': '#${colors[color].toARGB32().toRadixString(16).substring(2)}',
      'font': [
        'sans-serif',
        'serif',
        'monospace',
        'cursive',
        'display',
        'rounded',
      ][font],
      'coverSize': coverSize,
      'coverShape': coverShape,
      'backgroundStyle': backgroundStyle,
      'translationScale': translationScale,
      'titleScale': titleScale,
      'textEffect': textEffect,
      'coverVisible': coverVisible,
      'align': ['left', 'center', 'right'][alignment],
    };
  }

  Future<void> save() async {
    configureFeed();
    final p = await SharedPreferences.getInstance();
    await p.setInt('live.mode', mode);
    await p.setDouble('live.size', size);
    await p.setDouble('live.opacity', opacity);
    await p.setBool('live.hide', hide);
    await p.setBool('live.bilingual', bilingual);
    await p.setInt('live.color', color);
    await p.setInt('live.font', font);
    await p.setInt('live.align', alignment);
    await p.setDouble('live.coverSize', coverSize);
    await p.setDouble('live.translationScale', translationScale);
    await p.setDouble('live.titleScale', titleScale);
    await p.setInt('live.coverShape', coverShape);
    await p.setInt('live.backgroundStyle', backgroundStyle);
    await p.setInt('live.textEffect', textEffect);
    await p.setBool('live.coverVisible', coverVisible);
  }

  Future<void> sync() async {
    if (!mounted) return;
    setState(() {
      line = feed.line;
      translation = feed.translation;
      next = feed.next;
      previous = feed.previous;
      url = feed.url;
      error = feed.error;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget _adjust(
    String label,
    double value,
    double min,
    double max,
    void Function(double) update,
  ) => Row(
    children: [
      SizedBox(width: 120, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) {
            setState(() => update(v));
            save();
          },
        ),
      ),
      SizedBox(
        width: 42,
        child: Text(value > 3 ? '${value.round()}' : value.toStringAsFixed(2)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.sensors),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '直播模式 · NOW PLAYING',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
            IconButton(
              tooltip: '复制 OBS 浏览器源地址',
              onPressed: url == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: url!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制直播地址')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
            ),
            CloseButton(onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              height: (size * (mode == 2 ? 8 : 6)).clamp(260, 600),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff181b25),
                border: mode >= 6
                    ? Border.all(
                        color: colors[color].withValues(alpha: .6),
                        width: mode == 8 ? 3 : 1,
                      )
                    : null,
                borderRadius: BorderRadius.circular(
                  mode == 7 || mode == 11 ? 2 : 18,
                ),
                gradient: LinearGradient(
                  colors: backgroundStyle == 1
                      ? [const Color(0xff101724), const Color(0xff101724)]
                      : backgroundStyle == 2
                      ? [const Color(0xff152d47), const Color(0xff4d2648)]
                      : backgroundStyle == 3
                      ? [const Color(0xff316d85), const Color(0xff7d487b)]
                      : backgroundStyle == 4
                      ? [const Color(0xff111827), const Color(0xff283856)]
                      : mode == 7
                      ? [Colors.black, const Color(0xff333333)]
                      : [const Color(0xff222631), const Color(0xff11141d)],
                ),
              ),
              child: Opacity(
                opacity: hide && !widget.playback.player.state.playing ? 0 : 1,
                child: Row(
                  children: [
                    if (coverVisible) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          coverShape == 1 || coverShape == 3
                              ? 200
                              : coverShape == 2
                              ? 0
                              : 14,
                        ),
                        child: SizedBox.square(
                          dimension: MediaQuery.sizeOf(context).width < 600
                              ? (coverSize * .4).clamp(40, 92)
                              : coverSize.clamp(40, 220),
                          child:
                              widget.playback.current?.cover.isNotEmpty == true
                              ? Image.network(
                                  widget.playback.music.image(
                                    widget.playback.current!.cover,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.album,
                                    color: Colors.white,
                                    size: 70,
                                  ),
                                )
                              : const Icon(
                                  Icons.album,
                                  color: Colors.white,
                                  size: 70,
                                ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                      ),
                    ],
                    Expanded(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: colors[color],
                          fontFamily: [
                            'NotoSansSC',
                            'NotoSerifSC',
                            'monospace',
                            'KaiTi',
                            'Impact',
                            'Segoe UI',
                          ][font],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: [
                              CrossAxisAlignment.start,
                              CrossAxisAlignment.center,
                              CrossAxisAlignment.end,
                            ][alignment],
                            children: [
                              if (mode == 0 || mode >= 3)
                                Text(
                                  '${widget.playback.current?.title ?? '等待播放'} · ${widget.playback.current?.artist ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: size * titleScale),
                                ),
                              if (mode == 2)
                                Text(
                                  previous,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: colors[color].withValues(alpha: .35),
                                    fontSize: size * .6,
                                  ),
                                ),
                              Text(
                                line,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: [
                                  TextAlign.left,
                                  TextAlign.center,
                                  TextAlign.right,
                                ][alignment],
                                style: TextStyle(
                                  fontSize: size,
                                  fontWeight: FontWeight.w800,
                                  shadows:
                                      textEffect == 1 ||
                                          textEffect == 3 ||
                                          mode == 6 ||
                                          mode == 8
                                      ? [
                                          Shadow(
                                            color: colors[color],
                                            blurRadius:
                                                textEffect == 3 || mode == 8
                                                ? 16
                                                : textEffect == 1
                                                ? 3
                                                : 4,
                                          ),
                                        ]
                                      : null,
                                  letterSpacing: mode == 7 || textEffect == 4
                                      ? 3
                                      : null,
                                  height: 1.5,
                                ),
                              ),
                              if (bilingual)
                                Text(
                                  translation,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: size * translationScale,
                                    height: 1.5,
                                  ),
                                ),
                              if (mode == 2)
                                Text(
                                  next,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: colors[color].withValues(alpha: .35),
                                    fontSize: size * .6,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '预览底色仅用于检查透明字幕。浏览器源背景可完全透明；关闭配置窗口后继续同步；使用下方开关停止发布。横条建议 OBS 浏览器源 1000 × 320；海报建议 480 × 720。',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in liveModes.indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: mode == i,
                    onSelected: (_) {
                      setState(() => mode = i);
                      save();
                    },
                  ),
              ],
            ),
            Row(
              children: [
                const Text('字号'),
                Expanded(
                  child: Slider(
                    value: size,
                    min: 18,
                    max: 64,
                    onChanged: (v) {
                      setState(() => size = v);
                      save();
                    },
                  ),
                ),
                Text('${size.round()}'),
                const SizedBox(width: 16),
                const Text('背景'),
                Expanded(
                  child: Slider(
                    value: opacity,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      setState(() => opacity = v);
                      save();
                    },
                  ),
                ),
                Text('${(opacity * 100).round()}%'),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final (i, c) in colors.indexed)
                  ChoiceChip(
                    label: Icon(Icons.circle, color: c),
                    selected: color == i,
                    onSelected: (_) {
                      setState(() => color = i);
                      save();
                    },
                  ),
                DropdownButton<int>(
                  value: font,
                  items: [
                    for (final (i, label) in [
                      '黑体',
                      '宋体',
                      '等宽',
                      '楷体',
                      '海报粗体',
                      '圆润无衬线',
                    ].indexed)
                      DropdownMenuItem(value: i, child: Text(label)),
                  ],
                  onChanged: (v) {
                    setState(() => font = v!);
                    save();
                  },
                ),
                DropdownButton<int>(
                  value: alignment,
                  items: [
                    for (final (i, label) in ['左对齐', '居中', '右对齐'].indexed)
                      DropdownMenuItem(value: i, child: Text(label)),
                  ],
                  onChanged: (v) {
                    setState(() => alignment = v!);
                    save();
                  },
                ),
              ],
            ),
            const Divider(),
            const Text('字体独立调整', style: TextStyle(fontWeight: FontWeight.bold)),
            _adjust(
              '翻译字号比例',
              translationScale,
              .3,
              1,
              (v) => translationScale = v,
            ),
            _adjust('歌曲标题字号比例', titleScale, .3, 1, (v) => titleScale = v),
            Wrap(
              spacing: 6,
              children: [
                for (final (i, label) in [
                  '清晰',
                  '投影',
                  '描边',
                  '霓虹',
                  '宽字距',
                ].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: textEffect == i,
                    onSelected: (_) {
                      setState(() => textEffect = i);
                      save();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('封面独立调整', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('显示封面'),
              value: coverVisible,
              onChanged: (v) {
                setState(() => coverVisible = v);
                save();
              },
            ),
            _adjust('封面大小', coverSize, 40, 260, (v) => coverSize = v),
            Wrap(
              spacing: 6,
              children: [
                for (final (i, label) in [
                  '圆角',
                  '圆形',
                  '方形',
                  '黑胶旋转',
                  '倾斜画框',
                ].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: coverShape == i,
                    onSelected: (_) {
                      setState(() => coverShape = i);
                      save();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('背景样式', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, label) in [
                  '完全透明',
                  '深色底板',
                  '双色渐变',
                  '极光流动',
                  '网格舞台',
                  '封面虚化',
                ].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: backgroundStyle == i,
                    onSelected: (_) {
                      setState(() {
                        backgroundStyle = i;
                        if (i > 0 && opacity == 0) opacity = .65;
                      });
                      save();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('双语歌词'),
              value: bilingual,
              onChanged: (v) {
                setState(() => bilingual = v);
                save();
              },
            ),
            SwitchListTile(
              title: const Text('暂停时隐藏'),
              value: hide,
              onChanged: (v) {
                setState(() => hide = v);
                save();
              },
            ),
            SwitchListTile(
              title: const Text('后台直播发布'),
              subtitle: const Text('关闭后浏览器源隐藏，停止发布当前歌曲'),
              value: feed.enabled,
              onChanged: (v) {
                if (v) {
                  configureFeed();
                  feed.start();
                } else {
                  feed.stop();
                }
                setState(() {});
              },
            ),
            if (desktopModeSupported)
              OutlinedButton.icon(
                onPressed: () => showDesktopMode(context, widget.playback),
                icon: const Icon(Icons.desktop_windows_outlined),
                label: const Text('桌面模式 · 透明穿透展示'),
              ),
            if (error != null) Text(error!),
            if (url != null) SelectableText(url!),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: url == null
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: url!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制 OBS 浏览器源地址')),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制直播地址'),
                ),
                OutlinedButton.icon(
                  onPressed: url == null
                      ? null
                      : () => openSource(
                          context,
                          Uri.parse('$url&interactive=1'),
                        ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开可拖动缩放窗口'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
