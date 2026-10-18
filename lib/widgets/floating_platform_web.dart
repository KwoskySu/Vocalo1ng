import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../services/playback.dart';
import '../services/lyrics.dart';
import '../services/floating_style.dart';

@JS('documentPictureInPicture.requestWindow')
external JSPromise<web.Window> requestWindow(JSAny options);
Future<bool> openSystemLyrics(Playback playback, FloatingStyle style) async {
  // Browser PiP always has an opaque OS surface. The in-app overlay can keep
  // the requested fully transparent background without hiding the text.
  if (style.opacity == 0) return false;
  try {
    final window = await requestWindow(
      {'width': 520, 'height': style.mode == 5 ? 150 : 300}.jsify()!,
    ).toDart;
    final body = window.document.body!;
    body.style.cssText =
        'margin:0;background:rgba(${style.mode == 4 ? '32,10,48' : '12,16,24'},${style.opacity});color:white;font:${style.size}px sans-serif;text-align:center;padding:18px;box-sizing:border-box;display:flex;min-height:100vh;flex-direction:column;justify-content:center;gap:8px';
    final original = window.document.createElement('div') as web.HTMLDivElement;
    final translation =
        window.document.createElement('div') as web.HTMLDivElement;
    original.style.cssText =
        'font-weight:700;line-height:1.5;${style.mode == 4 ? 'color:#ff8ae6;text-shadow:0 0 12px #f04ce7' : ''}${style.mode == 5 ? 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis' : ''}';
    final ink =
        '#${floatingColors[style.color].toRadixString(16).substring(2)}';
    original.style.color = ink;
    original.style.fontFamily = [
      'sans-serif',
      'serif',
      'cursive',
      'monospace',
    ][style.font];
    original.style.fontWeight = style.effect == 1 ? '400' : '700';
    if (style.effect == 2) {
      original.style.textShadow =
          '1px 1px #000,-1px -1px #000,1px -1px #000,-1px 1px #000';
    }
    if (style.effect == 3) original.style.textShadow = '0 0 14px $ink';
    if (style.effect == 4) original.style.fontStyle = 'italic';
    if (style.effect == 5) original.style.letterSpacing = '4px';
    translation.style.cssText =
        'color:#94e8ed;font-size:${style.size * .68}px;${style.translation ? '' : 'display:none'}';
    final cover = window.document.createElement('img') as web.HTMLImageElement;
    cover.style.cssText =
        'height:68px;width:68px;object-fit:cover;border-radius:12px;align-self:center';
    if (style.mode == 3) body.appendChild(cover);
    body.appendChild(original);
    body.appendChild(translation);
    final following =
        window.document.createElement('div') as web.HTMLDivElement;
    following.style.cssText = 'color:#9ba7b5;font-size:${style.size * .7}px';
    if (style.mode == 1 || style.mode == 7) body.appendChild(following);
    if (style.mode == 6) {
      final heading =
          window.document.createElement('div') as web.HTMLDivElement;
      heading.textContent = playback.current?.title ?? '';
      heading.style.cssText = 'font-size:.5em;opacity:.55';
      body.insertBefore(heading, original);
    }
    final control = window.document.createElement('div') as web.HTMLDivElement;
    final play =
        window.document.createElement('button') as web.HTMLButtonElement;
    final handlers = <void Function()>[];
    void addControl(
      String label,
      void Function() action, [
      web.HTMLButtonElement? button,
    ]) {
      final element =
          button ??
          window.document.createElement('button') as web.HTMLButtonElement;
      element.textContent = label;
      element.style.cssText =
          'border:0;border-radius:20px;background:#ffffff18;color:white;padding:8px 14px;margin:0 4px;cursor:pointer';
      element.addEventListener('click', ((web.Event e) => action()).toJS);
      control.appendChild(element);
    }

    if (style.mode == 2 || style.mode == 3) {
      addControl('上一首', playback.previous);
      addControl('播放 / 暂停', () => playback.player.playOrPause(), play);
      addControl('下一首', () => playback.next());
      body.appendChild(control);
    }
    List<LyricLine> lines = [];
    List<String?> paired = [];
    String? id;
    int generation = 0;
    void changed() {
      final track = playback.current;
      if (track == null || track.id == id) return;
      id = track.id;
      lines = [];
      paired = [];
      final request = ++generation;
      original.textContent = track.title;
      translation.textContent = '';
      following.textContent = '';
      cover.src = playback.music.image(track.cover);
      playback.music
          .lyrics(track.id)
          .then((data) {
            if (request != generation) return;
            lines = parseLyrics(data.original);
            paired = alignTranslations(lines, data.translated);
          })
          .catchError((_) {});
    }

    changed();
    playback.addListener(changed);
    void render(Duration p) {
      final active = activeLyricIndex(lines, p);
      if (active >= 0) {
        original.textContent = lines[active].text;
        translation.textContent = paired[active] ?? '';
        following.textContent = active + 1 < lines.length
            ? lines[active + 1].text
            : '';
        if (style.mode == 0) {
          final start = lines[active].time!.inMilliseconds;
          final end = active + 1 < lines.length
              ? lines[active + 1].time?.inMilliseconds ?? start + 5000
              : start + 5000;
          final percent =
              ((p.inMilliseconds - start) /
                      (end - start).clamp(1, 1000000) *
                      100)
                  .clamp(0, 100);
          original.style.background =
              'linear-gradient(to right,$ink $percent%,white $percent%)';
          original.style.setProperty('background-clip', 'text');
          original.style.color = 'transparent';
        }
      }
    }

    final subscription = playback.player.stream.position.listen(render);
    final playing = playback.player.stream.playing.listen(
      (value) => play.textContent = value ? '暂停' : '播放',
    );
    handlers.add(() {
      subscription.cancel();
      playing.cancel();
    });
    window.addEventListener(
      'pagehide',
      ((web.Event e) {
        generation++;
        for (final cancel in handlers) {
          cancel();
        }
        playback.removeListener(changed);
      }).toJS,
    );
    return true;
  } catch (_) {
    return false;
  }
}
