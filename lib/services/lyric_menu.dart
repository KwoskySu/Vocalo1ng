import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lyricTools = ['视频', '百科', '收藏', '手记', '评论', '样式', '直播', '可视化', '沉浸'];
final lyricMenu = LyricMenu();

class LyricMenu extends ChangeNotifier {
  final visible = lyricTools.toSet();
  int immersiveStyle = 0, textMotion = 0;
  double textMotionSpeed = 1, textMotionAmount = 1;
  double immersiveSize = 1;
  bool immersiveMotion = true;
  bool immersiveStars = false;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList('lyric.menu.tools');
    if (saved != null) {
      visible
        ..clear()
        ..addAll(saved.where(lyricTools.contains));
    }
    if (!p.containsKey('lyric.menu.visualizer.added')) {
      visible.add('可视化');
    }
    textMotion = (p.getInt('lyric.motion.kind') ?? 0).clamp(0, 11);
    textMotionSpeed = (p.getDouble('lyric.motion.speed') ?? 1).clamp(.5, 2);
    textMotionAmount = (p.getDouble('lyric.motion.amount') ?? 1).clamp(
      .25,
      1.5,
    );
    immersiveStyle = (p.getInt('lyric.immersive.v2.style') ?? 0).clamp(0, 8);
    immersiveSize = (p.getDouble('lyric.immersive.size') ?? 1).clamp(.65, 1.6);
    immersiveMotion = p.getBool('lyric.immersive.motion') ?? true;
    immersiveStars = p.getBool('lyric.immersive.stars') ?? false;
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('lyric.menu.tools', visible.toList());
    await p.setBool('lyric.menu.visualizer.added', true);
    await p.setInt('lyric.motion.kind', textMotion);
    await p.setDouble('lyric.motion.speed', textMotionSpeed);
    await p.setDouble('lyric.motion.amount', textMotionAmount);
    await p.setInt('lyric.immersive.v2.style', immersiveStyle);
    await p.setDouble('lyric.immersive.size', immersiveSize);
    await p.setBool('lyric.immersive.motion', immersiveMotion);
    await p.setBool('lyric.immersive.stars', immersiveStars);
  }
}
