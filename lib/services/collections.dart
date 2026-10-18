import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music.dart';

final collections = Collections();

class Collections extends ChangeNotifier {
  final Map<String, MusicTrack> tracks = {};
  final Set<String> liked = {};
  final Map<String, Set<String>> folders = {'默认收藏夹': {}};
  final Map<String, Map<String, dynamic>> comments = {};
  final Map<String, Map<String, dynamic>> wikis = {};
  Future<void> _save = Future.value();
  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        'vocalo1ng.collections.v1',
      );
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in data['tracks'] as List) {
        final t = MusicTrack.fromJson(Map<String, dynamic>.from(item));
        tracks[t.id] = t;
      }
      liked.addAll(List<String>.from(data['liked'] ?? []));
      folders.clear();
      for (final item in (data['folders'] as Map).entries) {
        folders[item.key as String] = Set<String>.from(item.value);
      }
      for (final item in (data['comments'] as Map? ?? {}).entries) {
        comments[item.key as String] = Map<String, dynamic>.from(item.value);
      }
      for (final item in (data['wikis'] as Map? ?? {}).entries) {
        wikis[item.key as String] = Map<String, dynamic>.from(item.value);
      }
    } catch (_) {
      /* Keep the original preference intact until the next explicit change. */
    }
    notifyListeners();
  }

  Future<void> persist() {
    notifyListeners();
    final snapshot = jsonEncode({
      'tracks': tracks.values.map((t) => t.toJson()).toList(),
      'liked': liked.toList(),
      'folders': folders.map((k, v) => MapEntry(k, v.toList())),
      'comments': comments,
      'wikis': wikis,
    });
    final next = _save.then((_) async {
      if (!await (await SharedPreferences.getInstance()).setString(
        'vocalo1ng.collections.v1',
        snapshot,
      )) {
        throw StateError('收藏保存失败');
      }
    });
    _save = next.catchError((_) {});
    return next;
  }

  Future<void> toggleLike(MusicTrack track) {
    tracks[track.id] = track;
    if (!liked.remove(track.id)) liked.add(track.id);
    return persist();
  }

  Future<void> createFolder(String name) {
    final key = name.trim();
    if (key.isEmpty ||
        key.length > 30 ||
        folders.containsKey(key) ||
        key.toLowerCase().startsWith('vocalo1ng')) {
      throw ArgumentError('名称为空、过长或已存在');
    }
    folders[key] = {};
    return persist();
  }

  Future<void> setFolders(MusicTrack track, Set<String> names) {
    tracks[track.id] = track;
    for (final e in folders.entries) {
      if (names.contains(e.key)) {
        e.value.add(track.id);
      } else {
        e.value.remove(track.id);
      }
    }
    return persist();
  }

  Future<void> toggleComment(String key, Map<String, dynamic> value) {
    if (comments.containsKey(key)) {
      comments.remove(key);
    } else {
      comments[key] = value;
    }
    return persist();
  }

  Future<void> toggleWiki(int id, String title) {
    final key = '$id';
    if (wikis.containsKey(key)) {
      wikis.remove(key);
    } else {
      wikis[key] = {'id': id, 'title': title};
    }
    return persist();
  }
}
