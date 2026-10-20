import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/lyrics.dart';
import '../services/playback.dart';
import '../services/song_theme.dart';
import '../services/lyric_menu.dart';
import 'lyric_text_motion.dart';

const sceneNames = [
  '素纸诗行',
  '透视剧场',
  '双向对流',
  '星河漫游',
  '光速隧道',
  '行星轨道',
  '电影字幕',
  '错位海报',
  '纵向诗笺',
];

/// Bounded native paragraph cache. No outgoing lyric trees, raster snapshots,
/// image buffers, saveLayer, or render-to-texture history.
class SceneTextCache {
  final _items = LinkedHashMap<String, TextPainter>();
  final _segments = <TextPainter, List<Rect>>{};
  List<Rect> segments(TextPainter p, String text) =>
      _segments[p] ??= textMotionSegments(p, text);
  int get length => _items.length;
  TextPainter get(
    String text,
    double size,
    double width,
    Color ink, {
    bool serif = false,
    bool bold = true,
    TextAlign align = TextAlign.center,
  }) {
    final safe = String.fromCharCodes(text.runes.take(512));
    final key = '$safe|$size|$width|${ink.toARGB32()}|$serif|$bold|$align';
    final found = _items.remove(key);
    if (found != null) {
      _items[key] = found;
      return found;
    }
    final p = TextPainter(
      text: TextSpan(
        text: safe,
        style: TextStyle(
          fontSize: size,
          height: 1.25,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          fontFamily: serif ? 'NotoSerifSC' : 'NotoSansSC',
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 4,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, width));
    _items[key] = p;
    while (_items.length > 36) {
      final old = _items.remove(_items.keys.first)!;
      _segments.remove(old);
      old.dispose();
    }
    return p;
  }

  void dispose() {
    for (final p in _items.values) {
      p.dispose();
    }
    _items.clear();
    _segments.clear();
  }
}

class ImmersiveScene extends StatefulWidget {
  const ImmersiveScene({
    super.key,
    required this.playback,
    required this.lines,
    required this.translations,
    required this.active,
    required this.mode,
    required this.fontScale,
    required this.motion,
    required this.bilingual,
  });
  final Playback playback;
  final List<LyricLine> lines;
  final List<String?> translations;
  final int active, mode;
  final double fontScale;
  final bool motion, bilingual;
  @override
  State<ImmersiveScene> createState() => _ImmersiveSceneState();
}

class _ImmersiveSceneState extends State<ImmersiveScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final StreamSubscription<bool> playingSubscription;
  final cache = SceneTextCache();
  double lineChangedAt = 0;
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  );
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    playingSubscription = widget.playback.player.stream.playing.listen((_) {
      if (mounted) {
        _sync();
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run =
        foreground &&
        TickerMode.valuesOf(context).enabled &&
        widget.motion &&
        widget.playback.player.state.playing &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !clock.isAnimating) {
      clock.repeat();
    } else if (!run && clock.isAnimating) {
      clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ImmersiveScene old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) lineChangedAt = clock.value * 86400;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    playingSubscription.cancel();
    clock.dispose();
    cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.active;
    final text = i >= 0 && i < widget.lines.length
        ? widget.lines[i].text
        : widget.playback.current?.title ?? '等待歌词';
    return Semantics(
      container: true,
      label: [
        text,
        if (widget.bilingual && i >= 0 && i < widget.translations.length)
          widget.translations[i] ?? '',
      ].where((v) => v.isNotEmpty).join('\n'),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(
            widget,
            cache,
            clock,
            songAppearance.preset.seed,
            songAppearance.preset.accent,
            MediaQuery.devicePixelRatioOf(context),
            foreground &&
                TickerMode.valuesOf(context).enabled &&
                !MediaQuery.disableAnimationsOf(context),
            () =>
                (((clock.value * 86400 - lineChangedAt + 86400) % 86400) /
                        (.9 / lyricMenu.textMotionSpeed))
                    .clamp(0.0, 1.0),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(
    this.scene,
    this.cache,
    this.clock,
    this.seed,
    this.accent,
    this.dpr,
    this.allowMotion,
    this.entrance,
  ) : playing = scene.playback.player.state.playing,
      super(repaint: clock);
  final ImmersiveScene scene;
  final bool playing;
  final SceneTextCache cache;
  final Animation<double> clock;
  final Color seed, accent;
  final double dpr;
  final bool allowMotion;
  final double Function() entrance;
  double viewportHeight = 0;
  String text(int delta) {
    final i = scene.active + delta;
    return i >= 0 && i < scene.lines.length
        ? scene.lines[i].text
        : delta == 0
        ? scene.playback.current?.title ?? '等待歌词'
        : '';
  }

  void label(
    Canvas c,
    String text,
    Offset center,
    double font,
    double width,
    Color ink, {
    double angle = 0,
    bool serif = false,
    TextAlign align = TextAlign.center,
    bool animatedText = false,
    double animationDelay = 0,
  }) {
    if (text.isEmpty) return;
    // Quantization prevents continuous font-size glyph atlas growth.
    final size = (math.min(font * dpr, 136) / 2).round() * 2 / dpr;
    final p = cache.get(
      text,
      size.clamp(9, 136),
      width.floorToDouble(),
      ink,
      serif: serif,
      align: align,
    );
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final current = text == this.text(0) || animatedText;
    if (current) c.scale(math.min(1.0, viewportHeight * .25 / p.height));
    c.translate(-p.width / 2, -p.height / 2);
    if (current) {
      paintLyricMotion(
        c,
        p,
        () => cache.segments(p, text),
        effect: lyricMenu.textMotion,
        progress: ((entrance() - animationDelay) / (1 - animationDelay)).clamp(
          0.0,
          1.0,
        ),
        phase: clock.value * 86400 * lyricMenu.textMotionSpeed,
        amount: lyricMenu.textMotionAmount,
        animate: scene.motion && playing && allowMotion,
      );
    } else {
      p.paint(c, Offset.zero);
    }
    c.restore();
  }

  @override
  void paint(Canvas c, Size s) {
    viewportHeight = s.height;
    final mode = scene.mode.clamp(0, 8), family = mode ~/ 3, variant = mode % 3;
    final t = scene.motion && allowMotion ? clock.value * 86400 : 0.0;
    final light = mode == 0;
    final ink = light ? const Color(0xff24352f) : Colors.white;
    c.drawColor(
      light ? const Color(0xffecece2) : Color.lerp(seed, Colors.black, .89)!,
      BlendMode.src,
    );
    final w = s.width, h = s.height;
    final center = Offset(w * .5, h * .47);
    final font =
        math.min(w * .084, h * .11).clamp(18.0, 74.0) * scene.fontScale;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: .22);
    c.save();
    c.clipRect(Offset.zero & s);
    if (lyricMenu.immersiveStars && family != 1) {
      final dot = Paint();
      for (var i = 0; i < 64; i++) {
        final a = i * 2.3999632297 + t * .025;
        final depth = (i * .6180339 + t * .045) % 1;
        final radius = (.07 + depth * .66) * math.max(w, h);
        dot.color = (light ? ink : accent).withValues(alpha: .08 + depth * .25);
        c.drawCircle(
          center + Offset(math.cos(a) * radius, math.sin(a) * radius * .6),
          .5 + depth * 1.8,
          dot,
        );
      }
    }
    if (family == 0) {
      if (variant == 1) {
        for (var i = 0; i < 8; i++) {
          final y = h * .15 + i * h * .1;
          c.drawLine(Offset(0, y), Offset(w, y), pen);
        }
        for (var i = -4; i <= 4; i++) {
          c.drawLine(
            Offset(w * .5 + i * w * .22, h),
            Offset(w * .5 + i * w * .035, h * .2),
            pen,
          );
        }
      } else if (variant == 2) {
        for (var i = 0; i < 8; i++) {
          final x = w * (i / 7);
          c.drawLine(Offset(x, 0), Offset(x, h), pen);
        }
        c.drawCircle(
          center,
          math.min(w, h) * (.33 + .015 * math.sin(t * .35)),
          pen,
        );
      } else {
        c.drawLine(
          Offset(w * .08, h * .28),
          Offset(w * .92, h * .28),
          pen..color = ink.withValues(alpha: .16),
        );
        c.drawLine(Offset(w * .08, h * .68), Offset(w * .92, h * .68), pen);
      }
      for (final d in [-1, 1]) {
        final y = h * (d < 0 ? .26 : .72);
        label(
          c,
          text(d),
          Offset(center.dx + (variant == 2 ? d * w * .06 : 0), y),
          font * .47,
          w * .82,
          ink.withValues(alpha: d.abs() == 1 ? .36 : .14),
          angle: variant == 1 ? d * .035 : 0,
          serif: variant == 0,
        );
      }
      label(
        c,
        text(0),
        center.translate(variant == 2 ? math.sin(t * .3) * 8 : 0, 0),
        font,
        w * .84,
        ink,
        serif: variant == 0,
      );
    } else if (family == 1) {
      // Fixed count, deterministic seeds, no object growth or particle history.
      final count = variant == 1 ? 80 : 64;
      final dots = Paint();
      for (var i = 0; i < count; i++) {
        final a = i * 2.3999632297 + t * .025;
        final depth = ((i * .6180339 + t * .045) % 1);
        final radius = (.07 + depth * .66) * math.max(w, h);
        final x = center.dx + math.cos(a) * radius;
        final y =
            center.dy +
            math.sin(a) *
                radius *
                (variant == 0
                    ? .44
                    : variant == 2
                    ? .78
                    : 1);
        dots.color = Color.lerp(
          accent,
          Colors.white,
          (i % 5) / 5,
        )!.withValues(alpha: (.12 + depth * .65));
        c.drawCircle(Offset(x, y), (.5 + depth * 2.3), dots);
        if (variant == 1)
          c.drawLine(
            Offset(x, y),
            Offset(x + (x - center.dx) * .025, y + (y - center.dy) * .025),
            pen..color = dots.color,
          );
      }
      if (variant == 2) {
        for (var i = 0; i < 4; i++) {
          c.save();
          c.translate(center.dx, center.dy);
          c.rotate(t * .025 + i * .3);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: w * (.36 + i * .14),
              height: h * (.14 + i * .06),
            ),
            pen..color = accent.withValues(alpha: .18),
          );
          c.restore();
        }
      }
      label(
        c,
        text(-1),
        Offset(w * .5, h * .28),
        font * .43,
        w * .8,
        ink.withValues(alpha: .28),
      );
      label(c, text(0), center, font, w * .84, ink);
      label(
        c,
        text(1),
        Offset(w * .5, h * .69),
        font * .43,
        w * .8,
        ink.withValues(alpha: .38),
      );
    } else {
      // Authored typography per lyric index, no invented beat/word timings.
      final a = scene.active.isEven ? -.045 : .045;
      final rect = Rect.fromLTWH(w * .06, h * .24, w * .88, h * .44);
      if (variant == 0) {
        c.drawRect(
          Rect.fromLTWH(w * .06, h * .30, 5, h * .28),
          Paint()..color = accent,
        );
        c.drawRect(
          Rect.fromLTWH(w * .06, h * .70, w * .24, 3),
          Paint()..color = accent,
        );
        label(
          c,
          text(0),
          center,
          font * 1.15,
          w * .8,
          ink,
          align: TextAlign.left,
        );
      } else if (variant == 1) {
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(a);
        c.translate(-center.dx, -center.dy);
        c.drawRect(rect, pen..color = accent.withValues(alpha: .6));
        label(
          c,
          text(-1),
          Offset(w * .36, h * .26),
          font * .44,
          w * .6,
          accent.withValues(alpha: .45),
          angle: -a,
        );
        label(c, text(0), center, font * 1.1, w * .8, ink);
        label(
          c,
          text(1),
          Offset(w * .64, h * .70),
          font * .44,
          w * .6,
          accent.withValues(alpha: .6),
          angle: -a,
        );
        c.restore();
      } else {
        final chars = text(0).characters.take(30).toList();
        final rows = math.min(8, math.max(1, (h * .5 / (font * .8)).floor()));
        final cols = (chars.length / rows).ceil();
        for (var i = 0; i < chars.length; i++) {
          label(
            c,
            chars[i],
            Offset(
              center.dx + (cols / 2 - .5 - i ~/ rows) * font * .95,
              h * .23 + (i % rows) * font * .82,
            ),
            font * .72,
            font,
            ink,
            animatedText: true,
            animationDelay: i / math.max(1, chars.length) * .35,
          );
        }
      }
      label(
        c,
        '${(scene.active + 1).clamp(0, 999).toString().padLeft(3, '0')} / LYRIC FILM',
        Offset(w * .5, h * .16),
        12,
        w * .8,
        accent,
      );
    }
    final index = scene.active;
    if (scene.bilingual && index >= 0 && index < scene.translations.length) {
      label(
        c,
        scene.translations[index] ?? '',
        Offset(w * .5, h * .60),
        font * .40,
        w * .82,
        light ? ink.withValues(alpha: .65) : accent,
        animatedText: true,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene != scene ||
      old.seed != seed ||
      old.accent != accent ||
      old.allowMotion != allowMotion ||
      old.playing != playing;
}
