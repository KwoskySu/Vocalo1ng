import 'dart:math' as math;
import 'package:flutter/material.dart';

const textMotionNames = [
  '轻盈上浮',
  '横向揭幕',
  '逐字升起',
  '扇形铺展',
  '流动波浪',
  '弹性落字',
  '中轴展开',
  '交错滑入',
  '光栅切片',
  '折页翻转',
  '悬浮呼吸',
  '电影推镜',
];

/// Layout is shaped once. Only clip rectangles and transforms animate.
/// At most 32 grapheme groups; no split surrogate pairs or per-frame paragraphs.
List<Rect> textMotionSegments(TextPainter p, String text) {
  text = p.text?.toPlainText() ?? text;
  final characters = text.characters.toList();
  final group = math.max(1, (characters.length / 32).ceil());
  final result = <Rect>[];
  int start = 0;
  for (var i = 0; i < characters.length; i += group) {
    final end = start + characters.skip(i).take(group).join().length;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    for (final box in boxes) {
      result.add(box.toRect().inflate(.6));
    }
    start = end;
    if (result.length >= 96) break;
  }
  return result;
}

class TextMotionPreview extends StatefulWidget {
  const TextMotionPreview({
    super.key,
    required this.effect,
    required this.speed,
    required this.amount,
  });
  final int effect;
  final double speed, amount;
  @override
  State<TextMotionPreview> createState() => _TextMotionPreviewState();
}

class _TextMotionPreviewState extends State<TextMotionPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  TextPainter? paragraph;
  List<Rect> boxes = [];
  double width = -1;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void sync() {
    clock.duration = Duration(milliseconds: (1800 / widget.speed).round());
    if (foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!clock.isAnimating) clock.repeat();
    } else {
      clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(TextMotionPreview old) {
    super.didUpdateWidget(old);
    sync();
    if (old.effect != widget.effect) clock.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock.dispose();
    paragraph?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: LayoutBuilder(
      builder: (context, box) {
        if (width != box.maxWidth) {
          width = box.maxWidth;
          paragraph?.dispose();
          paragraph = TextPainter(
            text: TextSpan(
              text: '让歌声穿过光',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'NotoSansSC',
                fontSize: (width * .065).clamp(16, 30),
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: math.max(1, width * .86));
          boxes = textMotionSegments(paragraph!, '让歌声穿过光');
        }
        return RepaintBoundary(
          child: CustomPaint(
            painter: _MotionPreviewPainter(
              paragraph!,
              boxes,
              clock,
              widget.effect,
              widget.amount,
              !MediaQuery.disableAnimationsOf(context),
            ),
            size: Size.infinite,
          ),
        );
      },
    ),
  );
}

class _MotionPreviewPainter extends CustomPainter {
  _MotionPreviewPainter(
    this.p,
    this.boxes,
    this.clock,
    this.effect,
    this.amount,
    this.animate,
  ) : super(repaint: clock);
  final TextPainter p;
  final List<Rect> boxes;
  final Animation<double> clock;
  final int effect;
  final double amount;
  final bool animate;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Offset.zero & s);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff14232b));
    c.translate((s.width - p.width) / 2, (s.height - p.height) / 2);
    paintLyricMotion(
      c,
      p,
      () => boxes,
      effect: effect,
      progress: math.min(1, clock.value * 1.5),
      phase: clock.value * math.pi * 2,
      amount: amount,
      animate: animate,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_MotionPreviewPainter old) =>
      old.p != p ||
      old.effect != effect ||
      old.amount != amount ||
      old.animate != animate;
}

void paintLyricMotion(
  Canvas c,
  TextPainter p,
  List<Rect> Function() segments, {
  required int effect,
  required double progress,
  required double phase,
  required double amount,
  required bool animate,
}) {
  if (!animate) {
    p.paint(c, Offset.zero);
    return;
  }
  final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
  final w = p.width, h = p.height;
  c.save();
  switch (effect) {
    case 1:
      c.clipRect(Rect.fromLTWH(-2, -h * .25, (w + 4) * t, h * 1.5));
    case 6:
      c.clipRect(
        Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: (w + 4) * t,
          height: h * 1.5,
        ),
      );
    case 9:
      c.translate(w / 2, h / 2);
      c.scale(.08 + .92 * t, 1);
      c.skew((1 - t) * .25 * amount, 0);
      c.translate(-w / 2, -h / 2);
    case 10:
      c.translate(0, math.sin(phase * 1.3) * h * .045 * amount);
      c.translate(w / 2, h / 2);
      c.scale(1 + .012 * amount * math.sin(phase * .8));
      c.translate(-w / 2, -h / 2);
    case 11:
      c.translate(w / 2, h / 2);
      c.scale(1 + (1 - t) * .13 * amount);
      c.translate(-w / 2, -h / 2);
    case 8:
      for (var i = 0; i < 8; i++) {
        final y = h * i / 8, dy = h / 8;
        c.save();
        c.translate((i.isEven ? 1 : -1) * (1 - t) * w * .18 * amount, 0);
        c.clipRect(Rect.fromLTWH(-1, y, w + 2, dy + .1));
        p.paint(c, Offset.zero);
        c.restore();
      }
      c.restore();
      return;
    case 2:
    case 3:
    case 4:
    case 5:
    case 7:
      final boxes = segments();
      for (var i = 0; i < boxes.length; i++) {
        final r = boxes[i];
        final local = ((progress - i / math.max(1, boxes.length) * .45) / .55)
            .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(local);
        if (local == 0 && effect != 4) continue;
        c.save();
        if (effect == 2) c.translate(0, (1 - eased) * h * .35 * amount);
        if (effect == 3) {
          c.translate(r.center.dx, h * .8);
          c.rotate(
            (i / math.max(1, boxes.length - 1) - .5) *
                (1 - eased) *
                1.2 *
                amount,
          );
          c.translate(-r.center.dx, -h * .8);
        }
        if (effect == 4)
          c.translate(0, math.sin(phase * 2.1 - i * .48) * h * .075 * amount);
        if (effect == 5)
          c.translate(
            0,
            -(1 - eased) * h * .65 * amount +
                math.sin(local * math.pi * 2) * (1 - local) * h * .18 * amount,
          );
        if (effect == 7)
          c.translate((i.isEven ? -1 : 1) * (1 - eased) * w * .12 * amount, 0);
        c.clipRect(r);
        p.paint(c, Offset.zero);
        c.restore();
      }
      c.restore();
      return;
    default:
      c.translate(0, (1 - t) * h * .18 * amount);
  }
  p.paint(c, Offset.zero);
  c.restore();
}
