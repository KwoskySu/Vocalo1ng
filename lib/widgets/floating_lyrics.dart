import 'package:flutter/material.dart';
import '../services/playback.dart';
import '../services/lyrics.dart';
import '../services/floating_style.dart';
import 'floating_platform.dart'
    if (dart.library.js_interop) 'floating_platform_web.dart';

Future<void> showFloatingLyrics(BuildContext context, Playback playback) async {
  final style = await FloatingStyle.load();
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('悬浮歌词样式'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < floatingStyles.length; i++)
                      ChoiceChip(
                        label: Text(floatingStyles[i]),
                        selected: style.mode == i,
                        onSelected: (_) => update(() => style.mode = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '始终与你喜欢的声音同行',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: style.size,
                    fontWeight: FontWeight.bold,
                    color: Color(floatingColors[style.color]),
                    fontFamily: floatingFonts[style.font],
                  ),
                ),
                Text('字号 ${style.size.round()}'),
                Slider(
                  value: style.size,
                  min: 16,
                  max: 40,
                  divisions: 24,
                  onChanged: (v) => update(() => style.size = v),
                ),
                Text('背景不透明度 ${(style.opacity * 100).round()}%'),
                Slider(
                  value: style.opacity,
                  min: 0,
                  max: 1,
                  onChanged: (v) => update(() => style.opacity = v),
                ),
                SwitchListTile(
                  title: const Text('显示翻译'),
                  value: style.translation,
                  onChanged: (v) => update(() => style.translation = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < floatingColors.length; i++)
                      ChoiceChip(
                        label: Icon(
                          Icons.circle,
                          color: Color(floatingColors[i]),
                          size: 20,
                        ),
                        selected: style.color == i,
                        onSelected: (_) => update(() => style.color = i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < floatingEffects.length; i++)
                      ChoiceChip(
                        label: Text(floatingEffects[i]),
                        selected: style.effect == i,
                        onSelected: (_) => update(() => style.effect = i),
                      ),
                  ],
                ),
                DropdownButton<int>(
                  value: style.font,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < floatingFonts.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          ['黑体', '宋体', '艺术手写', '等宽字体'][i],
                          style: TextStyle(fontFamily: floatingFonts[i]),
                        ),
                      ),
                  ],
                  onChanged: (i) => update(() => style.font = i!),
                ),
                const Text(
                  '经典桌面按整句时间渐变染色；双行模式预览下一句。Windows 使用独立置顶窗，支持的浏览器使用画中画，Android 使用应用内可拖动浮层。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('打开悬浮歌词'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  await style.save();
  if (await openSystemLyrics(playback, style)) return;
  if (!context.mounted) return;
  final overlay = Overlay.of(context);
  Offset offset = const Offset(24, 100);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          final size = MediaQuery.sizeOf(context);
          offset = Offset(
            (offset.dx + d.delta.dx).clamp(
              0,
              (size.width - 300).clamp(0, double.infinity),
            ),
            (offset.dy + d.delta.dy).clamp(
              0,
              (size.height - 180).clamp(0, double.infinity),
            ),
          );
          entry.markNeedsBuild();
        },
        child: Material(
          elevation: style.opacity == 0 ? 0 : 20,
          color:
              (style.mode == 4
                      ? const Color(0xFF200A30)
                      : const Color(0xFF0C1018))
                  .withValues(alpha: style.opacity),
          borderRadius: BorderRadius.circular(style.mode == 5 ? 4 : 20),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 14),
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭悬浮歌词',
                      onPressed: entry.remove,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: FloatingLine(playback: playback, style: style),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class FloatingLine extends StatefulWidget {
  const FloatingLine({super.key, required this.playback, required this.style});
  final Playback playback;
  final FloatingStyle style;
  @override
  State<FloatingLine> createState() => _FloatingLineState();
}

