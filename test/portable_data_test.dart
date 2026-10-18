import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/services/portable_data.dart';
import 'package:vocashelf/models/song.dart';

void main() {
  String file(Map<String, dynamic> data) =>
      jsonEncode({'format': 'vocalo1ng', 'version': 1, 'data': data});
  test('portable data excludes account and connection configuration', () {
    for (final key in [
      'session:http://127.0.0.1:5418',
      'vocalo1ng.gateway',
      'vocalo1ng.connection.mode',
    ]) {
      expect(
        () => parsePortableData(file({key: 'secret'})),
        throwsFormatException,
      );
    }
  });
  test(
    'imports legacy journals and preserves local appearance value types',
    () {
      expect(
        parsePortableData(Song.encode([seedSongs.first])).keys,
        contains('vocashelf.library.v1'),
      );
      final data = parsePortableData(
        file({
          'lyricScale': 1,
          'lyricFont': 2,
          'autoSongTheme': true,
          'coverEffects': ['vinyl'],
        }),
      );
      expect(data['lyricScale'], isA<double>());
      expect(
        () => parsePortableData(file({'lyricFont': 'bad'})),
        throwsFormatException,
      );
      expect(
        () => parsePortableData(
          file({
            'coverEffects': [42],
          }),
        ),
        throwsFormatException,
      );
    },
  );
  test('rejects broken collection structure before changing preferences', () {
    expect(
      () => parsePortableData(
        file({
          'vocalo1ng.collections.v1': jsonEncode({
            'tracks': [],
            'liked': [],
            'folders': {'broken': 'bad'},
          }),
        }),
      ),
      throwsA(anything),
    );
  });
}
