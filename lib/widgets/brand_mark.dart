import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.inverted = false});
  final double size;
  final bool inverted;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Vocalo1ng',
    child: CustomPaint(size: Size.square(size), painter: _Mark(inverted)),
  );
}

class _Mark extends CustomPainter {
  _Mark(this.inverted);
  final bool inverted;
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 100, s.height / 100);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(15),
      ),
      Paint()..color = inverted ? Colors.white : Colors.black,
    );
    final p = Paint()
      ..color = inverted ? Colors.black : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.square;
    c.drawPath(
      Path()
        ..moveTo(20, 28)
        ..lineTo(41, 73)
        ..lineTo(63, 28),
      p,
    );
    c.drawLine(const Offset(76, 28), const Offset(76, 73), p);
    c.drawLine(const Offset(68, 73), const Offset(84, 73), p..strokeWidth = 4);
    c.drawLine(
      const Offset(19, 86),
      const Offset(82, 15),
      Paint()
        ..color = inverted ? Colors.white : Colors.black
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_Mark old) => old.inverted != inverted;
}
