import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SongThemePreset {
  const SongThemePreset(this.name, this.seed, this.accent);
  final String name;
  final Color seed, accent;
  Color get background => Color.lerp(seed, Colors.white, .93)!;
  Color get panel => Color.lerp(seed, Colors.white, .86)!;
}

const songThemes = <SongThemePreset>[
  SongThemePreset('薄荷未来', Color(0xFF238B82), Color(0xFF77DCC5)),
  SongThemePreset('樱色告白', Color(0xFFB34978), Color(0xFFFFB5D2)),
  SongThemePreset('深海回声', Color(0xFF285B9A), Color(0xFF7DCAE0)),
  SongThemePreset('镜音日光', Color(0xFF99721A), Color(0xFFFFDB68)),
  SongThemePreset('巡音玫瑰', Color(0xFFA33F7D), Color(0xFFF7A4CB)),
  SongThemePreset('电光紫域', Color(0xFF7944BD), Color(0xFFC6A4FF)),
  SongThemePreset('重音绯红', Color(0xFFAD384F), Color(0xFFFF9DAD)),
  SongThemePreset('洛水天青', Color(0xFF348497), Color(0xFF9BE2E7)),
  SongThemePreset('萤火森林', Color(0xFF497E40), Color(0xFFB1DF87)),
  SongThemePreset('橘子汽水', Color(0xFFAD652D), Color(0xFFFFBF7D)),
  SongThemePreset('午夜靛蓝', Color(0xFF404D9A), Color(0xFFA9AFF2)),
  SongThemePreset('云端棉花', Color(0xFF647A9F), Color(0xFFCADCF8)),
  SongThemePreset('霓虹桃乐', Color(0xFFA0389E), Color(0xFFF0A0EC)),
  SongThemePreset('银河航线', Color(0xFF5554AE), Color(0xFFADAFF7)),
  SongThemePreset('青柠脉冲', Color(0xFF637C24), Color(0xFFD5EA82)),
  SongThemePreset('琥珀唱片', Color(0xFF926629), Color(0xFFE8C98B)),
  SongThemePreset('冰川极光', Color(0xFF267D87), Color(0xFF8CE1DC)),
  SongThemePreset('蓝莓星球', Color(0xFF6251A4), Color(0xFFC6B8F5)),
  SongThemePreset('草莓电台', Color(0xFFAD4C62), Color(0xFFFFBDCA)),
  SongThemePreset('月光水母', Color(0xFF3D719B), Color(0xFFA8DAEF)),
  SongThemePreset('珊瑚海岸', Color(0xFFB56554), Color(0xFFFFBDB0)),
  SongThemePreset('雨后苔原', Color(0xFF4B806C), Color(0xFFA5D8BA)),
  SongThemePreset('热带白昼', Color(0xFF288D70), Color(0xFF91E3B5)),
  SongThemePreset('雾中薰衣', Color(0xFF80609C), Color(0xFFD9BDEB)),
  SongThemePreset('星尘银幕', Color(0xFF67718B), Color(0xFFC7D0E4)),
  SongThemePreset('落日诗篇', Color(0xFFB65E3E), Color(0xFFFFC69A)),
  SongThemePreset('金鱼花火', Color(0xFFAE4340), Color(0xFFFFACA0)),
  SongThemePreset('机械心跳', Color(0xFF527B85), Color(0xFFA6D7DF)),
  SongThemePreset('葡萄苏打', Color(0xFF884D94), Color(0xFFDCB3E9)),
  SongThemePreset('北极星轨', Color(0xFF35678C), Color(0xFF9AC9EF)),
  SongThemePreset('白桃幻梦', Color(0xFFAB697B), Color(0xFFF6C6D4)),
  SongThemePreset('翡翠秘境', Color(0xFF2F8074), Color(0xFF98D9CA)),
  SongThemePreset('单色回声', Color(0xFF242424), Color(0xFFECECEC)),
  SongThemePreset('酸性黄绿', Color(0xFF5E7118), Color(0xFFE3FF81)),
  SongThemePreset('冷却液蓝', Color(0xFF15567C), Color(0xFF78D9FF)),
  SongThemePreset('故障红屏', Color(0xFF84283B), Color(0xFFFF758F)),
  SongThemePreset('静电青紫', Color(0xFF5A3F82), Color(0xFFD0ACFF)),
  SongThemePreset('胶片棕影', Color(0xFF71533A), Color(0xFFEBCFA6)),
  SongThemePreset('深空银灰', Color(0xFF414C5B), Color(0xFFD1E0ED)),
  SongThemePreset('甜梦荧粉', Color(0xFF8E436C), Color(0xFFFFC0E7)),
];
int stableThemeIndex(String value) =>
    value.runes.fold<int>(0, (hash, n) => ((hash * 31) + n) & 0x7fffffff) %
    songThemes.length;
int nearestTheme(Color color) {
  final hsv = HSVColor.fromColor(color);
  double distance(SongThemePreset p) {
    final candidate = HSVColor.fromColor(p.seed);
    final hue = (hsv.hue - candidate.hue).abs();
    return (hue > 180 ? 360 - hue : hue) +
        (hsv.saturation - candidate.saturation).abs() * 35;
  }

  var best = 0;
  for (var i = 1; i < songThemes.length; i++) {
    if (distance(songThemes[i]) < distance(songThemes[best])) best = i;
  }
  return best;
}

