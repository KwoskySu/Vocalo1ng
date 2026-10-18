import 'package:flutter/material.dart';
import '../services/playback.dart';
import '../services/song_theme.dart';

class CoverDeck extends StatelessWidget {
  const CoverDeck({
    super.key,
    required this.playback,
    required this.child,
    required this.size,
  });
  final double size;
  final Playback playback;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!songAppearance.coverControls) return child;
    final style = songAppearance.coverDeck;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          Align(
            alignment: style == 0
                ? Alignment.center
                : style == 3
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(style == 0 ? 80 : 14),
              ),
              child: StreamBuilder<bool>(
                stream: playback.player.stream.playing,
                initialData: playback.player.state.playing,
                builder: (context, snap) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (style == 1 || style == 2)
                        IconButton(
                          tooltip: '封面上一首',
                          onPressed: playback.previous,
                          icon: const Icon(
                            Icons.skip_previous,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      IconButton(
                        tooltip: snap.data! ? '封面暂停' : '封面播放',
                        onPressed: playback.loading
                            ? null
                            : () => playback.player.playOrPause(),
                        icon: Icon(
                          snap.data! ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: style == 0 ? 34 : 25,
                        ),
                      ),
                      if (style == 1 || style == 2)
                        IconButton(
                          tooltip: '封面下一首',
                          onPressed: playback.next,
                          icon: const Icon(
                            Icons.skip_next,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
