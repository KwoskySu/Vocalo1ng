import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../models/music.dart';
import 'music.dart';
import 'song_theme.dart';
import 'queue_order.dart';
export 'queue_order.dart' show PlayMode;

class Playback extends ChangeNotifier {
  Playback(this.music) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      androidSubscription = player.stream.playing.listen((_) => syncAndroid());
      _android.setMethodCallHandler((call) async {
        if (call.method == 'refreshPlayback') {
          await syncAndroid();
          return;
        }
        if (call.method != 'transport') return;
        final action = call.arguments as String? ?? '';
        if (action.startsWith('queue:')) {
          selectAt(int.tryParse(action.substring(6)) ?? -1);
          return;
        }
        if (action.startsWith('seek:')) {
          await player.seek(
            Duration(milliseconds: int.tryParse(action.substring(5)) ?? 0),
          );
          await syncAndroid();
          return;
        }
        switch (action) {
          case 'next':
            next();
          case 'previous':
            previous();
          case 'play':
            await player.play();
          case 'pause':
            await player.pause();
          case 'toggle':
            await player.playOrPause();
        }
      });
    }
    errorSubscription = player.stream.error.listen((_) {
      error = '音频加载失败，请重试或更换歌曲。';
      loading = false;
      notifyListeners();
    });
    completeSubscription = player.stream.completed.listen((complete) {
      if (complete && !loading && index >= 0) {
        next(completed: true);
      }
    });
    positionSubscription = player.stream.position.listen((position) {
      if (position.inSeconds ~/ 5 != _androidBucket) {
        _androidBucket = position.inSeconds ~/ 5;
        syncAndroid();
      }
      if (position > Duration.zero && error != null) {
        error = null;
        notifyListeners();
      }
    });
    durationSubscription = player.stream.duration.listen((_) => syncAndroid());
    bufferingSubscription = player.stream.buffering.listen(
      (_) => syncAndroid(),
    );
  }
  int _androidBucket = -1;
  Future<void> syncAndroid() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        (current == null && localName == null)) {
      return;
    }
    try {
      final hasSource = current == null || _androidSourceId == current?.id;
      await _android.invokeMethod('playback', {
        'playing': hasSource && player.state.playing,
        'buffering': hasSource && player.state.buffering,
        'mediaId': current?.id ?? localName ?? '',
        'title': current?.title ?? localName ?? 'Vocalo1ng',
        'artist': current?.artist ?? '',
        'cover': current == null ? '' : music.image(current!.cover),
        'position': hasSource ? player.state.position.inMilliseconds : 0,
        'duration': hasSource && player.state.duration > Duration.zero
            ? player.state.duration.inMilliseconds
            : current?.duration ?? 0,
        'buffered': hasSource ? player.state.buffer.inMilliseconds : 0,
        'index': index,
        'count': queue.length,
        'queue': [
          for (
            var i = (index - 20).clamp(0, queue.length);
            i < queue.length && i <= index + 30;
            i++
          )
            {
              'id': queue[i].id,
              'title': queue[i].title,
              'artist': queue[i].artist,
              'index': i,
            },
        ],
      });
    } catch (_) {}
  }

  final MusicService music;
  static const _android = MethodChannel('vocalo1ng/runtime');
  StreamSubscription<bool>? androidSubscription;
  final Player player = Player();
  late final StreamSubscription<String> errorSubscription;
  late final StreamSubscription<bool> completeSubscription;
  late final StreamSubscription<Duration> positionSubscription;
  List<MusicTrack> queue = [];
  int index = -1;
  MusicTrack? current;
  String? localName, error;
  bool loading = false, preview = false;
  int generation = 0;
  String? _androidSourceId;
  late final StreamSubscription<Duration> durationSubscription;
  late final StreamSubscription<bool> bufferingSubscription;
  String quality = 'standard';
  Future<void> setQuality(String value) async {
    final track = current;
    if (track == null) return;
    final at = player.state.position;
    final wasPlaying = player.state.playing;
    final request = ++generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final source = await music.stream(track.id, quality: value);
      if (request != generation) return;
      await player.open(Media(source.url, httpHeaders: music.nativeHeaders));
      await player.seek(at);
      if (!wasPlaying) await player.pause();
      quality = value;
      preview = source.preview;
    } catch (e) {
      if (request == generation) error = '$e';
    } finally {
      if (request == generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  final order = QueueOrder();
  PlayMode get mode => order.mode;
  void setMode(PlayMode mode) {
    order.mode = mode;
    order.reset();
    notifyListeners();
  }

  void removeAt(int at) {
    if (at < 0 || at >= queue.length || at == index) return;
    queue.removeAt(at);
    if (at < index) index--;
    order.reset();
    notifyListeners();
  }

  void keepCurrentOnly() {
    queue = current == null ? [] : [current!];
    index = current == null ? -1 : 0;
    order.reset();
    notifyListeners();
  }

  void selectAt(int at) {
    if (at < 0 || at >= queue.length) return;
    order.reset();
    play(queue[at]);
  }

  Future<void> play(MusicTrack track, {List<MusicTrack>? tracks}) async {
    final request = ++generation;
    final requestedQuality = current?.id == track.id ? quality : 'standard';
    current = track;
    _androidSourceId = null;
    // A successful quality selection for another song is not an entitlement for
    // this song or provider. New songs begin at the universally requested level.
    quality = requestedQuality;
    localName = null;
    error = null;
    loading = true;
    preview = false;
    if (tracks != null) {
      queue = List.of(tracks);
      order.reset();
    }
    if (!queue.any((s) => s.id == track.id)) queue.add(track);
    index = queue.indexWhere((s) => s.id == track.id);
    syncAndroid();
    notifyListeners();
    music.songWiki.prefetch(track);
    songAppearance.adapt(
      '${track.title} ${track.artist}',
      music.image(track.cover),
    );
    try {
      await player.pause();
      final source = await music.stream(track.id, quality: quality);
      if (request != generation) return;
      preview = source.preview;
      await player.open(Media(source.url, httpHeaders: music.nativeHeaders));
      if (request == generation) {
        _androidSourceId = track.id;
        await syncAndroid();
      }
    } catch (e) {
      if (request == generation) error = '$e';
    } finally {
      if (request == generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> local(String uri, String name) async {
    generation++;
    current = null;
    localName = name;
    queue = [];
    order.reset();
    index = -1;
    preview = false;
    error = null;
    loading = false;
    notifyListeners();
    try {
      await player.open(Media(uri));
    } catch (_) {
      error = '无法播放该音频文件';
      notifyListeners();
    }
  }

  void previous() {
    final target = order.previous(index, queue.length);
    if (target != null) play(queue[target]);
  }

  void next({bool completed = false}) {
    final target = order.next(index, queue.length, completed: completed);
    if (target != null) play(queue[target]);
  }

  @override
  void dispose() {
    generation++;
    errorSubscription.cancel();
    completeSubscription.cancel();
    positionSubscription.cancel();
    durationSubscription.cancel();
    bufferingSubscription.cancel();
    androidSubscription?.cancel();
    player.dispose();
    super.dispose();
  }
}
