import 'dart:async';
import 'lyrics.dart';
import 'playback.dart';

LiveFeed? _liveFeed;
LiveFeed liveFeedFor(Playback playback) {
  if (_liveFeed?.playback != playback) {
    _liveFeed?.stop();
    _liveFeed = LiveFeed(playback);
  }
  return _liveFeed!;
}

/// Publishing is independent of the configuration dialog: OBS keeps updating
/// while the user searches, changes tracks or opens the full lyric page.
class LiveFeed {
  LiveFeed(this.playback);
  final Playback playback;
  Timer? timer;
  Map<String, dynamic> settings = {};
  List<LyricLine> lines = [];
  List<String?> translations = [];
  String? song, url, error;
  String line = '', translation = '', next = '', previous = '';
  bool busy = false, enabled = false;
  int generation = 0;
  void start() {
    if (enabled) return;
    enabled = true;
    generation++;
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => sync());
    sync();
  }

  Future<void> stop() async {
    enabled = false;
    generation++;
    timer?.cancel();
    url = null;
    try {
      await playback.music.request('/api/live/stop', body: {});
    } catch (_) {}
  }

  Future<void> sync() async {
    if (busy || !enabled) return;
    busy = true;
    final revision = generation;
    final p = playback, track = playback.current;
    try {
      if (track?.id != song) {
        song = track?.id;
        lines = [];
        translations = [];
        if (track != null) {
          try {
            final lyrics = await p.music.lyrics(track.id);
            if (!enabled ||
                revision != generation ||
                track.id != p.current?.id) {
              song = null;
              return;
            }
            lines = parseLyrics(lyrics.original);
            translations = alignTranslations(lines, lyrics.translated);
          } catch (_) {}
        }
      }
      if (!enabled || revision != generation || track?.id != p.current?.id) {
        return;
      }
      final i = activeLyricIndex(lines, p.player.state.position);
      line = i >= 0 ? lines[i].text : track?.title ?? '等待播放';
      translation = i >= 0 ? translations[i] ?? '' : '';
      next = i + 1 < lines.length ? lines[i + 1].text : '';
      previous = i > 0 ? lines[i - 1].text : '';
      final response = await p.music.request(
        '/api/live/publish',
        body: {
          ...settings,
          'title': track?.title ?? p.localName ?? 'Vocalo1ng',
          'artist': track?.artist ?? '',
          'cover': track?.cover ?? '',
          'line': line,
          'translation': translation,
          'next': next,
          'previous': previous,
          'playing': p.player.state.playing,
          'position': p.player.state.position.inMilliseconds / 1000,
          'duration': p.player.state.duration.inMilliseconds / 1000,
        },
      );
      if (!enabled || revision != generation) {
        if (!enabled) await p.music.request('/api/live/stop', body: {});
        return;
      }
      url = Uri.parse(
        p.music.base,
      ).resolve(response['path'] as String).toString();
      error = null;
    } catch (e) {
      if (revision == generation) error = '$e';
    } finally {
      busy = false;
    }
  }
}
