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
  int mode = 0, color = 0, font = 0, alignment = 1;
  double size = 32, opacity = 0;
  bool hide = false, bilingual = true;
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
      font = (prefs.getInt('live.font') ?? 0).clamp(0, 2);
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
      'font': ['sans-serif', 'serif', 'monospace'][font],
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
                  colors: mode == 7
                      ? [Colors.black, const Color(0xff333333)]
                      : mode == 8
                      ? [const Color(0xff201735), const Color(0xff103137)]
                      : [const Color(0xff222631), const Color(0xff11141d)],
                ),
              ),
              child: Opacity(
                opacity: hide && !widget.playback.player.state.playing ? 0 : 1,
                child: Row(
                  children: [
                    if ([0, 4, 5, 9, 10].contains(mode)) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          mode == 4 ? 100 : 14,
                        ),
                        child: SizedBox.square(
                          dimension: MediaQuery.sizeOf(context).width < 600
                              ? 56
                              : 120,
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
                          ][font],
                        ),
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
                                style: const TextStyle(fontSize: 14),
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
                                shadows: mode == 6 || mode == 8
                                    ? [
                                        Shadow(
                                          color: colors[color],
                                          blurRadius: mode == 8 ? 16 : 4,
                                        ),
                                      ]
                                    : null,
                                letterSpacing: mode == 7 ? 3 : null,
                                height: 1.5,
                              ),
                            ),
                            if (bilingual)
                              Text(
                                translation,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: size * .57,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '预览底色仅用于检查透明字幕。浏览器源背景可完全透明；关闭配置窗口后继续同步；使用下方开关停止发布。建议 OBS 浏览器源 1000 × 320。',
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
                    for (final (i, label) in ['黑体', '宋体', '等宽'].indexed)
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
