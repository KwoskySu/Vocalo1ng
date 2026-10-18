import 'phone_theme.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/lyrics.dart';
import 'player_visuals.dart' show lyricFontFamilies;

class LyricStage extends StatefulWidget {
  const LyricStage({
    super.key,
    required this.lines,
    required this.translations,
    required this.bilingual,
    required this.active,
    required this.style,
    required this.foreground,
    required this.accent,
    required this.onSeek,
    this.font = 0,
    this.scale = 1,
    this.effects = const {},
  });
  final List<LyricLine> lines;
  final List<String?> translations;
  final bool bilingual;
  final int active, style;
  final Color foreground, accent;
  final ValueChanged<Duration> onSeek;
  final int font;
  final double scale;
  final Set<String> effects;
  @override
  State<LyricStage> createState() => _LyricStageState();
}

class _LyricStageState extends State<LyricStage> {
  final scroll = ScrollController();
  final pages = PageController(viewportFraction: .86);
  bool following = true;
  int focus = 0;
  double viewport = 300;
  double get extent =>
      (isPhoneLayout(context)
          ? (widget.bilingual ? 108 : 72)
          : (widget.bilingual ? 144 : 104)) *
      math.max(1, widget.scale) *
      (mounted ? MediaQuery.textScalerOf(context).scale(16) / 16 : 1);
  @override
  void initState() {
    super.initState();
    scheduleFollow();
  }

