import 'music.dart';

class ThemeArt {
  const ThemeArt(this.id, this.name, this.credit, this.year, this.color);
  final String id, name, credit;
  final int year, color;
  String get image =>
      gatewayImage('https://piapro.net/intl/images/popup_$id.jpg');
  String get source => 'https://piapro.net/intl/en_for_creators.html';
  String get attribution =>
      '$credit, © Crypton Future Media, Inc. $year · CC BY-NC 3.0';
}

const themeArts = [
  ThemeArt('miku', '未来青空', 'Hatsune Miku', 2007, 0xFF278E91),
  ThemeArt('rin', '镜音日光', 'Kagamine Rin', 2007, 0xFFB38722),
  ThemeArt('len', '镜音电波', 'Kagamine Len', 2007, 0xFFB59A24),
  ThemeArt('luka', '巡音夜樱', 'Megurine Luka', 2009, 0xFFAA628A),
  ThemeArt('kaito', '海蓝回声', 'KAITO', 2006, 0xFF365CAC),
  ThemeArt('meiko', '绯红舞台', 'MEIKO', 2004, 0xFFA33E4A),
];

ThemeArt? selectedThemeArt(
  String id, {
  String identity = '',
  int fallback = 0,
}) {
  if (id == 'cover') return null;
  if (id == 'auto') {
    final text = identity.toLowerCase();
    for (final (pattern, key) in [
      ('初音|miku|ミク', 'miku'),
      ('镜音铃|鏡音リン|kagamine rin', 'rin'),
      ('镜音连|鏡音レン|kagamine len', 'len'),
      ('巡音|luka|ルカ', 'luka'),
      ('kaito', 'kaito'),
      ('meiko', 'meiko'),
    ]) {
      if (RegExp(pattern).hasMatch(text)) {
        return themeArts.firstWhere((art) => art.id == key);
      }
    }
    return themeArts[fallback % themeArts.length];
  }
  return themeArts.where((art) => art.id == id).firstOrNull;
}
