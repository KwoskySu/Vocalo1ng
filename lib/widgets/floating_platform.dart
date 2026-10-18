import '../services/playback.dart';
import '../services/floating_style.dart';
import '../services/lyrics.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

const _channel = MethodChannel('vocalo1ng/floating');
StreamSubscription<Duration>? _position;
void Function()? _detach;
Future<bool> openSystemLyrics(Playback playback, FloatingStyle style) async {
  if (!Platform.isWindows) return false;
  try {
    final opened = await _channel.invokeMethod<bool>('show', {
      'mode': style.mode,
      'size': style.size,
      'opacity': style.opacity,
      'color': floatingColors[style.color],
      'effect': style.effect,
      'font': style.font,
    });
    if (opened != true) return false;
    await _position?.cancel();
    _detach?.call();
    List<LyricLine> lines = [];
    List<String?> translations = [];
    String? id;
    int generation = 0;
    void render(Duration at) {
      final active = activeLyricIndex(lines, at);
      final next = active >= 0 && active + 1 < lines.length
          ? lines[active + 1]
          : null;
      final start = active < 0 ? 0 : lines[active].time!.inMilliseconds;
      final progress = next?.time == null
          ? 1.0
          : ((at.inMilliseconds - start) /
                    (next!.time!.inMilliseconds - start).clamp(1, 1000000))
                .clamp(0.0, 1.0);
      _channel.invokeMethod<void>('update', {
        'title': playback.current?.title ?? '等待播放',
        'original': active < 0
            ? playback.current?.title ?? '等待播放'
            : lines[active].text,
        'translation':
            style.translation && active >= 0 && active < translations.length
            ? translations[active] ?? ''
            : '',
        'next': next?.text ?? '',
        'progress': progress,
        'playing': playback.player.state.playing,
      });
    }

    void changed() {
      final track = playback.current;
      if (track == null || id == track.id) return;
      id = track.id;
      lines = [];
      translations = [];
      final request = ++generation;
      render(playback.player.state.position);
      playback.music
          .lyrics(track.id)
          .then((data) {
            if (request != generation) return;
            lines = parseLyrics(data.original);
            translations = alignTranslations(lines, data.translated);
            render(playback.player.state.position);
          })
          .catchError((_) {});
    }

    playback.addListener(changed);
    _detach = () {
      generation++;
      playback.removeListener(changed);
    };
    _position = playback.player.stream.position.listen(render);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'previous') playback.previous();
      if (call.method == 'toggle') await playback.player.playOrPause();
      if (call.method == 'next') playback.next();
      if (call.method == 'closed') {
        await _position?.cancel();
        _position = null;
        _detach?.call();
        _detach = null;
      }
    });
    changed();
    return true;
  } catch (_) {
    return false;
  }
}
