import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlayerLayout {
  PlayerLayout({
    required Size viewport,
    required Size available,
    required bool mobile,
    required bool cinema,
  }) {
    phone = mobile && viewport.shortestSide < 600;
    landscape =
        phone &&
        available.width >= 480 &&
        available.width > available.height * 1.3;
    wide = available.width >= 760 || landscape;
    horizontalAlbum = phone || cinema || (!wide && available.height < 380);
    coverSize = landscape
        ? math.min(96.0, available.height * .35)
        : horizontalAlbum
        ? math.min(phone ? 88.0 : 92.0, available.height * .22)
        : wide
        ? math.min(available.height * .48, 315.0)
        : math.min(available.height * .24, 160.0);
  }
  late final bool phone, landscape, wide, horizontalAlbum;
  late final double coverSize;
}

/// Center a normal desktop album; scroll only when the pane is too short.
class CenteredAlbumPane extends StatelessWidget {
  const CenteredAlbumPane({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

/// A phone in landscape has its own proportions, independent of desktop.
class PhoneLandscapePlayer extends StatelessWidget {
  const PhoneLandscapePlayer({
    super.key,
    required this.album,
    required this.lyrics,
    required this.controls,
  });
  final Widget album, lyrics, controls;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              SizedBox(
                width: math.min(300, box.maxWidth * .32),
                child: CenteredAlbumPane(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: album,
                  ),
                ),
              ),
              VerticalDivider(
                width: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .12),
              ),
              Expanded(child: lyrics),
            ],
          ),
        ),
      ),
      controls,
    ],
  );
}
