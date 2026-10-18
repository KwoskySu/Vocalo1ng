import 'package:flutter/material.dart';
import '../services/theme_art.dart';

class ThemeArtView extends StatelessWidget {
  const ThemeArtView({
    super.key,
    required this.art,
    this.light = false,
    this.opacity = .5,
  });
  final ThemeArt art;
  final bool light;
  final double opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: opacity,
          child: ColorFiltered(
            // The licensed originals use white paper. Remove that white at
            // render time so the current palette remains the backdrop.
            colorFilter: const ColorFilter.matrix([
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              -.333,
              -.333,
              -.333,
              1,
              0,
            ]),
            child: Image.network(
              art.image,
              alignment: Alignment.centerRight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(art.color).withValues(alpha: .28),
                (light ? Colors.white : const Color(0xFF07101D)).withValues(
                  alpha: .12,
                ),
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
      ],
    ),
  );
}
