import 'dart:convert';
import '../models/song.dart';
import '../models/music.dart';

const portableKeys = {
  'vocashelf.library.v1',
  'vocalo1ng.collections.v1',
  'vocalo1ng.bar.actions',
  'autoSongTheme',
  'songTheme',
  'lyricStyle',
  'lyricScrollStyle',
  'coverControls',
  'coverDeck',
  'lyricFont',
  'lyricScale',
  'lyricEffects',
  'coverEffects',
  'themeArt',
};

Map<String, dynamic> parsePortableData(String text) {
  final decoded = jsonDecode(text);
  final Map<String, dynamic> values;
  if (decoded is List) {
    values = {'vocashelf.library.v1': jsonEncode(decoded)};
  } else {
    if (decoded is! Map ||
        decoded['format'] != 'vocalo1ng' ||
        decoded['version'] != 1 ||
        decoded['data'] is! Map) {
      throw const FormatException('不是受支持的 Vocalo1ng 数据文件');
    }
    values = Map<String, dynamic>.from(decoded['data']);
  }
  for (final entry in values.entries) {
    final key = entry.key, value = entry.value;
    if (!portableKeys.contains(key)) throw const FormatException('包含非跨端数据项');
    if (const {'autoSongTheme', 'coverControls'}.contains(key)) {
      if (value is! bool) throw const FormatException('开关格式错误');
    } else if (const {
      'songTheme',
      'lyricStyle',
      'lyricScrollStyle',
      'coverDeck',
      'lyricFont',
    }.contains(key)) {
      if (value is! int || value < 0 || value > 1000) {
        throw const FormatException('样式格式错误');
      }
    } else if (key == 'lyricScale') {
      if (value is! num || !value.isFinite || value < .5 || value > 3) {
        throw const FormatException('字号格式错误');
      }
      values[key] = value.toDouble();
    } else if (const {
      'lyricEffects',
      'coverEffects',
      'vocalo1ng.bar.actions',
    }.contains(key)) {
      if (value is! List || !value.every((v) => v is String)) {
        throw const FormatException('样式列表格式错误');
      }
    } else if (key == 'themeArt') {
      if (value is! String) throw const FormatException('主题格式错误');
    } else if (key == 'vocashelf.library.v1') {
      final rows = jsonDecode(value as String) as List;
      if (rows.isEmpty) throw const FormatException('曲库不能为空');
      for (final row in rows) {
        Song.fromJson(Map<String, dynamic>.from(row));
      }
    } else if (key == 'vocalo1ng.collections.v1') {
      final c = jsonDecode(value as String) as Map;
      for (final item in c['tracks'] as List) {
        MusicTrack.fromJson(Map<String, dynamic>.from(item));
      }
      List<String>.from(c['liked'] as List);
      for (final folder in (c['folders'] as Map).entries) {
        if (folder.key is! String) throw const FormatException('收藏夹名称错误');
        List<String>.from(folder.value as List);
      }
      for (final group in ['comments', 'wikis']) {
        for (final item in (c[group] as Map? ?? {}).entries) {
          if (item.key is! String || item.value is! Map) {
            throw const FormatException('收藏内容格式错误');
          }
        }
      }
    }
  }
  return values;
}
