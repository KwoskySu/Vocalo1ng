import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lyrics.dart';
import '../services/playback.dart';
import '../services/lyric_menu.dart';
import 'adaptive_dialog.dart';
import 'immersive_scene.dart';
import 'lyric_text_motion.dart';
import 'immersive_transport.dart';
export 'immersive_transport.dart';

const immersiveStyles = sceneNames;
Future<void> showLyricMenuSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => AdaptiveDialog(
    child: SizedBox(
      width: 520,
      height: 650,
      child: ListenableBuilder(
        listenable: lyricMenu,
        builder: (context, _) => Column(
          children: [
            const ListTile(title: Text('歌词页菜单管理'), trailing: CloseButton()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('选择封面区常驻按钮；隐藏后仍可从右上角菜单打开。'),
                  for (final name in lyricTools)
                    CheckboxListTile(
                      title: Text(name),
                      value: lyricMenu.visible.contains(name),
                      onChanged: (v) {
                        if (v == true) {
                          lyricMenu.visible.add(name);
                        } else {
                          lyricMenu.visible.remove(name);
                        }
                        lyricMenu.save();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> showImmersiveSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => AdaptiveDialog(
    child: SizedBox(
      width: 620,
      height: 680,
      child: ListenableBuilder(
        listenable: lyricMenu,
        builder: (context, _) => Column(
          children: [
            const ListTile(title: Text('沉浸设置 · 选择舞台'), trailing: CloseButton()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('点击预览卡片应用样式，也可在沉浸舞台顶部直接切换。'),
                  const SizedBox(height: 12),
                  ImmersiveStylePicker(),
                  SwitchListTile(
                    title: const Text('叠加星海背景'),
                    subtitle: const Text('将空间排版、星海背景与文字动画组合，场景由你手动选择'),
                    value: lyricMenu.immersiveStars,
                    onChanged: (value) {
                      lyricMenu.immersiveStars = value;
                      lyricMenu.save();
                    },
                  ),
                  const Divider(),
                  const Text('文字动画 · 可与所有场景组合'),
                  TextMotionPreview(
                    effect: lyricMenu.textMotion,
                    speed: lyricMenu.textMotionSpeed,
                    amount: lyricMenu.textMotionAmount,
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (i, name) in textMotionNames.indexed)
                        ChoiceChip(
                          label: Text(name),
                          selected: lyricMenu.textMotion == i,
                          onSelected: (_) {
                            lyricMenu.textMotion = i;
                            lyricMenu.save();
                          },
                        ),
                    ],
                  ),
                  const Text('动画速度'),
                  Slider(
                    value: lyricMenu.textMotionSpeed,
                    min: .5,
                    max: 2,
                    onChanged: (v) {
                      lyricMenu.textMotionSpeed = v;
                      lyricMenu.save();
                    },
                  ),
                  const Text('动画幅度'),
                  Slider(
                    value: lyricMenu.textMotionAmount,
                    min: .25,
                    max: 1.5,
                    onChanged: (v) {
                      lyricMenu.textMotionAmount = v;
                      lyricMenu.save();
                    },
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  const Text('沉浸歌词大小'),
                  Slider(
                    value: lyricMenu.immersiveSize,
                    min: .65,
                    max: 1.6,
                    onChanged: (v) {
                      lyricMenu.immersiveSize = v;
                      lyricMenu.save();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('舞台动效'),
                    subtitle: const Text('关闭后保留排版与配色，降低图形负担'),
                    value: lyricMenu.immersiveMotion,
                    onChanged: (v) {
                      lyricMenu.immersiveMotion = v;
                      lyricMenu.save();
                    },
                  ),
                  const Text('场景与文字动画可以自由搭配。逐字效果仅编排入场，不替代歌曲的原有时间轴。'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class ImmersivePlayer extends StatefulWidget {
  const ImmersivePlayer({
    super.key,
    required this.playback,
    required this.lines,
    required this.translations,
    required this.active,
    required this.animation,
    required this.onExit,
    required this.menu,
    this.bilingual = true,
  });
  final Playback playback;
  final List<LyricLine> lines;
  final List<String?> translations;
  final int active;
  final Animation<double> animation;
  final VoidCallback onExit;
  final Widget menu;
  final bool bilingual;
  @override
  State<ImmersivePlayer> createState() => _ImmersivePlayerState();
}

class _ImmersivePlayerState extends State<ImmersivePlayer> {
  bool controls = true;
  Timer? hide;
  void reveal() {
    if (!mounted) return;
    if (!controls) setState(() => controls = true);
    hide?.cancel();
    hide = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.playback.player.state.playing)
        setState(() => controls = false);
    });
  }

  @override
  void initState() {
    super.initState();
    reveal();
  }

  @override
  void dispose() {
    hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onExit},
    child: Focus(
      autofocus: true,
      child: ListenableBuilder(
        listenable: lyricMenu,
        builder: (context, _) {
          final mode = lyricMenu.immersiveStyle.clamp(0, 8), light = mode == 0;
          final ink = light ? const Color(0xff24352f) : Colors.white;
          return Material(
            color: Colors.black,
            child: MouseRegion(
              onHover: (_) => reveal(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: reveal,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImmersiveScene(
                      playback: widget.playback,
                      lines: widget.lines,
                      translations: widget.translations,
                      active: widget.active,
                      mode: mode,
                      fontScale: lyricMenu.immersiveSize,
                      motion:
                          lyricMenu.immersiveMotion &&
                          !MediaQuery.disableAnimationsOf(context),
                      bilingual: widget.bilingual,
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: '退出沉浸模式',
                                  onPressed: widget.onExit,
                                  icon: Icon(
                                    Icons.close_fullscreen,
                                    color: ink,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.playback.current?.title ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: ink, fontSize: 12),
                                  ),
                                ),
                                PopupMenuButton<int>(
                                  tooltip: '切换沉浸场景',
                                  onOpened: reveal,
                                  onSelected: (v) {
                                    lyricMenu.immersiveStyle = v;
                                    lyricMenu.save();
                                    reveal();
                                  },
                                  itemBuilder: (_) => [
                                    for (final (i, name) in sceneNames.indexed)
                                      CheckedPopupMenuItem(
                                        value: i,
                                        checked: i == mode,
                                        child: Text(name),
                                      ),
                                  ],
                                  child: Chip(
                                    label: Text(
                                      MediaQuery.sizeOf(context).width < 600
                                          ? sceneNames[mode].split(' · ').last
                                          : sceneNames[mode],
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    avatar: const Icon(Icons.layers, size: 16),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '沉浸设置',
                                  onPressed: () =>
                                      showImmersiveSettings(context),
                                  icon: Icon(Icons.tune, color: ink),
                                ),
                                widget.menu,
                              ],
                            ),
                          ),
                          const Spacer(),
                          IgnorePointer(
                            ignoring: !controls,
                            child: AnimatedOpacity(
                              opacity: controls ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: ImmersiveTransport(
                                  playback: widget.playback,
                                  ink: ink,
                                  accent: light
                                      ? const Color(0xff267c70)
                                      : const Color(0xff9ee6db),
                                  compact:
                                      MediaQuery.sizeOf(context).height < 450,
                                  onInteraction: reveal,
                                  onSeek: reveal,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class ImmersiveStylePicker extends StatelessWidget {
  const ImmersiveStylePicker({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var family = 0; family < 3; family++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            ['空间歌词', '星海电台', '文字影像'][family],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var v = 0; v < 3; v++)
              ChoiceChip(
                selected: lyricMenu.immersiveStyle == family * 3 + v,
                label: Text(sceneNames[family * 3 + v].split(' · ').last),
                avatar: Icon(
                  [
                    Icons.view_agenda,
                    Icons.auto_awesome,
                    Icons.text_fields,
                  ][family],
                  size: 18,
                ),
                onSelected: (_) {
                  lyricMenu.immersiveStyle = family * 3 + v;
                  lyricMenu.save();
                },
              ),
          ],
        ),
        SizedBox(
          height: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _ScenePreview(family),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    ],
  );
}

class _ScenePreview extends CustomPainter {
  _ScenePreview(this.family);
  final int family;
  @override
  void paint(Canvas c, Size s) {
    c.drawColor(
      family == 0 ? const Color(0xffeae9de) : const Color(0xff111c29),
      BlendMode.src,
    );
    final p = Paint()..color = const Color(0xff8ed6cd);
    if (family == 1) {
      for (var i = 0; i < 32; i++)
        c.drawCircle(
          Offset((i * 73.0) % s.width, (i * 31.0) % s.height),
          i % 3 + 0.6,
          p,
        );
    }
    final t = TextPainter(
      text: TextSpan(
        text: family == 0
            ? '上一句\n   让歌声穿过光\n下一句'
            : family == 1
            ? '✧ 让歌声穿过光 ✧'
            : '声 / 光     001',
        style: TextStyle(
          color: family == 0 ? const Color(0xff334b43) : Colors.white,
          fontSize: family == 0 ? 16 : 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: s.width);
    t.paint(c, Offset((s.width - t.width) / 2, (s.height - t.height) / 2));
    t.dispose();
  }

  @override
  bool shouldRepaint(_ScenePreview old) => old.family != family;
}
