import 'package:flutter/foundation.dart';
import '../models/music.dart';
import 'wiki.dart';

String normalizedWikiTitle(String text) => text.toLowerCase().replaceAll(
  RegExp(r'\s|[\p{P}\p{S}]', unicode: true),
  '',
);
List<String> wikiQueries(MusicTrack track) => {
  track.title,
  track.title.replaceAll(RegExp(r'[（(【\[].*?[）)】\]]'), '').trim(),
  ...RegExp(
    r'[（(]([^）)]+)[）)]',
  ).allMatches(track.title).map((m) => m.group(1)!),
  ...track.alias.split(' / '),
}.where((name) => name.trim().isNotEmpty).toList();
double wikiMatchScore(WikiEntry entry, MusicTrack track) {
  final value = normalizedWikiTitle(entry.title);
  final titles = wikiQueries(track);
  var best = 0.0;
  for (final title in titles) {
    final key = normalizedWikiTitle(title);
    final score = value == key
        ? 100.0
        : value.startsWith(key)
        ? 82.0
        : value.contains(key)
        ? 65.0
        : 0.0;
    if (score > best) best = score;
    if (normalizedWikiTitle(entry.snippet).contains(key) &&
        key.length >= 3 &&
        best < 55) {
      best = 55;
    }
  }
  if (normalizedWikiTitle(track.producer).isNotEmpty &&
      value.contains(normalizedWikiTitle(track.producer))) {
    best += 12;
  }
  if (RegExp(r'翻唱|翻调|专辑|用户|消歧义').hasMatch(entry.title)) best -= 18;
  final alternate = RegExp(
    r'remix|remake|arrange|cover|现场|live|翻唱|翻调|翻奏|重制',
    caseSensitive: false,
  );
  if (alternate.hasMatch(entry.title) && !alternate.hasMatch(track.title)) {
    best -= 45;
  }
  return best;
}

class SongWikiLookup extends ChangeNotifier {
  SongWikiLookup({WikiService? service}) : service = service ?? WikiService();
  final WikiService service;
  final Map<String, List<WikiEntry>> results = {};
  final Map<String, Future<void>> pending = {};
  final Set<String> failed = {};
  bool closed = false;
  Future<void> prefetch(MusicTrack track, {bool retry = false}) {
    if (pending.containsKey(track.id)) return pending[track.id]!;
    if (results.containsKey(track.id) && !failed.contains(track.id) && !retry) {
      return Future.value();
    }
    final future = _lookup(track);
    pending[track.id] = future;
    return future;
  }

  Future<void> _lookup(MusicTrack track) async {
    try {
      final names = wikiQueries(track).take(4);
      final found = <int, WikiEntry>{};
      for (final name in names) {
        final entries = await service.search(name);
        for (final entry in entries) {
          found[entry.pageId] = entry;
        }
        if (entries.any((e) => wikiMatchScore(e, track) >= 100)) break;
      }
      final entries =
          found.values.where((e) => wikiMatchScore(e, track) >= 50).toList()
            ..sort(
              (a, b) =>
                  wikiMatchScore(b, track).compareTo(wikiMatchScore(a, track)),
            );
      if (closed) return;
      if (results.length >= 100) results.remove(results.keys.first);
      results[track.id] = entries;
      failed.remove(track.id);
    } catch (_) {
      if (!closed) {
        failed.add(track.id);
        results.remove(track.id);
      }
    } finally {
      pending.remove(track.id);
      if (!closed) notifyListeners();
    }
  }

  @override
  void dispose() {
    closed = true;
    service.dispose();
    super.dispose();
  }
}
