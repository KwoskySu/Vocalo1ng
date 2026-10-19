import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lyrics.dart';
import 'playback.dart';

bool get desktopModeSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
DesktopOverlay? _overlay;
DesktopOverlay desktopOverlayFor(Playback playback) {
  if (_overlay?.playback != playback) {
    _overlay?.close();
    _overlay = DesktopOverlay(playback);
  }
  return _overlay!;
}

class DesktopOverlay extends ChangeNotifier {
  DesktopOverlay(this.playback);
  final Playback playback;
  static const channel = MethodChannel('vocalo1ng/desktop');
  bool enabled = false,
      busy = false,
      cover = true,
      lyrics = true,
      graph = true,
      progress = true;
  int edge = 1;
  double scale = 1, opacity = .94, extent = .65, offset = .5;
  String? error, song;
  int generation = 0;
  Timer? timer;
  List<LyricLine> lines = [];
  List<String?> translations = [];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    edge = (p.getInt('desktop.edge') ?? 1).clamp(0, 3);
    scale = (p.getDouble('desktop.scale') ?? 1).clamp(.65, 1.5);
    opacity = (p.getDouble('desktop.opacity') ?? .94).clamp(.3, 1);
    extent = (p.getDouble('desktop.extent') ?? .65).clamp(.3, .95);
    offset = (p.getDouble('desktop.offset') ?? .5).clamp(0, 1);
    cover = p.getBool('desktop.cover') ?? true;
    lyrics = p.getBool('desktop.lyrics') ?? true;
    graph = p.getBool('desktop.graph') ?? true;
    progress = p.getBool('desktop.progress') ?? true;
    notifyListeners();
  }

  Map<String, Object> get configuration => {
    'edge': edge,
    'scale': scale,
    'opacity': opacity,
    'extent': extent,
    'offset': offset,
    'showCover': cover,
    'showLyrics': lyrics,
    'showGraph': graph,
    'showProgress': progress,
  };
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('desktop.edge', edge);
    for (final entry in {
      'scale': scale,
      'opacity': opacity,
      'extent': extent,
      'offset': offset,
    }.entries) {
      await p.setDouble('desktop.${entry.key}', entry.value);
    }
    for (final entry in {
      'cover': cover,
      'lyrics': lyrics,
      'graph': graph,
      'progress': progress,
    }.entries) {
      await p.setBool('desktop.${entry.key}', entry.value);
    }
    if (enabled) {
      try {
        await channel.invokeMethod('show', configuration);
        error = null;
      } catch (e) {
        error = '桌面窗口调整失败：$e';
      }
    }
    notifyListeners();
  }

  Future<void> toggle(bool value) async {
    if (!desktopModeSupported) return;
    if (!value) {
      await close();
      return;
    }
    try {
      final ok = await channel.invokeMethod<bool>('show', configuration);
      if (ok != true) throw StateError('无法创建桌面窗口');
      enabled = true;
      error = null;
      song = null;
      timer?.cancel();
      timer = Timer.periodic(const Duration(milliseconds: 300), (_) => sync());
      sync();
    } catch (e) {
      error = '$e';
      enabled = false;
    }
    notifyListeners();
  }

  Future<void> close() async {
    generation++;
    timer?.cancel();
    enabled = false;
    song = null;
    if (desktopModeSupported) {
      try {
        await channel.invokeMethod('close');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> loadTrack(String id) async {
    final request = ++generation;
    lines = [];
    translations = [];
    final track = playback.current;
    // Cover and lyrics are independent: one slow source must not block progress.
    unawaited(() async {
      try {
        if (track == null || track.cover.isEmpty) return;
        final r = await playback.music.client
            .get(playback.music.uri('/api/image', {'url': track.cover}))
            .timeout(const Duration(seconds: 15));
        if (enabled &&
            request == generation &&
            r.statusCode == 200 &&
            r.bodyBytes.length < 4 * 1024 * 1024) {
          await channel.invokeMethod('cover', r.bodyBytes);
        }
      } catch (_) {}
    }());
    try {
      if (track == null) return;
      final data = await playback.music.lyrics(id);
      if (!enabled || request != generation) return;
      lines = parseLyrics(data.original);
      translations = alignTranslations(lines, data.translated);
    } catch (_) {}
  }

  Future<void> sync() async {
    if (!enabled || busy) return;
    busy = true;
    try {
      final id = playback.current?.id ?? playback.localName ?? '';
      if (id != song) {
        song = id;
        await channel.invokeMethod('cover', null);
        unawaited(loadTrack(id));
      }
      final i = activeLyricIndex(lines, playback.player.state.position);
      final duration = playback.player.state.duration.inMilliseconds;
      await channel.invokeMethod('update', {
        'title': playback.current?.title ?? playback.localName ?? '等待播放',
        'artist': playback.current?.artist ?? '',
        'line': i >= 0 ? lines[i].text : '',
        'translation': i >= 0 ? translations[i] ?? '' : '',
        'progress': duration > 0
            ? playback.player.state.position.inMilliseconds / duration
            : 0.0,
        'playing': playback.player.state.playing,
      });
    } catch (e) {
      error = '桌面同步失败：$e';
      notifyListeners();
    } finally {
      busy = false;
    }
  }
}
