import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'playback.dart';

final _analyzers = Expando<AudioAnalysis>();
AudioAnalysis audioAnalysisFor(Playback p) =>
    _analyzers[p] ??= AudioAnalysis(p);

/// One shared, bounded native analyzer; consumers explicitly lease it.
/// URLs and decoded PCM are never persisted.
class AudioAnalysis extends ChangeNotifier {
  AudioAnalysis(this.playback);
  final Playback playback;
  static const _channel = MethodChannel('vocalo1ng/audio');
  final Set<Object> _owners = {};
  final bands = Float32List(48),
      waveform = Float32List(128),
      previousBands = Float32List(48);
  final sampleClock = Stopwatch()..start();
  int sampleAt = 0;
  double interpolatedBand(int i) {
    final t = ((sampleClock.elapsedMilliseconds - sampleAt) / 50).clamp(
      0.0,
      1.0,
    );
    return previousBands[i] + (bands[i] - previousBands[i]) * t;
  }

  Timer? _timer;
  bool _polling = false, available = false;
  int _generation = 0;
  String? _source;
  String status = '等待音源';
  double get energy => bands.fold<double>(0, (a, b) => a + b) / bands.length;
  void acquire(Object owner) {
    if (!_owners.add(owner) || _timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());
    _poll();
  }

  void retry() {
    _source = null;
    _generation++;
    clear();
    unawaited(_stop());
  }

  void release(Object owner) {
    _owners.remove(owner);
    if (_owners.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
    _source = null;
    _generation++;
    unawaited(_stop());
    clear();
  }

  Future<void> _stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  void clear() {
    bands.fillRange(0, 48, 0);
    previousBands.fillRange(0, 48, 0);
    waveform.fillRange(0, 128, 0);
    available = false;
  }

  Future<void> _poll() async {
    if (_polling || _owners.isEmpty) return;
    _polling = true;
    final generation = _generation;
    try {
      if (kIsWeb) {
        status = '此浏览器暂不支持音源分析';
        notifyListeners();
        return;
      }
      final source = playback.analysisSource;
      if (source == null || playback.loading) {
        if (_source != null) {
          await _stop();
          _source = null;
        }
        clear();
        status = '等待音源';
        notifyListeners();
        return;
      }
      if (_source != source) {
        clear();
        await _channel.invokeMethod('start', {
          'url': source,
          'headers': playback.music.nativeHeaders,
        });
        if (generation != _generation || _owners.isEmpty) {
          await _stop();
          return;
        }
        _source = source;
      }
      final frame = await _channel.invokeMapMethod<String, dynamic>('read', {
        'position': playback.player.state.position.inMilliseconds,
        'playing': playback.player.state.playing,
      });
      if (generation != _generation || _owners.isEmpty) return;
      available = frame?['available'] == true && playback.player.state.playing;
      status = frame?['status'] as String? ?? (available ? '实时音源' : '等待音频');
      if (available) {
        for (var i = 0; i < 48; i++) {
          previousBands[i] = interpolatedBand(i);
        }
        sampleAt = sampleClock.elapsedMilliseconds;
        _copy(bands, frame?['bands'], 0, 1);
        _copy(waveform, frame?['waveform'], -1, 1);
      } else {
        clear();
      }
      notifyListeners();
    } on MissingPluginException {
      status = '当前平台暂不支持音源分析';
      clear();
      notifyListeners();
    } catch (_) {
      status = '分析暂不可用，正在重试';
      _source = null;
      clear();
      notifyListeners();
    } finally {
      _polling = false;
    }
  }

  static void _copy(Float32List out, dynamic input, double low, double high) {
    for (var i = 0; i < out.length; i++) {
      final value = input is List && i < input.length && input[i] is num
          ? (input[i] as num).toDouble()
          : 0.0;
      out[i] = value.isFinite ? value.clamp(low, high) : 0;
    }
  }
}
