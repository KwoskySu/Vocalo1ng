import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/top_chart.dart';
import '../services/music.dart';
import 'player_visuals.dart' show lyricFontFamilies;
import 'top_blurred_cover.dart';

const topStyleNames = [
  '森林杂志',
  '颁奖台',
  '黑胶档案',
  '樱花手帖',
  '黑白社论',
  '电影胶片',
  '午夜霓虹',
  '拼贴便笺',
  '极简画廊',
  '巡演票根',
  '暮色画册',
  '先锋海报',
  '雾面玻璃',
  '封面光场',
  '珠光卡片',
  '极光棱镜',
  '烫金画框',
  '水彩留白',
];
const topFrameNames = [
  '沿用样式',
  '留白无框',
  '细线描边',
  '双线画框',
  '虚线票券',
  '胶片边',
  '金属角标',
  '柔光投影',
  '硬边阴影',
  '磨砂玻璃',
  '镭射棱镜',
];

const topPaletteNames = ['苔绿', '莓粉', '海蓝', '琥珀', '鸢紫', '珊瑚', '青柠', '银灰'];
const topPaletteColors = [
  0xff397862,
  0xffb85279,
  0xff337dae,
  0xffbd8233,
  0xff8864ba,
  0xffcd654f,
  0xff879e29,
  0xff727b87,
];

final _topBytes = LinkedHashMap<String, Uint8List>();
Uint8List topImageBytes(String source) {
  final found = _topBytes.remove(source);
  final value = found ?? base64Decode(source);
  _topBytes[source] = value;
  while (_topBytes.length > 24 ||
      _topBytes.values.fold<int>(0, (n, b) => n + b.length) > 4 * 1024 * 1024) {
    _topBytes.remove(_topBytes.keys.first);
  }
  return value;
}

void clearTopImageBytes() => _topBytes.clear();

Color? topHex(String value) => RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value)
    ? Color(0xff000000 | int.parse(value.substring(1), radix: 16))
    : null;
double topArtWidth(TopChart c) => [640.0, 760.0, 1040.0, 760.0][c.format];

String topImageUrl(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    return '';
  }
  final original = uri.path == '/api/image'
      ? uri.queryParameters['url'] ?? source
      : source;
  final target = Uri.tryParse(original);
  if (target == null) return '';
  return [
        'voca.wiki',
        'nimg.jp',
        'smilevideo.jp',
        'pximg.net',
        'piapro.jp',
        'twimg.com',
        'wikimedia.org',
        'wikia.nocookie.net',
      ].any((h) => target.host == h || target.host.endsWith('.$h'))
      ? gatewayImage(original)
      : original;
}

class TopCover extends StatelessWidget {
  const TopCover({
    super.key,
    required this.entry,
    this.shape = 0,
    this.contain = false,
    this.color = const Color(0xff397862),
  });
  final TopEntry entry;
  final int shape;
  final bool contain;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: color.withValues(alpha: .13),
      child: Center(child: Icon(Icons.album_outlined, color: color, size: 36)),
    );
    final fit = contain ? BoxFit.contain : BoxFit.cover;
    Widget cover = fallback;
    if (entry.coverData.isNotEmpty) {
      cover = Image.memory(
        topImageBytes(entry.coverData),
        fit: fit,
        cacheWidth: 320,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (topImageUrl(entry.coverUrl).isNotEmpty) {
      cover = Image.network(
        topImageUrl(entry.coverUrl),
        fit: fit,
        cacheWidth: 320,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        shape == 2
            ? 999
            : shape == 1
            ? 0
            : 12,
      ),
      child: SizedBox.expand(child: cover),
    );
  }
}

