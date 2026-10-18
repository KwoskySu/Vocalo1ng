import 'phone_theme.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/song_theme.dart';

const backgroundStyleNames = [
  '极光流动',
  '黑胶暗室',
  '霓虹脉冲',
  '光谱舞台',
  '极简留白',
  '像素终端',
  '宇宙跃迁',
  '棱镜流体',
  '日落网格',
  '黑白切纸',
  '摩尔涟漪',
  '磁带星图',
];
const scrollStyleNames = [
  '流光长卷',
  '纵深隧道',
  '电影聚焦',
  '星轨横移',
  '交错对唱',
  '扇形唱针',
  '螺旋星阶',
  '翻页剧场',
  '波浪回廊',
  '环形诗轨',
  '分屏译幕',
  '阶梯律动',
  '字阵回声',
];
const lyricFontNames = ['思源黑体', '思源宋体', '站酷快乐体', '等宽终端'];
const lyricFontFamilies = [
  'NotoSansSC',
  'NotoSerifSC',
  'ZCOOLKuaiLe',
  'monospace',
];
const lyricEffectNames = {
  'glow': '光晕字幕',
  'outline': '镂空字影',
  'chromatic': '色差霓虹',
  'glass': '玻璃字幕卡',
  'tracking': '字距呼吸',
  'extrude': '立体铅字',
  'underline': '唱针下划线',
  'stamp': '斜印字章',
  'stencil': '钢印字模',
};
const coverEffectNames = {
  'rotate': '黑胶旋转',
  'glow': '霓虹辉光',
  'tilt': '3D 悬浮倾角',
  'depth': '3D 层叠唱片',
  'float': '失重漂浮',
  'ring': '轨道光环',
  'hologram': '全息棱镜',
  'portal': '跃迁星门',
  'shards': '碎片卫星',
  'scan': '赛博扫描',
  'ripple': '涟漪声场',
  'diamond': '菱形切面',
  'cassette': '透明磁带',
  'crosshair': '机械瞄准',
  'halo': '双星引力',
  'frame': '悬浮画框',
};

