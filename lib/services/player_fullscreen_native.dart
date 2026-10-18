import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

bool playerFullscreenActive = false;
final _changes = StreamController<bool>.broadcast();
Stream<bool> get playerFullscreenChanges => _changes.stream;
Future<void> setPlayerFullscreen(bool enabled) async {
  if (Platform.isAndroid) {
    await const MethodChannel(
      'vocalo1ng/runtime',
    ).invokeMethod('fullscreen', enabled);
  } else if (Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  } else if (Platform.isWindows) {
    await const MethodChannel(
      'vocalo1ng/window',
    ).invokeMethod('fullscreen', enabled);
  } else {
    throw UnsupportedError('此平台暂未提供窗口全屏');
  }
  playerFullscreenActive = enabled;
  _changes.add(enabled);
}
