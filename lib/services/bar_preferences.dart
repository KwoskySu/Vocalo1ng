import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const barActions = ['歌词', '百科', '喜爱', '收藏夹', '播放列表', '音质与悬浮歌词', '本地音频'];
final barPreferences = BarPreferences();

class BarPreferences extends ChangeNotifier {
  Set<String> visible = barActions.toSet();
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList('vocalo1ng.bar.actions');
    if (saved != null) visible = saved.where(barActions.contains).toSet();
    notifyListeners();
  }

  Future<void> set(Set<String> value) async {
    visible = value;
    await (await SharedPreferences.getInstance()).setStringList(
      'vocalo1ng.bar.actions',
      visible.toList(),
    );
    notifyListeners();
  }
}