  @override
  void didUpdateWidget(LyricStage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active ||
        old.bilingual != widget.bilingual ||
        old.style != widget.style ||
        old.scale != widget.scale) {
      scheduleFollow();
    }
  }

  void scheduleFollow() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => follow());
  void follow() {
    if (!mounted || !following || widget.lines.isEmpty) return;
    final target = widget.active.clamp(0, widget.lines.length - 1);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    if (widget.style == 3 && pages.hasClients) {
      pages.animateToPage(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } else if (scroll.hasClients) {
      scroll.animateTo(
        (target * extent).clamp(0, scroll.position.maxScrollExtent),
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    pages.dispose();
    super.dispose();
  }

  Widget text(int i, {bool large = false}) {
    final current = i == widget.active;
    final wide =
        !isPhoneLayout(context) && MediaQuery.sizeOf(context).width >= 760;
    final aligned = widget.style == 4;
    final translation = i < widget.translations.length
        ? widget.translations[i]
        : null;
    if (widget.style == 10) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.lines[i].text,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: lyricFontFamilies[widget.font],
                  fontSize: (current ? 24 : 18) * widget.scale,
                  color: current
                      ? widget.foreground
                      : widget.foreground.withValues(alpha: .5),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Container(
              width: 1,
              height: 56,
              color: widget.accent.withValues(alpha: .4),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                widget.bilingual ? translation ?? '' : '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: lyricFontFamilies[widget.font],
                  fontSize: (current ? 20 : 15) * widget.scale,
                  color: widget.accent.withValues(alpha: current ? 1 : .5),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: bounds.maxWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: aligned
                  ? (i.isEven
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end)
                  : CrossAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 320),
                  textAlign: aligned
                      ? (i.isEven ? TextAlign.left : TextAlign.right)
                      : TextAlign.center,
                  style: TextStyle(
                    fontFamily: lyricFontFamilies[widget.font.clamp(0, 3)],
                    fontFamilyFallback: const ['NotoSansSC'],
                    foreground: current && widget.effects.contains('outline')
                        ? (Paint()
                            ..color = widget.accent
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.1)
                        : null,
                    color: current && widget.effects.contains('outline')
                        ? null
                        : current || large
                        ? widget.foreground
                        : widget.foreground.withValues(alpha: .45),
                    fontSize:
                        (large
                            ? (wide ? 36 : 25)
                            : current
                            ? (wide
                                  ? 28
                                  : isPhoneLayout(context)
                                  ? 19
                                  : 22)
                            : (wide ? 20 : 16)) *
                        widget.scale,
                    fontStyle: widget.effects.contains('stamp')
                        ? FontStyle.italic
                        : FontStyle.normal,
                    decoration: widget.effects.contains('underline') && current
                        ? TextDecoration.underline
                        : null,
                    decorationColor: widget.accent,
                    letterSpacing:
                        (widget.effects.contains('tracking') ||
                                widget.effects.contains('stencil') ||
                                widget.style == 12) &&
                            current
                        ? 2.5
                        : 0,
                    shadows: current
                        ? [
                            if (widget.effects.contains('extrude')) ...[
                              Shadow(
                                color: widget.accent.withValues(alpha: .6),
                                offset: const Offset(1, 1),
                              ),
                              Shadow(
                                color: widget.accent.withValues(alpha: .4),
                                offset: const Offset(2, 2),
                              ),
                              Shadow(
                                color: widget.accent.withValues(alpha: .2),
                                offset: const Offset(3, 3),
                              ),
                            ],
                            if (widget.effects.contains('glow'))
                              Shadow(color: widget.accent, blurRadius: 18),
                            if (widget.effects.contains('chromatic')) ...[
                              const Shadow(
                                color: Colors.cyanAccent,
                                offset: Offset(-2, 0),
                              ),
                              const Shadow(
                                color: Colors.pinkAccent,
                                offset: Offset(2, 0),
                              ),
                            ],
                          ]
                        : [],
                    fontWeight: current || large
                        ? FontWeight.w800
                        : FontWeight.w500,
                    height: 1.35,
                  ),
                  child: Text(
                    widget.lines[i].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.bilingual && translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    translation,
                    textAlign: aligned
                        ? (i.isEven ? TextAlign.left : TextAlign.right)
                        : TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (wide ? 16 : 13) * widget.scale,
                      fontFamily: lyricFontFamilies[widget.font.clamp(0, 3)],
                      fontFamilyFallback: const ['NotoSansSC'],
                      height: 1.4,
                      color: current || large
                          ? widget.accent
                          : widget.foreground.withValues(alpha: .38),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void seek(int i) {
    final time = widget.lines[i].time;
    if (time == null) return;
    widget.onSeek(time);
    setState(() => following = true);
    scheduleFollow();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if ((viewport - box.maxHeight).abs() > 1) {
        viewport = box.maxHeight;
        scheduleFollow();
      }
      if (widget.lines.isEmpty) {
        return Center(
          child: Text(
            '纯音乐，或暂未提供歌词',
            style: TextStyle(color: widget.foreground),
          ),
        );
      }
      final current = widget.active.clamp(0, widget.lines.length - 1);
      Widget content;
      if (widget.style == 2) {
        final shown = following
            ? current
            : focus.clamp(0, widget.lines.length - 1);
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('${widget.bilingual}:$shown'),
                    onTap: () => seek(shown),
                    child: text(shown, large: true),
                  ),
                ),
              ),
            ),
            if (box.maxHeight > 220 && shown + 1 < widget.lines.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.lines[shown + 1].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.foreground.withValues(alpha: .35),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '浏览上一句',
                  onPressed: shown > 0
                      ? () => setState(() {
                          focus = shown - 1;
                          following = false;
                        })
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                Text(
                  '${shown + 1} / ${widget.lines.length}',
                  style: TextStyle(
                    color: widget.foreground.withValues(alpha: .45),
                    fontSize: 10,
                  ),
                ),
                IconButton(
                  tooltip: '浏览下一句',
                  onPressed: shown + 1 < widget.lines.length
                      ? () => setState(() {
                          focus = shown + 1;
                          following = false;
                        })
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ],
        );
      } else if (widget.style == 3) {
        content = PageView.builder(
          controller: pages,
          itemCount: widget.lines.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            child: InkWell(
              onTap: () => seek(i),
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.accent.withValues(
                      alpha: i == current ? .6 : .12,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accent.withValues(alpha: .15),
                      widget.accent.withValues(alpha: .02),
                    ],
                  ),
                ),
                child: text(i, large: true),
              ),
            ),
          ),
        );
      } else {
        content = AnimatedBuilder(
          animation: scroll,
          builder: (context, _) => ListView.builder(
            controller: scroll,
            itemExtent: extent,
            itemCount: widget.lines.length,
            padding: EdgeInsets.symmetric(
              vertical: math.max(0, box.maxHeight / 2 - extent / 2),
            ),
            itemBuilder: (context, i) {
              Widget row = InkWell(onTap: () => seek(i), child: text(i));
              if (widget.effects.contains('glass')) {
                row = Padding(
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(
                        alpha: i == current ? .13 : .025,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: widget.accent.withValues(
                          alpha: i == current ? .35 : .04,
                        ),
                      ),
                    ),
                    child: row,
                  ),
                );
              }
              if (widget.style >= 5) {
                final center = scroll.hasClients
                    ? scroll.offset / extent
                    : current.toDouble();
                final distance = (i - center).clamp(-4.0, 4.0);
                final reduced = MediaQuery.disableAnimationsOf(context);
                final transform = Matrix4.identity()..setEntry(3, 2, .0012);
                final spread = (box.maxWidth / 600).clamp(.35, 1.0);
                if (!reduced) {
                  switch (widget.style) {
                    case 5:
                      transform
                        ..translateByDouble(
                          distance.abs() * 17 * spread,
                          0,
                          0,
                          1,
                        )
                        ..rotateZ(distance * .13);
                    case 6:
                      transform
                        ..translateByDouble(
                          math.sin(distance * .9) * 62 * spread,
                          0,
                          -distance.abs() * 45,
                          1,
                        )
                        ..rotateZ(distance * .09)
                        ..rotateY(distance * .16);
                    case 7:
                      transform.rotateX((distance * .55).clamp(-1.15, 1.15));
                    case 8:
                      transform
                        ..translateByDouble(
                          math.sin(distance * 1.1) * 48 * spread,
                          0,
                          0,
                          1,
                        )
                        ..rotateZ(math.sin(distance) * .065);
                    case 9:
                      transform
                        ..translateByDouble(
                          (1 - math.cos(distance * .4)) * 90 * spread,
                          0,
                          0,
                          1,
                        )
                        ..rotateZ(distance * .1);
                    case 11:
                      transform.translateByDouble((i % 4 - 1.5) * 16, 0, 0, 1);
                    case 12:
                      transform.translateByDouble(distance * 8, 0, 0, 1);
                  }
                }
                row = Transform(
                  alignment: widget.style == 5
                      ? Alignment.centerLeft
                      : Alignment.center,
                  transform: transform,
                  child: RepaintBoundary(child: row),
                );
              }
              if (widget.style == 1) {
                final center = scroll.hasClients
                    ? scroll.offset / extent
                    : current.toDouble();
                final distance = (i - center).clamp(-3.0, 3.0);
                row = Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0012)
                    ..rotateX(-distance * .16)
                    ..scaleByDouble(
                      1 - distance.abs() * .08,
                      1 - distance.abs() * .08,
                      1,
                      1,
                    ),
                  child: RepaintBoundary(child: row),
                );
              }
              if (widget.style == 4) {
                row = Padding(
                  padding: EdgeInsets.only(
                    left: i.isEven ? 0 : 36,
                    right: i.isEven ? 36 : 0,
                  ),
                  child: row,
                );
              }
              return RepaintBoundary(key: ValueKey('lyric:$i'), child: row);
            },
          ),
        );
      }
      return Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                if (n.dragDetails != null && following) {
                  setState(() => following = false);
                }
                return false;
              },
              child: content,
            ),
          ),
          if (!following)
            Positioned(
              right: 10,
              bottom: 8,
              child: isPhoneLayout(context)
                  ? IconButton.filledTonal(
                      tooltip: '跟随歌词',
                      onPressed: () {
                        setState(() => following = true);
                        scheduleFollow();
                      },
                      icon: const Icon(Icons.my_location, size: 18),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() => following = true);
                        scheduleFollow();
                      },
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('跟随歌词'),
                    ),
            ),
        ],
      );
    },
  );
}