class TopChartArt extends StatelessWidget {
  const TopChartArt({super.key, required this.chart, this.page = 0});
  final TopChart chart;
  final int page;
  Color get accent => Color(topPaletteColors[chart.palette]);
  Color get base =>
      topHex(chart.customColor) ??
      const [
        Color(0xfff1efe5),
        Color(0xfff6f1e5),
        Color(0xff171b22),
        Color(0xfffff0f3),
        Color(0xfffafafa),
        Color(0xff22211e),
        Color(0xff111525),
        Color(0xffeae3d4),
        Color(0xfff9f9f5),
        Color(0xfff5ecdb),
        Color(0xff25253c),
        Color(0xfff3ef67),
        Color(0xffe7eff3),
        Color(0xff172731),
        Color(0xfff7f0f5),
        Color(0xff162334),
        Color(0xff18231f),
        Color(0xfff4f2e8),
      ][chart.style];
  bool get dark => base.computeLuminance() < .28;
  Color get ink => dark ? const Color(0xfff8f5ee) : const Color(0xff242a2b);
  Color get highlight => dark ? Color.lerp(accent, Colors.white, .45)! : accent;
  TopTypography textType(String part, TopEntry? entry) =>
      entry?.typography[part] ??
      chart.typography[part] ??
      chart.typography['footer']!;
  TextStyle type(String part, {Color? color, TopEntry? entry}) {
    final value = textType(part, entry);
    return TextStyle(
      fontFamily: lyricFontFamilies[value.font],
      fontSize: value.size,
      fontWeight: value.bold ? FontWeight.w800 : FontWeight.w400,
      height: value.height,
      letterSpacing: value.tracking,
      fontStyle: value.italic ? FontStyle.italic : FontStyle.normal,
      decoration: value.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      color: topHex(value.color) ?? color ?? ink,
    );
  }

