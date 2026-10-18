import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/music.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.song, this.radius = 16});
  final Song song;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: song.cover.isNotEmpty
        ? Image.memory(
            base64Decode(song.cover),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _art(),
          )
        : song.coverUrl.isNotEmpty
        ? Image.network(
            gatewayImage(song.coverUrl),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _art(),
          )
        : _art(),
  );
  Widget _art() => CustomPaint(
    painter: _CoverPainter(Color(song.color)),
    child: LayoutBuilder(
      builder: (context, size) => Stack(
        children: [
          Positioned(
            left: 18,
            top: 18,
            child: Text(
              'VOCA / ARCHIVE',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .7),
                fontSize: math.min(11, size.maxWidth / 18),
                letterSpacing: 2,
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white.withValues(alpha: .9),
              size: size.maxWidth * .36,
            ),
          ),
          Positioned(
            left: 18,
            bottom: 16,
            child: Text(
              song.voice,
              style: TextStyle(
                color: Colors.white,
                fontSize: math.min(14, size.maxWidth / 13),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, const Color(0xFF182D39), .5)!],
        ).createShader(rect),
    );
    final center = Offset(size.width * .75, size.height * .42);
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
        center,
        size.width * (.12 + i * .075),
        Paint()
          ..color = Colors.white.withValues(alpha: .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .85),
      size.width * .3,
      Paint()..color = Colors.white.withValues(alpha: .06),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) => oldDelegate.color != color;
}
