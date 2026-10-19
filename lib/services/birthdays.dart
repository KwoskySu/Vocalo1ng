import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SingerBirthday {
  const SingerBirthday(
    this.id,
    this.name,
    this.month,
    this.day,
    this.wiki,
    this.color, [
    this.note = '诞生 / 首发纪念日',
  ]);
  final String id, name, wiki, note;
  final int month, day, color;
  DateTime next(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    var date = DateTime.utc(now.year, month, day);
    if (date.isBefore(today)) date = DateTime.utc(now.year + 1, month, day);
    return date;
  }

  int days(DateTime now) =>
      next(now).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  String get source => Uri.https('voca.wiki', '/$wiki').toString();
}

const singerBirthdays = [
  SingerBirthday('miku', '初音未来', 8, 31, '初音未来', 0xff39b9ac),
  SingerBirthday('rin', '镜音铃', 12, 27, '镜音铃·连', 0xffe5ae36),
  SingerBirthday('len', '镜音连', 12, 27, '镜音铃·连', 0xffd89929),
  SingerBirthday('luka', '巡音流歌', 1, 30, '巡音流歌', 0xffca769d),
  SingerBirthday('meiko', 'MEIKO', 11, 5, 'MEIKO', 0xffc95162),
  SingerBirthday(
    'kaito',
    'KAITO',
    2,
    17,
    'KAITO',
    0xff4b7ac4,
    'Crypton 发售纪念日；Yamaha 历为 2月14日',
  ),
  SingerBirthday('gumi', 'GUMI', 6, 26, 'GUMI', 0xff81a54c),
  SingerBirthday('ia', 'IA', 1, 27, 'IA', 0xffb98ebc),
  SingerBirthday('yukari', '结月缘', 12, 22, '结月缘', 0xff9580c3),
  SingerBirthday('tianyi', '洛天依', 7, 12, '洛天依', 0xff74b8b3, '角色生日'),
  SingerBirthday('yanhe', '言和', 7, 11, '言和', 0xff6eaaa5, '角色生日'),
  SingerBirthday('ling', '乐正绫', 4, 12, '乐正绫', 0xffcd6251, '角色生日'),
  SingerBirthday(
    'teto',
    '重音Teto',
    4,
    1,
    '重音Teto',
    0xffba4563,
    '角色诞生日 · UTAU / Synthesizer V',
  ),
];

class BirthdayPreferences extends ChangeNotifier {
  final selected = <String>{};
  final images = <String, Uint8List>{};
  Future<void> _saving = Future.value();
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    selected.addAll(
      (p.getStringList('birthdays.selected') ?? []).where(
        (id) => singerBirthdays.any((s) => s.id == id),
      ),
    );
    try {
      final raw = jsonDecode(p.getString('birthdays.images') ?? '{}') as Map;
      for (final e in raw.entries) {
        images[e.key as String] = base64Decode(e.value as String);
      }
    } catch (_) {
      /* Keep malformed preference untouched until an explicit edit. */
    }
    notifyListeners();
  }

  Future<void> toggle(String id) {
    if (!selected.remove(id)) selected.add(id);
    return save();
  }

  Future<void> setImage(String id, Uint8List? bytes) {
    if (bytes == null) {
      images.remove(id);
    } else {
      images[id] = bytes;
    }
    return save();
  }

  Future<void> save() {
    notifyListeners();
    final ids = selected.toList(),
        encoded = jsonEncode(
          images.map((k, v) => MapEntry(k, base64Encode(v))),
        );
    final task = _saving.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('birthdays.selected', ids);
      await p.setString('birthdays.images', encoded);
    });
    _saving = task.catchError((_) {});
    return task;
  }
}