  Widget line(
    String value,
    String part, {
    Color? color,
    TextAlign? align,
    TopEntry? entry,
  }) {
    final alignment = textType(part, entry).align;
    return Text(
      value,
      style: type(part, color: color, entry: entry),
      textAlign:
          align ??
          [TextAlign.left, TextAlign.center, TextAlign.right][alignment >= 0
              ? alignment
              : chart.align],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = chart.page(page);
    final width = topArtWidth(chart), padding = chart.outerPadding;
    var cols = chart.columns;
    if (cols == 0) {
      cols = chart.style == 1
          ? 3
          : [2, 5, 6, 7, 8, 10, 12, 14, 15, 16].contains(chart.style)
          ? 2
          : 1;
    }
    if (chart.format == 2 && chart.columns == 0 && cols == 2) cols = 3;
    final tileWidth = (width - padding * 2 - (cols - 1) * chart.gap) / cols;
    final minHeight = [width * 1.3, width, width * .56, 0.0][chart.format];
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          gradient: chart.style == 10
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [base, Color.lerp(base, accent, .4)!],
                )
              : null,
        ),
        child: Stack(
          children: [
            if (chart.backgroundData.isNotEmpty ||
                topImageUrl(chart.backgroundUrl).isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: chart.backgroundOpacity,
                  child: chart.backgroundData.isNotEmpty
                      ? Image.memory(
                          topImageBytes(chart.backgroundData),
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        )
                      : Image.network(
                          topImageUrl(chart.backgroundUrl),
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                ),
              ),
            if ([0, 3, 7, 9].contains(chart.style))
              Positioned.fill(
                child: CustomPaint(
                  painter: _PaperLines(ink.withValues(alpha: .04), chart.style),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chart.title.isNotEmpty) line(chart.title, 'title'),
                    if (chart.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      line(
                        chart.subtitle,
                        'subtitle',
                        color: ink.withValues(alpha: .65),
                      ),
                    ],
                    if (chart.showDivider)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Container(
                          height: chart.style == 11 ? 4 : 1,
                          color: ink.withValues(alpha: .24),
                        ),
                      ),
                    if (chart.title.isNotEmpty || chart.subtitle.isNotEmpty)
                      const SizedBox(height: 22),
                    if (rows.isNotEmpty)
                      Wrap(
                        spacing: chart.gap,
                        runSpacing: chart.gap,
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            SizedBox(
                              width: tileWidth,
                              child: tile(
                                rows[i],
                                page * chart.perPage + i + 1,
                                cols,
                              ),
                            ),
                        ],
                      ),
                    if (chart.footer.isNotEmpty || chart.author.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      if (chart.footer.isNotEmpty)
                        line(
                          chart.footer,
                          'footer',
                          color: ink.withValues(alpha: .65),
                        ),
                      if (chart.author.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        line(chart.author, 'author', color: highlight),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget tile(TopEntry entry, int rank, int columns) {
    final grid = columns > 1;
    final ticket = chart.style == 9,
        raw = [0, 4, 8].contains(chart.style),
        brutal = chart.style == 11;
    final tileColor = dark
        ? Colors.white.withValues(alpha: .055)
        : Colors.white.withValues(alpha: chart.style == 7 ? .72 : .65);
    Widget rankLabel = chart.showRank
        ? line(
            rank.toString().padLeft(2, '0'),
            'rank',
            color: highlight,
            entry: entry,
          )
        : const SizedBox();
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry.badge.isNotEmpty) ...[
          line(entry.badge, 'badge', color: highlight, entry: entry),
          const SizedBox(height: 5),
        ],
        line(entry.title, 'item', entry: entry),
        if (entry.subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          line(
            entry.subtitle,
            'detail',
            color: ink.withValues(alpha: .65),
            entry: entry,
          ),
        ],
        if (chart.showReason &&
            entry.reason.isNotEmpty &&
            !(chart.style == 4 && !grid)) ...[
          const SizedBox(height: 10),
          line(
            entry.reason,
            'reason',
            color: ink.withValues(alpha: .8),
            entry: entry,
          ),
        ],
      ],
    );
    final image = AspectRatio(
      aspectRatio: 1,
      child: TopCover(
        entry: entry,
        shape: chart.style == 2 ? 2 : chart.coverShape,
        contain: chart.coverContain,
        color: highlight,
      ),
    );
    Widget content;
    if (grid) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              rankLabel,
              if (chart.style == 1 && rank <= 3)
                Icon(
                  Icons.workspace_premium,
                  color: highlight,
                  size: rank == 1 ? 38 : 26,
                ),
            ],
          ),
          if (chart.showCover) ...[
            const SizedBox(height: 12),
            image,
            const SizedBox(height: 14),
          ],
          detail,
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chart.showRank) ...[
            SizedBox(
              width: math.max(44, textType('rank', entry).size * 1.9),
              child: rankLabel,
            ),
            const SizedBox(width: 10),
          ],
          if (chart.showCover) ...[
            SizedBox(width: ticket ? 76 : 100, child: image),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: chart.style == 4 && chart.showReason ? 4 : 1,
            child: detail,
          ),
          if (chart.style == 4 && chart.showReason) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: line(
                entry.reason.isEmpty ? '—' : entry.reason,
                'reason',
                entry: entry,
                color: ink.withValues(alpha: .8),
              ),
            ),
          ],
        ],
      );
    }
    if (chart.style == 5) {
      content = Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              10,
              (_) => Container(
                width: 10,
                height: 5,
                color: ink.withValues(alpha: .35),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: content,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              10,
              (_) => Container(
                width: 10,
                height: 5,
                color: ink.withValues(alpha: .35),
              ),
            ),
          ),
        ],
      );
    }
    final selectedFrame = entry.frame >= 0 ? entry.frame : chart.frame;
    final frame = selectedFrame == 0
        ? switch (chart.style) {
            12 => 9,
            13 => 2,
            14 => 3,
            15 => 10,
            16 => 6,
            17 => 7,
            _ => 0,
          }
        : selectedFrame;
    final glass = frame == 9 || frame == 10;
    final radius = brutal || chart.style == 5 ? 0.0 : chart.radius;
    final provider = entry.coverData.isNotEmpty
        ? ResizeImage(MemoryImage(topImageBytes(entry.coverData)), width: 320)
        : topImageUrl(entry.coverUrl).isNotEmpty
        ? ResizeImage(NetworkImage(topImageUrl(entry.coverUrl)), width: 320)
        : null;
    final useCover = provider != null && (chart.coverBackdrop || glass);
    final surface = glass
        ? (dark ? Colors.white : Colors.white).withValues(
            alpha: chart.glassOpacity,
          )
        : frame == 1 || (raw && frame == 0)
        ? Colors.transparent
        : brutal
        ? (dark ? const Color(0xff252525) : Colors.white)
        : tileColor;
    Widget result = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: frame == 8 || (brutal && frame == 0)
            ? [
                BoxShadow(
                  color: ink.withValues(alpha: .8),
                  offset: const Offset(4, 4),
                ),
              ]
            : frame == 7
            ? [
                BoxShadow(
                  color: highlight.withValues(alpha: .2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          foregroundPainter: _TopFramePainter(
            frame: frame,
            color: chart.style == 16 ? const Color(0xffc9a55d) : highlight,
            ink: ink,
            width: chart.borderWidth,
            radius: radius,
            raw: raw,
            brutal: brutal,
          ),
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: surface)),
              if (useCover)
                Positioned.fill(
                  child: TopBlurredCover(
                    provider: provider,
                    blur: chart.backdropBlur,
                    zoom: chart.backdropZoom,
                    opacity: chart.backdropOpacity,
                  ),
                ),
              if (useCover)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: glass
                            ? [
                                base.withValues(alpha: .32),
                                base.withValues(alpha: .62),
                              ]
                            : [
                                base.withValues(alpha: .22),
                                base.withValues(alpha: .75),
                              ],
                      ),
                    ),
                  ),
                ),
              if (glass)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: chart.glassOpacity),
                          Colors.white.withValues(alpha: .02),
                          highlight.withValues(alpha: .1),
                        ],
                        stops: const [0, .48, 1],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(
                  raw && frame == 0 ? 10 : chart.cardPadding,
                ),
                child: content,
              ),
            ],
          ),
        ),
      ),
    );
    if (chart.style == 7) {
      result = Transform.rotate(
        angle: rank.isEven ? .008 : -.008,
        child: result,
      );
    }
    return result;
  }
}

