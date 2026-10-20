import 'dart:async';
import 'dart:convert';
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
  DesktopOverlay(this.playback) {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'visibility') return;
      enabled = call.arguments == true;
      timer?.cancel();
      generation++;
      song = null;
      if (enabled) {
        timer = Timer.periodic(
          const Duration(milliseconds: 300),
          (_) => sync(),
        );
        sync();
      }
      notifyListeners();
    });
  }
  final Playback playback;
  static const channel = MethodChannel('vocalo1ng/desktop');
  bool enabled = false,
      busy = false,
      cover = true,
      lyrics = true,
      graph = true,
      progress = true,
      transparentBackground = true,
      title = true,
      artist = true,
      translation = true,
      stats = true,
      autoFont = true;
  int edge = 4, style = 0, graphStyle = 0;
  double scale = 1, opacity = .94, extent = 1, offset = .5, graphExtent = .35;
  double fontScale = 1, progressThickness = 4, progressThumb = 5;
  Timer? _previewTimer;
  bool _configBusy = false, _configDirty = false;
  List<String> statItems = ['cpu', 'gpu', 'ram', 'clock'];
  String? error, song;
  int generation = 0;
  Timer? timer, _saveTimer;
  final Map<String, List<double>> layout = {
    'cover': [.06, .18, .20, .40],
    'lyrics': [.32, .22, .61, .33],
    'graph': [.32, .62, .61, .28],
    'stats': [.06, .04, .88, .09],
    'progress': [.04, .94, .92, .06],
  };
  Future<void> save() async {
    notifyListeners();
    _saveTimer?.cancel();
    if (enabled && _previewTimer == null) {
      _previewTimer = Timer(const Duration(milliseconds: 40), () {
        _previewTimer = null;
        _applyLatest();
      });
    }
    _saveTimer = Timer(const Duration(milliseconds: 180), () => _saveNow());
  }

  Future<void> _applyLatest() async {
    if (!enabled) return;
    if (_configBusy) {
      _configDirty = true;
      return;
    }
    _configBusy = true;
    try {
      await channel.invokeMethod('show', configuration);
      error = null;
    } catch (e) {
      error = '桌面窗口调整失败：$e';
    } finally {
      _configBusy = false;
      if (_configDirty && enabled) {
        _configDirty = false;
        unawaited(_applyLatest());
      }
    }
  }

  List<LyricLine> lines = [];
  List<String?> translations = [];
  Future<void>? _loaded;
  Future<void> load() => _loaded ??= _load();
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final saved = jsonDecode(p.getString('desktop.layout.v2') ?? '{}');
      for (final key in layout.keys) {
        final v = saved[key];
        if (v is List &&
            v.length == 4 &&
            v.every((n) => n is num && n.isFinite))
          layout[key] = [for (final n in v) (n as num).toDouble().clamp(0, 1)];
      }
    } catch (_) {}
    for (final v in layout.values) {
      v[0] = v[0].clamp(0, .94);
      v[1] = v[1].clamp(0, .94);
      v[2] = v[2].clamp(.06, 1 - v[0]);
      v[3] = v[3].clamp(.06, 1 - v[1]);
    }
    edge = (p.getInt('desktop.edge') ?? 4).clamp(0, 4);
    scale = (p.getDouble('desktop.scale') ?? 1).clamp(.65, 1.5);
    opacity = (p.getDouble('desktop.opacity') ?? .94).clamp(.3, 1);
    extent = (p.getDouble('desktop.extent') ?? 1).clamp(.3, 1);
    offset = (p.getDouble('desktop.offset') ?? .5).clamp(0, 1);
    style = (p.getInt('desktop.style') ?? 0).clamp(0, 5);
    graphStyle = (p.getInt('desktop.graphStyle') ?? 0).clamp(0, 4);
    graphExtent = (p.getDouble('desktop.graphExtent') ?? .35).clamp(.15, .55);
    stats = p.getBool('desktop.stats') ?? true;
    transparentBackground = p.getBool('desktop.transparentBackground') ?? true;
    autoFont = p.getBool('desktop.autoFont') ?? true;
    progressThickness = (p.getDouble('desktop.progressThickness') ?? 4).clamp(
      1,
      24,
    );
    progressThumb = (p.getDouble('desktop.progressThumb') ?? 5).clamp(0, 20);
    fontScale = (p.getDouble('desktop.fontScale') ?? 1).clamp(.65, 2);
    title = p.getBool('desktop.title') ?? true;
    artist = p.getBool('desktop.artist') ?? true;
    translation = p.getBool('desktop.translation') ?? true;
    statItems =
        p.getStringList('desktop.statItems') ?? ['cpu', 'gpu', 'ram', 'clock'];
    cover = p.getBool('desktop.cover') ?? true;
    lyrics = p.getBool('desktop.lyrics') ?? true;
    graph = p.getBool('desktop.graph') ?? true;
    progress = p.getBool('desktop.progress') ?? true;
    notifyListeners();
  }

  Map<String, Object> get configuration => {
    'layout': layout,
    'edge': edge,
    'style': style,
    'graphStyle': graphStyle,
    'graphExtent': graphExtent,
    'showStats': stats,
    'transparentBackground': transparentBackground,
    'fontScale': fontScale,
    'autoFont': autoFont,
    'progressThickness': progressThickness,
    'progressThumb': progressThumb,
    'showTitle': title,
    'showArtist': artist,
    'showTranslation': translation,
    'statItems': statItems,
    'scale': scale,
    'opacity': opacity,
    'extent': extent,
    'offset': offset,
    'showCover': cover,
    'showLyrics': lyrics,
    'showGraph': graph,
    'showProgress': progress,
  };
  Future<void> _saveNow() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('desktop.layout.v2', jsonEncode(layout));
    await p.setInt('desktop.edge', edge);
    await p.setInt('desktop.style', style);
    await p.setInt('desktop.graphStyle', graphStyle);
    for (final entry in {
      'scale': scale,
      'opacity': opacity,
      'extent': extent,
      'offset': offset,
      'graphExtent': graphExtent,
      'fontScale': fontScale,
      'progressThickness': progressThickness,
      'progressThumb': progressThumb,
    }.entries) {
      await p.setDouble('desktop.${entry.key}', entry.value);
    }
    for (final entry in {
      'cover': cover,
      'lyrics': lyrics,
      'graph': graph,
      'progress': progress,
      'stats': stats,
      'autoFont': autoFont,
      'transparentBackground': transparentBackground,
      'title': title,
      'artist': artist,
      'translation': translation,
    }.entries) {
      await p.setBool('desktop.${entry.key}', entry.value);
    }
    await p.setStringList('desktop.statItems', statItems);
    notifyListeners();
  }

  Future<void> toggle(bool value) async {
    if (!desktopModeSupported) return;
    if (!value) {
      generation++;
      _previewTimer?.cancel();
      _previewTimer = null;
      timer?.cancel();
      enabled = false;
      song = null;
      await channel.invokeMethod('hide');
      notifyListeners();
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
    _saveTimer?.cancel();
    _previewTimer?.cancel();
    _previewTimer = null;
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
