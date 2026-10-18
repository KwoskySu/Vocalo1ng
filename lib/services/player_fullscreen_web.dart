import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get playerFullscreenActive => web.document.fullscreenElement != null;
bool _listening = false;
final StreamController<bool> _changes = StreamController<bool>.broadcast(
  onListen: () {
    if (_listening) return;
    _listening = true;
    web.document.addEventListener(
      'fullscreenchange',
      ((web.Event event) {
        _changes.add(playerFullscreenActive);
      }).toJS,
    );
  },
);
Stream<bool> get playerFullscreenChanges => _changes.stream;
Future<void> setPlayerFullscreen(bool enabled) async {
  if (enabled && !playerFullscreenActive) {
    await web.document.documentElement!.requestFullscreen().toDart;
  } else if (!enabled && playerFullscreenActive) {
    await web.document.exitFullscreen().toDart;
  }
}