class _PaperLines extends CustomPainter {
  _PaperLines(this.color, this.mode);
  final Color color;
  final int mode;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 28) {
      if (mode == 3) {
        for (var x = 12.0; x < size.width; x += 28) {
          canvas.drawCircle(Offset(x, y), 1, paint);
        }
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PaperLines old) => old.color != color || old.mode != mode;
}

class _TopFramePainter extends CustomPainter {
  const _TopFramePainter({
    required this.frame,
    required this.color,
    required this.ink,
    required this.width,
    required this.radius,
    required this.raw,
    required this.brutal,
  });
  final int frame;
  final Color color, ink;
  final double width, radius;
  final bool raw, brutal;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: .65);
    if (frame == 1) return;
    if (frame == 0) {
      pen.color = ink.withValues(alpha: brutal ? 1 : .18);
      pen.strokeWidth = brutal ? 2 : width;
      if (raw) {
        canvas.drawLine(
          Offset(0, size.height - width),
          Offset(size.width, size.height - width),
          pen,
        );
        return;
      }
    }
    if (frame == 4 || frame == 5) {
      for (double x = 8; x < size.width - 4; x += 14) {
        canvas.drawLine(
          Offset(x, 3),
          Offset((x + 7).clamp(0, size.width), 3),
          pen,
        );
        canvas.drawLine(
          Offset(x, size.height - 3),
          Offset((x + 7).clamp(0, size.width), size.height - 3),
          pen,
        );
      }
      if (frame == 5) {
        for (double y = 14; y < size.height - 10; y += 22) {
          canvas.drawRect(Rect.fromLTWH(3, y, 4, 8), pen);
          canvas.drawRect(Rect.fromLTWH(size.width - 7, y, 4, 8), pen);
        }
      }
      return;
    }
    if (frame == 6) {
      final len = (size.shortestSide * .18).clamp(10.0, 28.0);
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        final dx = corner.dx < size.width / 2 ? 1 : -1,
            dy = corner.dy < size.height / 2 ? 1 : -1;
        canvas.drawLine(corner, corner + Offset(len * dx, 0), pen);
        canvas.drawLine(corner, corner + Offset(0, len * dy), pen);
      }
      return;
    }
    ui.Shader? shader;
    if (frame == 9 || frame == 10) {
      shader = LinearGradient(
        colors: frame == 10
            ? [
                const Color(0xffb0f1e6),
                const Color(0xffddb8f4),
                const Color(0xffffdfa6),
                Colors.white,
              ]
            : [
                Colors.white.withValues(alpha: .9),
                Colors.white.withValues(alpha: .12),
                Colors.white.withValues(alpha: .6),
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
      pen.shader = shader;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      pen,
    );
    if (frame == 3)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(5),
          Radius.circular((radius - 4).clamp(0, double.infinity)),
        ),
        pen..color = color.withValues(alpha: .3),
      );
    shader?.dispose();
  }

  @override
  bool shouldRepaint(_TopFramePainter old) =>
      old.frame != frame ||
      old.color != color ||
      old.ink != ink ||
      old.width != width ||
      old.radius != radius ||
      old.raw != raw ||
      old.brutal != brutal;
}
