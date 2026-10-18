import 'dart:math' as math;
import 'package:flutter/material.dart';

class Atmosphere extends CustomPainter {
  Atmosphere(this.color, this.phase, this.style);
  final Color color;
  final double phase;
  final int style;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .08);
    if (style == 9) {
      paint
        ..color = Colors.white.withValues(alpha: .12)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 18; i++) {
        final y = size.height * (i / 18 + phase * .1) % size.height;
        canvas.drawPath(
          Path()
            ..moveTo(0, y)
            ..lineTo(size.width * .4, y - 70)
            ..lineTo(size.width * .65, y + 40)
            ..lineTo(size.width, y - 50),
          paint,
        );
      }
    } else if (style == 10) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      for (var i = 0; i < 35; i++) {
        paint.color = color.withValues(alpha: .06 + i * .003);
        canvas.drawCircle(
          Offset(
            size.width * .5 + math.sin(phase * math.pi * 2) * 80,
            size.height * .5,
          ),
          20 + i * 15,
          paint,
        );
      }
    } else if (style == 11) {
      paint
        ..color = color.withValues(alpha: .25)
        ..strokeWidth = 1;
      final points = List.generate(
        40,
        (i) => Offset(
          size.width * ((i * .618 + phase * .02) % 1),
          size.height * ((i * .414 + phase * .03) % 1),
        ),
      );
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(points[i], 2, paint);
        if (i > 0 && (points[i] - points[i - 1]).distance < 180) {
          canvas.drawLine(points[i], points[i - 1], paint);
        }
      }
    } else if (style == 6) {
      final center = size.center(Offset.zero);
      for (var i = 0; i < 70; i++) {
        final angle = i * 2.39996;
        final reach = ((i / 70 + phase * 3) % 1);
        paint
          ..color = color.withValues(alpha: reach * .5)
          ..strokeWidth = 1 + reach * 2;
        canvas.drawLine(
          center +
              Offset(math.cos(angle), math.sin(angle)) *
                  reach *
                  size.longestSide *
                  .65,
          center +
              Offset(math.cos(angle), math.sin(angle)) *
                  (reach + .035) *
                  size.longestSide *
                  .65,
          paint,
        );
      }
    } else if (style == 7) {
      for (var i = 0; i < 9; i++) {
        paint
          ..color = Color.lerp(
            color,
            Colors.pinkAccent,
            i / 9,
          )!.withValues(alpha: .08)
          ..style = PaintingStyle.fill;
        final x = size.width * (.5 + .4 * math.sin(i + phase * math.pi * 2));
        final y =
            size.height * (.5 + .4 * math.cos(i * .7 + phase * math.pi * 2));
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 180)
            ..lineTo(x + 190, y + 100)
            ..lineTo(x - 190, y + 100)
            ..close(),
          paint,
        );
      }
    } else if (style == 8) {
      paint.color = Colors.deepOrangeAccent.withValues(alpha: .2);
      canvas.drawCircle(
        Offset(size.width * .5, size.height * .45),
        size.shortestSide * .2,
        paint,
      );
      paint
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: .25);
      for (var i = -8; i <= 8; i++) {
        canvas.drawLine(
          Offset(size.width * .5 + i * 10, size.height * .6),
          Offset(size.width * .5 + i * 100, size.height),
          paint,
        );
      }
      for (var i = 0; i < 12; i++) {
        final t = (i / 12 + phase * 2) % 1;
        final y = size.height * (.6 + t * t * .4);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (style == 5) {
      for (double x = 0; x < size.width; x += 32) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += 32) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (style == 3) {
      for (var i = 0; i < 50; i++) {
        final height = 25 + 45 * (1 + math.sin(i * .5 + phase * math.pi * 8));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              i * size.width / 50,
              size.height - height,
              size.width / 70,
              height,
            ),
            const Radius.circular(5),
          ),
          paint,
        );
      }
    } else {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
      canvas.drawCircle(
        Offset(
          size.width * (.3 + .15 * math.sin(phase * math.pi * 2)),
          size.height * .25,
        ),
        size.width * .25,
        paint,
      );
      canvas.drawCircle(
        Offset(
          size.width * .8,
          size.height * (.65 + .1 * math.cos(phase * math.pi * 2)),
        ),
        size.width * .2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(Atmosphere old) =>
      old.phase != phase || old.color != color || old.style != style;
}
