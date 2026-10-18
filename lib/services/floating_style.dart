import 'package:shared_preferences/shared_preferences.dart';

const floatingStyles = [
  '经典桌面',
  '双行轮播',
  '毛玻璃卡片',
  '迷你播放器',
  '霓虹字幕',
  '极简横条',
  '电台字幕',
  '聚焦舞台',
];
const floatingColors = [
  0xFFFFFFFF,
  0xFFFFDD55,
  0xFF91F1EC,
  0xFFFF95CB,
  0xFFBDA5FF,
  0xFF9CFFB2,
  0xFF75BCFF,
  0xFFFFA976,
];
const floatingEffects = ['清晰粗体', '细体', '描边', '霓虹光晕', '斜体', '宽字距'];
const floatingFonts = ['NotoSansSC', 'NotoSerifSC', 'ZCOOLKuaiLe', 'monospace'];

class FloatingStyle {
  FloatingStyle({
    this.mode = 0,
    this.size = 24,
    this.translation = true,
    this.opacity = .92,
    this.color = 0,
    this.effect = 0,
    this.font = 0,
  });
  int mode;
  int color, effect, font;
  double size, opacity;
  bool translation;
  static Future<FloatingStyle> load() async {
    final p = await SharedPreferences.getInstance();
    return FloatingStyle(
      mode: (p.getInt('floating.mode') ?? 0).clamp(
        0,
        floatingStyles.length - 1,
      ),
      size: (p.getDouble('floating.size') ?? 24).clamp(16, 40),
      translation: p.getBool('floating.translation') ?? true,
      opacity: (p.getDouble('floating.opacity') ?? .92).clamp(0, 1),
      color: (p.getInt('floating.color') ?? 0).clamp(
        0,
        floatingColors.length - 1,
      ),
      effect: (p.getInt('floating.effect') ?? 0).clamp(
        0,
        floatingEffects.length - 1,
      ),
      font: (p.getInt('floating.font') ?? 0).clamp(0, floatingFonts.length - 1),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('floating.mode', mode);
    await p.setDouble('floating.size', size);
    await p.setBool('floating.translation', translation);
    await p.setDouble('floating.opacity', opacity);
    await p.setInt('floating.color', color);
    await p.setInt('floating.effect', effect);
    await p.setInt('floating.font', font);
  }
}
