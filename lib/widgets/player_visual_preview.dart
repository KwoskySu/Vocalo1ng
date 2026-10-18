import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/lyrics.dart';
import '../services/song_theme.dart';
import 'player_visuals.dart';
import 'lyric_stage.dart';
import 'atmosphere.dart';

/// The actual cover and lyric renderers stay visible while editing effects.
class PlayerVisualPreview extends StatefulWidget {
  const PlayerVisualPreview({
    super.key,
    required this.url,
    required this.lines,
    required this.translations,
    required this.active,
  });
  final String url;
  final List<LyricLine> lines;
  final List<String?> translations;
  final int active;
  @override
  State<PlayerVisualPreview> createState() => _PlayerVisualPreviewState();
}

class _PlayerVisualPreviewState extends State<PlayerVisualPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([songAppearance, motion]),
    builder: (context, _) {
      final preset = songAppearance.preset;
      final light = songAppearance.lyricStyle == 4;
      final data = widget.lines.isEmpty
          ? [
              const LyricLine(null, '歌声在这里流动'),
              const LyricLine(null, '让每一次喜欢拥有自己的形状'),
            ]
          : widget.lines;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: light
              ? preset.background
              : Color.lerp(preset.seed, Colors.black, .82)!,
          child: CustomPaint(
            painter: Atmosphere(
              preset.accent,
              MediaQuery.disableAnimationsOf(context) ? 0 : motion.value,
              songAppearance.lyricStyle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  MotionCover(
                    url: widget.url,
                    size: 88,
                    motion: motion,
                    style: songAppearance.lyricStyle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LyricStage(
                      lines: data,
                      translations: widget.lines.isEmpty
                          ? List.filled(2, null)
                          : widget.translations,
                      bilingual: true,
                      active: math.max(0, widget.active),
                      style: songAppearance.scrollStyle,
                      font: songAppearance.lyricFont,
                      scale: songAppearance.lyricScale * .8,
                      effects: songAppearance.lyricEffects,
                      foreground: light
                          ? const Color(0xff243830)
                          : Colors.white,
                      accent: preset.accent,
                      onSeek: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
