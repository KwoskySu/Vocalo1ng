class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration? time;
  final String text;
}

/// Match translations by timestamp, never by array position (instrumental
/// breaks and metadata often make the two LRC files different lengths).
List<String?> alignTranslations(List<LyricLine> original, String translated) {
  final candidates = parseLyrics(
    translated,
  ).where((l) => l.time != null).toList();
  return original.map((line) {
    if (line.time == null) return null;
    LyricLine? best;
    var distance = 701;
    for (final candidate in candidates) {
      final delta = (candidate.time! - line.time!).inMilliseconds.abs();
      if (delta < distance) {
        best = candidate;
        distance = delta;
      }
    }
    return best == null || best.text == line.text ? null : best.text;
  }).toList();
}

int activeLyricIndex(List<LyricLine> lines, Duration position) =>
    lines.lastIndexWhere((line) => line.time != null && line.time! <= position);

List<LyricLine> parseLyrics(String lrc) {
  final result = <LyricLine>[];
  final stamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  for (final raw in lrc.split('\n')) {
    final matches = stamp.allMatches(raw).toList();
    final text = raw.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    if (text.isEmpty) continue;
    if (matches.isEmpty) {
      result.add(LyricLine(null, text));
      continue;
    }
    for (final match in matches) {
      final fraction = (match.group(3) ?? '').padRight(3, '0');
      result.add(
        LyricLine(
          Duration(
            minutes: int.parse(match.group(1)!),
            seconds: int.parse(match.group(2)!),
            milliseconds: int.tryParse(fraction) ?? 0,
          ),
          text,
        ),
      );
    }
  }
  result.sort(
    (a, b) => (a.time ?? Duration.zero).compareTo(b.time ?? Duration.zero),
  );
  return result;
}
