import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_analysis.dart';
import '../services/playback.dart';
import '../services/player_fullscreen.dart';
import '../services/song_theme.dart';
import 'immersive_transport.dart';

Future<void> showAudioVisualizer(
  BuildContext context,
  Playback playback,
) async {
  final original = playerFullscreenActive;
  // Enter while still in the user's gesture, before pushing an opaque route.
  unawaited(setPlayerFullscreen(true).catchError((_) {}));
  try {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => AudioVisualizer(playback: playback),
      ),
    );
  } finally {
    unawaited(setPlayerFullscreen(original).catchError((_) {}));
  }
}

class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({super.key, required this.playback});
  final Playback playback;
  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final signal = audioAnalysisFor(widget.playback);
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  int mode = 0;
  double strength = 1, width = 3;
  bool foreground = true;
  String? _lastStatus;
  bool? _lastAvailable;
  String? _lastTrack;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    signal.acquire(this);
    signal.addListener(sync);
  }

  void sync() {
    if (!mounted) return;
    final active =
        foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.playback.player.state.playing;
    if (active && !clock.isAnimating) {
      clock.repeat();
    } else if (!active) {
      clock.stop();
    }
    final track = widget.playback.current?.id ?? widget.playback.localName;
    if (_lastStatus != signal.status ||
        _lastAvailable != signal.available ||
        _lastTrack != track) {
      _lastStatus = signal.status;
      _lastAvailable = signal.available;
      _lastTrack = track;
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      signal.acquire(this);
    } else {
      signal.release(this);
    }
    sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    signal.removeListener(sync);
    signal.release(this);
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = songAppearance.preset;
    final track = widget.playback.current;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Color.lerp(theme.seed, Colors.black, .92),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      CloseButton(color: Colors.white),
                      Text(
                        MediaQuery.sizeOf(context).width < 400
                            ? '频谱'
                            : 'AUDIO / VISUAL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '重新分析当前音源',
                        onPressed: signal.retry,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      PopupMenuButton<int>(
                        tooltip: '频谱样式',
                        onSelected: (v) => setState(() => mode = v),
                        itemBuilder: (_) => [
                          for (final (i, name) in [
                            '频率柱',
                            '镜面声场',
                            '轨道环谱',
                            '示波轨迹',
                            '山峦频谱',
                            '点阵舞台',
                            '双环声场',
                            '立体声柱',
                          ].indexed)
                            CheckedPopupMenuItem(
                              value: i,
                              checked: mode == i,
                              child: Text(name),
                            ),
                        ],
                        icon: const Icon(Icons.graphic_eq, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: '可视化设置',
                        icon: const Icon(Icons.tune, color: Colors.white),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => StatefulBuilder(
                            builder: (context, update) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('频谱强度'),
                                    Slider(
                                      value: strength,
                                      min: .4,
                                      max: 2,
                                      onChanged: (v) {
                                        setState(() => strength = v);
                                        update(() {});
                                      },
                                    ),
                                    const Text('线条宽度'),
                                    Slider(
                                      value: width,
                                      min: 1,
                                      max: 8,
                                      onChanged: (v) {
                                        setState(() => width = v);
                                        update(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth > box.maxHeight * 1.3;
                      final cover = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (track != null && track.cover.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                widget.playback.music.image(track.cover),
                                width: math.min(
                                  wide
                                      ? box.maxWidth * .23
                                      : box.maxHeight * .22,
                                  260,
                                ),
                                height: math.min(
                                  wide
                                      ? box.maxWidth * .23
                                      : box.maxHeight * .22,
                                  260,
                                ),
                                cacheWidth: 512,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.album,
                                  color: Colors.white54,
                                  size: 100,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            track?.title ??
                                widget.playback.localName ??
                                '请选择歌曲',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            track?.artist ?? '',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                      final graph = RepaintBoundary(
                        child: CustomPaint(
                          painter: SignalPainter(
                            signal: signal,
                            clock: clock,
                            color: theme.accent,
                            mode: mode,
                            strength: strength,
                            width: width,
                          ),
                          size: Size.infinite,
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: wide
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: box.maxWidth * .32,
                                    child: cover,
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(child: graph),
                                ],
                              )
                            : Column(
                                children: [
                                  cover,
                                  const SizedBox(height: 16),
                                  Expanded(child: graph),
                                ],
                              ),
                      );
                    },
                  ),
                ),
                Text(
                  signal.available ? '当前歌曲 · 48 段真实频谱' : signal.status,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ImmersiveTransport(
                    playback: widget.playback,
                    ink: Colors.white,
                    accent: theme.accent,
                    compact: MediaQuery.sizeOf(context).height < 450,
                    onInteraction: () {},
                    onSeek: signal.clear,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignalPainter extends CustomPainter {
  SignalPainter({
    required this.signal,
    required this.clock,
    required this.color,
    this.mode = 0,
    this.strength = 1,
    this.width = 3,
  }) : super(repaint: Listenable.merge([clock, signal]));
  final AudioAnalysis signal;
  final Animation<double> clock;
  final Color color;
  final int mode;
  final double strength, width;
  @override
  void paint(Canvas c, Size s) {
    final ink = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final bands = signal.bands;
    final w = s.width, h = s.height;
    c.save();
    c.clipRect(Offset.zero & s);
    if (mode == 4) {
      final path = Path()..moveTo(0, h);
      for (var i = 0; i < bands.length; i++) {
        path.lineTo(
          w * i / (bands.length - 1),
          h * .9 - signal.interpolatedBand(i) * h * .75 * strength,
        );
      }
      path.lineTo(w, h);
      path.close();
      c.drawPath(path, Paint()..color = color.withValues(alpha: .22));
      c.drawPath(path, ink..style = PaintingStyle.stroke);
      c.restore();
      return;
    }
    if (mode == 5 || mode == 7) {
      final cell = w / 48;
      for (var i = 0; i < 48; i++) {
        final n = (signal.interpolatedBand(i) * strength).clamp(0.0, 1.0);
        if (mode == 5) {
          for (var j = 0; j < (n * 14).floor(); j++) {
            c.drawCircle(
              Offset((i + .5) * cell, h - (j + .5) * h / 14),
              math.min(cell * .28, h / 44),
              ink,
            );
          }
        } else {
          final x = (i + .5) * cell, bar = n * h * .8;
          final face = Path()
            ..moveTo(x, h)
            ..lineTo(x, h - bar)
            ..lineTo(x + cell * .5, h - bar - cell * .25)
            ..lineTo(x + cell * .5, h - cell * .25)
            ..close();
          c.drawPath(face, Paint()..color = color.withValues(alpha: .68));
          c.drawLine(Offset(x, h), Offset(x, h - bar), ink);
        }
      }
      c.restore();
      return;
    }
    if (mode == 6) {
      final center = Offset(w / 2, h / 2), radius = math.min(w, h) * .25;
      for (var i = 0; i < 48; i++) {
        final a = i * math.pi * 2 / 48, d = Offset(math.cos(a), math.sin(a));
        final level =
            signal.interpolatedBand(i) * strength * math.min(w, h) * .14;
        c.drawLine(center + d * radius, center + d * (radius + level), ink);
        c.drawLine(
          center + d * (radius * .8),
          center + d * (radius * .8 - level * .5),
          ink,
        );
      }
      c.restore();
      return;
    }
    if (mode == 3) {
      final path = Path();
      for (var i = 0; i < signal.waveform.length; i++) {
        final x = w * i / (signal.waveform.length - 1),
            y = h / 2 - signal.waveform[i] * h * .44 * strength;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      c.drawPath(path, ink..style = PaintingStyle.stroke);
      c.restore();
      return;
    }
    if (mode == 2) {
      final center = Offset(w / 2, h / 2);
      final radius = math.min(w, h) * .23;
      for (var i = 0; i < bands.length; i++) {
        final a = i * math.pi * 2 / bands.length - math.pi / 2;
        final n = (signal.interpolatedBand(i) * strength).clamp(0.0, 1.0);
        final direction = Offset(math.cos(a), math.sin(a));
        c.drawLine(
          center + direction * radius,
          center + direction * (radius + n * math.min(w, h) * .22),
          ink,
        );
      }
      c.drawCircle(
        center,
        radius - 7,
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      c.restore();
      return;
    }
    final cell = w / bands.length;
    for (var i = 0; i < bands.length; i++) {
      final n = (signal.interpolatedBand(i) * strength).clamp(0.0, 1.0);
      final bar = math.max(1.0, n * h * (mode == 1 ? .44 : .88));
      final x = (i + .5) * cell;
      if (mode == 1) {
        c.drawLine(
          Offset(x, h / 2 - bar),
          Offset(x, h / 2 + bar),
          ink..strokeWidth = math.min(width + 2, cell * .7),
        );
      } else {
        c.drawLine(
          Offset(x, h - 4),
          Offset(x, h - 4 - bar),
          ink..strokeWidth = math.min(width + 2, cell * .7),
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(SignalPainter old) =>
      old.signal != signal ||
      old.color != color ||
      old.mode != mode ||
      old.strength != strength ||
      old.width != width;
}