class VisualOptions extends StatelessWidget {
  const VisualOptions({super.key, this.previewBuilder});
  final WidgetBuilder? previewBuilder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: songAppearance,
    builder: (context, _) => Column(
      children: [
        if (previewBuilder != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height < 450 ? 100 : 142,
              child: previewBuilder!(context),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isPhoneLayout(context) ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '视觉实验室',
                        style: TextStyle(
                          fontSize: isPhoneLayout(context) ? 18 : 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭视觉实验室',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '背景氛围',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    backgroundStyleNames.length,
                    (i) => ChoiceChip(
                      label: Text(backgroundStyleNames[i]),
                      selected: songAppearance.lyricStyle == i,
                      onSelected: (_) => songAppearance.setLyricStyle(i),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '封面效果 · 可自由叠加',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coverEffectNames.entries
                      .map(
                        (e) => FilterChip(
                          label: Text(e.value),
                          selected: songAppearance.coverEffects.contains(e.key),
                          onSelected: (_) =>
                              songAppearance.toggleCoverEffect(e.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text('封面播放组件'),
                  subtitle: Text('在封面上直接播放、暂停与切歌'),
                  value: songAppearance.coverControls,
                  onChanged: songAppearance.setCoverControls,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, name) in [
                      '中心唱针',
                      '磁带控制台',
                      '底座甲板',
                      '轨道按钮',
                    ].indexed)
                      ChoiceChip(
                        label: Text(name),
                        selected: songAppearance.coverDeck == i,
                        onSelected: (_) => songAppearance.setCoverDeck(i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '歌词滚动与布局',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    scrollStyleNames.length,
                    (i) => ChoiceChip(
                      label: Text(scrollStyleNames[i]),
                      selected: songAppearance.scrollStyle == i,
                      onSelected: (_) => songAppearance.setScrollStyle(i),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '歌词效果 · 可叠加',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lyricEffectNames.entries
                      .map(
                        (e) => FilterChip(
                          label: Text(e.value),
                          selected: songAppearance.lyricEffects.contains(e.key),
                          onSelected: (_) =>
                              songAppearance.toggleLyricEffect(e.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  '字体与字号',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 15 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    lyricFontNames.length,
                    (i) => ChoiceChip(
                      label: Text(lyricFontNames[i]),
                      selected: songAppearance.lyricFont == i,
                      onSelected: (_) => songAppearance.setTypography(font: i),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text('字号'),
                    Expanded(
                      child: Slider(
                        value: songAppearance.lyricScale,
                        min: .75,
                        max: 1.5,
                        divisions: 15,
                        label: '${(songAppearance.lyricScale * 100).round()}%',
                        onChanged: (v) =>
                            songAppearance.setTypography(scale: v),
                      ),
                    ),
                    Text('${(songAppearance.lyricScale * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '电影聚焦将封面移到上方，交错对唱在宽屏中将封面移到右侧。拖动歌词可自由浏览，点击「跟随歌词」回到当前进度。',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class MotionCover extends StatefulWidget {
  const MotionCover({
    super.key,
    required this.url,
    required this.size,
    required this.motion,
    required this.style,
  });
  final String url;
  final double size;
  final Animation<double> motion;
  final int style;
  @override
  State<MotionCover> createState() => _MotionCoverState();
}

class _MotionCoverState extends State<MotionCover> {
  Offset pointer = Offset.zero;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) => setState(
      () => pointer = Offset(
        (e.localPosition.dx / widget.size - .5).clamp(-.5, .5),
        (e.localPosition.dy / widget.size - .5).clamp(-.5, .5),
      ),
    ),
    onExit: (_) => setState(() => pointer = Offset.zero),
    child: GestureDetector(
      onPanUpdate: (event) => setState(
        () => pointer = Offset(
          (event.localPosition.dx / widget.size - .5).clamp(-.5, .5),
          (event.localPosition.dy / widget.size - .5).clamp(-.5, .5),
        ),
      ),
      onPanEnd: (_) => setState(() => pointer = Offset.zero),
      child: AnimatedBuilder(
        animation: widget.motion,
        builder: (context, _) {
          final effects = songAppearance.coverEffects;
          final accent = songAppearance.preset.accent;
          final reduced = MediaQuery.disableAnimationsOf(context);
          final phone = isPhoneLayout(context);
          // Render the whole effect composition at one design size, then fit
          // it into the phone thumbnail including an orbit/3D safety margin.
          final size = phone ? 240.0 : widget.size;
          final phase = reduced ? 0.0 : widget.motion.value * math.pi * 2;
          final rotate = effects.contains('rotate') || widget.style == 1;
          final matrix = Matrix4.identity()..setEntry(3, 2, .0015);
          if (effects.contains('tilt') || effects.contains('depth')) {
            matrix.rotateX(
              reduced ? -.08 : -.10 + math.sin(phase) * .18 - pointer.dy * .9,
            );
            matrix.rotateY(
              reduced ? .18 : .18 + math.cos(phase) * .20 + pointer.dx * .9,
            );
          }
          Widget image = ClipRRect(
            borderRadius: BorderRadius.circular(rotate ? 500 : 22),
            child: widget.url.isEmpty
                ? ColoredBox(
                    color: accent.withValues(alpha: .25),
                    child: Center(child: Icon(Icons.album, size: size * .3)),
                  )
                : Image.network(
                    widget.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.album, size: 80)),
                  ),
          );
          if (effects.contains('diamond')) {
            image = ClipPath(clipper: _DiamondClipper(), child: image);
          }
          if (effects.contains('hologram')) {
            image = ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment(-1, math.sin(phase)),
                end: Alignment(1, -math.cos(phase)),
                colors: [
                  Colors.cyan.withValues(alpha: .3),
                  Colors.pink.withValues(alpha: .4),
                  Colors.amber.withValues(alpha: .2),
                ],
              ).createShader(rect),
              blendMode: BlendMode.softLight,
              child: image,
            );
          }
          image = Transform.rotate(angle: rotate ? phase : 0, child: image);
          final rendered = Transform.translate(
            offset: Offset(
              0,
              effects.contains('float') && !reduced
                  ? math.sin(phase * 2) * 9
                  : 0,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (effects.contains('ring'))
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: phase,
                          child: Container(
                            margin: const EdgeInsets.all(-16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: .4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: .16),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (effects.contains('depth'))
                      for (var layer = 3; layer > 0; layer--)
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(layer * 7, layer * 5),
                            child: Transform.rotate(
                              angle: layer * .035,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    rotate ? 500 : 22,
                                  ),
                                  color: Color.lerp(
                                    accent,
                                    Colors.black,
                                    layer / 5,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: .45),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            rotate ? 500 : 22,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(
                                alpha:
                                    effects.contains('glow') ||
                                        widget.style == 2
                                    ? .45
                                    : .12,
                              ),
                              blurRadius: effects.contains('glow') ? 60 : 30,
                              spreadRadius: effects.contains('glow') ? 8 : 0,
                            ),
                          ],
                        ),
                        child: image,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CoverFX(accent, phase, effects),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return phone
              ? SizedBox.square(
                  dimension: widget.size,
                  child: FittedBox(
                    child: Padding(
                      padding: EdgeInsets.all(effects.isEmpty ? 0 : 42),
                      child: rendered,
                    ),
                  ),
                )
              : rendered;
        },
      ),
    ),
  );
}

class _DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, 0)
    ..lineTo(s.width, s.height * .5)
    ..lineTo(s.width * .5, s.height)
    ..lineTo(0, s.height * .5)
    ..close();
  @override
  bool shouldReclip(_DiamondClipper old) => false;
}

class _CoverFX extends CustomPainter {
  _CoverFX(this.color, this.phase, Set<String> effects)
    : effects = Set.of(effects);
  final Color color;
  final double phase;
  final Set<String> effects;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (effects.contains('cassette')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .1,
            size.height * .3,
            size.width * .8,
            size.height * .45,
          ),
          const Radius.circular(12),
        ),
        paint..color = color.withValues(alpha: .75),
      );
      for (final x in [.3, .7]) {
        canvas.drawCircle(
          Offset(size.width * x, size.height * .52),
          radius * .25,
          paint,
        );
      }
      canvas.drawLine(
        Offset(size.width * .3, size.height * .64),
        Offset(size.width * .7, size.height * .64),
        paint,
      );
    }
    if (effects.contains('crosshair')) {
      paint
        ..color = color.withValues(alpha: .8)
        ..strokeWidth = 2;
      for (final p in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        final sx = p.dx == 0 ? 1.0 : -1.0, sy = p.dy == 0 ? 1.0 : -1.0;
        canvas.drawLine(
          p + Offset(sx * 6, sy * 22),
          p + Offset(sx * 6, sy * 6),
          paint,
        );
        canvas.drawLine(
          p + Offset(sx * 6, sy * 6),
          p + Offset(sx * 22, sy * 6),
          paint,
        );
      }
    }
    if (effects.contains('halo')) {
      for (var i = 0; i < 2; i++) {
        paint.color = (i == 0 ? color : Colors.pinkAccent).withValues(
          alpha: .7,
        );
        canvas.drawCircle(
          center +
              Offset(
                math.cos(phase + i * math.pi) * radius * .4,
                math.sin(phase + i * math.pi) * radius * .4,
              ),
          radius * .7,
          paint,
        );
      }
    }
    if (effects.contains('frame')) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.sin(phase) * .06);
      paint.color = color.withValues(alpha: .7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width + 14,
            height: size.height + 14,
          ),
          const Radius.circular(24),
        ),
        paint,
      );
      canvas.restore();
    }
    if (effects.contains('portal')) {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius + 8 + i * 8),
          phase * (i.isEven ? 1 : -1) + i,
          math.pi * 1.35,
          false,
          paint,
        );
      }
    }
    if (effects.contains('ripple')) {
      for (var i = 0; i < 3; i++) {
        final progress = (phase / (math.pi * 2) * 3 + i / 3) % 1;
        paint.color = color.withValues(alpha: (1 - progress) * .4);
        canvas.drawCircle(center, radius * (.55 + progress * .7), paint);
      }
    }
    if (effects.contains('shards')) {
      paint.style = PaintingStyle.fill;
      for (var i = 0; i < 6; i++) {
        final angle = phase + i * math.pi / 3;
        final p =
            center +
            Offset(
              math.cos(angle) * (radius + 16),
              math.sin(angle) * (radius + 16),
            );
        paint.color = Color.lerp(
          color,
          Colors.white,
          i / 7,
        )!.withValues(alpha: .7);
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - 7)
            ..lineTo(p.dx + 5, p.dy)
            ..lineTo(p.dx, p.dy + 7)
            ..lineTo(p.dx - 5, p.dy)
            ..close(),
          paint,
        );
      }
    }
    if (effects.contains('scan')) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      );
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: .2);
      for (double y = 0; y < size.height; y += 7) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      final y = (phase / (math.pi * 2) * 4 % 1) * size.height;
      paint
        ..color = Colors.white.withValues(alpha: .65)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CoverFX old) =>
      old.phase != phase ||
      old.color != color ||
      !setEquals(old.effects, effects);
}