class _FloatingLineState extends State<FloatingLine> {
  String? id;
  List<LyricLine> lines = [];
  List<String?> translated = [];
  int generation = 0;
  @override
  void initState() {
    super.initState();
    widget.playback.addListener(changed);
    changed();
  }

  void changed() {
    final track = widget.playback.current;
    if (track == null || track.id == id) return;
    id = track.id;
    lines = [];
    translated = [];
    final request = ++generation;
    widget.playback.music
        .lyrics(track.id)
        .then((data) {
          if (mounted && request == generation) {
            setState(() {
              lines = parseLyrics(data.original);
              translated = alignTranslations(
                parseLyrics(data.original),
                data.translated,
              );
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    generation++;
    widget.playback.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: widget.playback.player.stream.position,
    initialData: widget.playback.player.state.position,
    builder: (context, snap) {
      final active = activeLyricIndex(lines, snap.data!);
      final style = widget.style;
      final original = active < 0
          ? widget.playback.current?.title ?? '等待播放'
          : lines[active].text;
      final color = Color(floatingColors[style.color]);
      final next = active >= 0 && active + 1 < lines.length
          ? lines[active + 1]
          : null;
      final start = active >= 0 ? lines[active].time!.inMilliseconds : 0;
      final progress = next?.time == null
          ? 1.0
          : ((snap.data!.inMilliseconds - start) /
                    (next!.time!.inMilliseconds - start).clamp(1, 1000000))
                .clamp(0.0, 1.0);
      Widget title = Text(
        original,
        textAlign: TextAlign.center,
        maxLines: style.mode == 5 ? 1 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: style.size,
          fontFamily: floatingFonts[style.font],
          fontStyle: style.effect == 4 ? FontStyle.italic : FontStyle.normal,
          letterSpacing: style.effect == 5 ? 4 : null,
          height: 1.5,
          fontWeight: style.effect == 1 ? FontWeight.w400 : FontWeight.w700,
          shadows: style.effect == 3
              ? [Shadow(color: color, blurRadius: 14)]
              : style.effect == 2
              ? const [
                  Shadow(color: Colors.black, offset: Offset(1, 1)),
                  Shadow(color: Colors.black, offset: Offset(-1, -1)),
                  Shadow(color: Colors.black, offset: Offset(1, -1)),
                  Shadow(color: Colors.black, offset: Offset(-1, 1)),
                ]
              : const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      );
      if (style.mode == 0 && active >= 0) {
        title = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [color, color, Colors.white, Colors.white],
            stops: [0, progress, progress, 1],
          ).createShader(rect),
          child: title,
        );
      }
      return Column(
        children: [
          if (style.mode == 6)
            Text(
              widget.playback.current?.title ?? '',
              style: TextStyle(
                color: color.withValues(alpha: .55),
                fontSize: style.size * .5,
              ),
            ),
          if (style.mode == 3 &&
              widget.playback.current?.cover.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.playback.music.image(widget.playback.current!.cover),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.album, color: Colors.white),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(key: ValueKey(original), child: title),
          ),
          if (style.translation &&
              active >= 0 &&
              active < translated.length &&
              translated[active] != null)
            Text(
              translated[active]!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.cyanAccent, height: 1.6),
            ),
          if ((style.mode == 1 || style.mode == 7) && next != null)
            Text(
              next.text,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: style.size * .7,
              ),
            ),
          if (style.mode == 7)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: color.withValues(alpha: .12),
                minHeight: 2,
              ),
            ),
          if (style.mode == 2 || style.mode == 3)
            ListenableBuilder(
              listenable: widget.playback,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: widget.playback.previous,
                    tooltip: '上一首',
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                  ),
                  StreamBuilder<bool>(
                    stream: widget.playback.player.stream.playing,
                    initialData: widget.playback.player.state.playing,
                    builder: (context, playing) => IconButton(
                      onPressed: widget.playback.player.playOrPause,
                      tooltip: '播放或暂停',
                      icon: Icon(
                        playing.data == true ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.playback.next,
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