Future<Color?> extractCoverColor(ImageProvider provider) async {
  final stream = provider.resolve(const ImageConfiguration());
  final ready = Completer<ui.Image>();
  final listener = ImageStreamListener(
    (info, _) {
      if (!ready.isCompleted) ready.complete(info.image);
    },
    onError: (Object e, StackTrace? stack) {
      if (!ready.isCompleted) ready.completeError(e);
    },
  );
  stream.addListener(listener);
  late ui.Image image;
  try {
    image = await ready.future.timeout(const Duration(seconds: 12));
  } finally {
    stream.removeListener(listener);
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  final bytes = data.buffer.asUint8List();
  double r = 0, g = 0, b = 0, total = 0;
  final stride =
      ((image.width * image.height / 1500).ceil().clamp(1, 100000)) * 4;
  for (var i = 0; i + 3 < bytes.length; i += stride) {
    final max = [
      bytes[i],
      bytes[i + 1],
      bytes[i + 2],
    ].reduce((a, b) => a > b ? a : b);
    final min = [
      bytes[i],
      bytes[i + 1],
      bytes[i + 2],
    ].reduce((a, b) => a < b ? a : b);
    if (bytes[i + 3] < 160 || max < 35 || min > 235) continue;
    final weight = 1 + (max - min) / 50;
    r += bytes[i] * weight;
    g += bytes[i + 1] * weight;
    b += bytes[i + 2] * weight;
    total += weight;
  }
  return total == 0
      ? null
      : Color.fromARGB(
          255,
          (r / total).round(),
          (g / total).round(),
          (b / total).round(),
        );
}

final songAppearance = SongAppearance();

class SongAppearance extends ChangeNotifier {
  int index = 0, lyricStyle = 0, generation = 0;
  int scrollStyle = 0;
  int lyricFont = 0;
  double lyricScale = 1;
  final Set<String> lyricEffects = {};
  String themeArt = 'cover';
  bool coverControls = false;
  int coverDeck = 0;
  final Set<String> coverEffects = {};
  bool automatic = true;
  SongThemePreset get preset => songThemes[index];
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    automatic = prefs.getBool('autoSongTheme') ?? true;
    index = (prefs.getInt('songTheme') ?? 0).clamp(0, songThemes.length - 1);
    lyricStyle = (prefs.getInt('lyricStyle') ?? 0).clamp(0, 11);
    scrollStyle = (prefs.getInt('lyricScrollStyle') ?? 0).clamp(0, 12);
    coverControls = prefs.getBool('coverControls') ?? false;
    coverDeck = (prefs.getInt('coverDeck') ?? 0).clamp(0, 3);
    lyricFont = (prefs.getInt('lyricFont') ?? 0).clamp(0, 3);
    lyricScale = (prefs.getDouble('lyricScale') ?? 1).clamp(.75, 1.5);
    themeArt = 'cover';
    lyricEffects.clear();
    lyricEffects.addAll(prefs.getStringList('lyricEffects') ?? []);
    coverEffects.clear();
    coverEffects.addAll(prefs.getStringList('coverEffects') ?? []);
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoSongTheme', automatic);
      await prefs.setInt('songTheme', index);
      await prefs.setInt('lyricStyle', lyricStyle);
      await prefs.setInt('lyricScrollStyle', scrollStyle);
      await prefs.setStringList('coverEffects', coverEffects.toList());
      await prefs.setInt('lyricFont', lyricFont);
      await prefs.setDouble('lyricScale', lyricScale);
      await prefs.setString('themeArt', themeArt);
      await prefs.setStringList('lyricEffects', lyricEffects.toList());
      await prefs.setBool('coverControls', coverControls);
      await prefs.setInt('coverDeck', coverDeck);
    } catch (_) {}
  }

  void select(int value) {
    generation++;
    index = value;
    automatic = false;
    notifyListeners();
    save();
  }

  void setAutomatic(bool value) {
    automatic = value;
    generation++;
    notifyListeners();
    save();
  }

  void setLyricStyle(int value) {
    lyricStyle = value;
    notifyListeners();
    save();
  }

  void toggleCoverEffect(String effect) {
    if (!coverEffects.remove(effect)) coverEffects.add(effect);
    notifyListeners();
    save();
  }

  void setScrollStyle(int value) {
    scrollStyle = value;
    notifyListeners();
    save();
  }

  void setTypography({int? font, double? scale}) {
    if (font != null) lyricFont = font.clamp(0, 3);
    if (scale != null) lyricScale = scale.clamp(.75, 1.5);
    notifyListeners();
    save();
  }

  void toggleLyricEffect(String effect) {
    if (!lyricEffects.remove(effect)) lyricEffects.add(effect);
    notifyListeners();
    save();
  }

  void selectArt(String id) {
    themeArt = id;
    notifyListeners();
    save();
  }

  void setCoverControls(bool value) {
    coverControls = value;
    notifyListeners();
    save();
  }

  void setCoverDeck(int value) {
    coverDeck = value;
    notifyListeners();
    save();
  }

  Future<void> adapt(String identity, String cover) async {
    if (!automatic) return;
    final revision = ++generation;
    index = stableThemeIndex(identity);
    notifyListeners();
    if (cover.isEmpty) return;
    try {
      final color = await extractCoverColor(NetworkImage(cover));
      if (color != null && revision == generation && automatic) {
        index = nearestTheme(color);
        notifyListeners();
      }
    } catch (_) {
      /* Stable title-based palette remains available when artwork fails. */
    }
  }
}
