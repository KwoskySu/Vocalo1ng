import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class Library extends ChangeNotifier {
  Library(this.preferences);
  final SharedPreferences preferences;
  List<Song> songs = List.of(seedSongs);
  bool recovered = false;
  Future<void> _pendingSave = Future.value();

  void load() {
    final raw = preferences.getString('vocashelf.library.v1');
    if (raw == null) return;
    try {
      final decoded = (jsonDecode(raw) as List)
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (decoded.isEmpty) throw const FormatException('Empty library');
      songs = decoded;
    } catch (_) {
      recovered = true;
      // Preserve the original value so that damaged data is recoverable.
    }
  }

  Future<void> update(Song song) {
    songs = [
      for (final current in songs)
        if (current.id == song.id) song else current,
    ];
    notifyListeners();
    return _save();
  }

  void reload() {
    load();
    notifyListeners();
  }

  Future<void> add(Song song) {
    songs = [song, ...songs];
    notifyListeners();
    return _save();
  }

  Future<void> _save() {
    final snapshot = Song.encode(songs);
    final save = _pendingSave.then((_) async {
      if (recovered) {
        final original = preferences.getString('vocashelf.library.v1');
        if (original != null &&
            !await preferences.setString(
              'vocashelf.library.recovery',
              original,
            )) {
          throw StateError('无法备份原始数据');
        }
        recovered = false;
      }
      if (!await preferences.setString('vocashelf.library.v1', snapshot)) {
        throw StateError('保存失败，请导出备份后重试');
      }
    });
    _pendingSave = save.catchError((_) {});
    return save;
  }
}
