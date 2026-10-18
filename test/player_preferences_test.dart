import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocashelf/services/floating_style.dart';
import 'package:vocashelf/services/bar_preferences.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('transparent lyrics and selected type persist without opacity clamping',() async {
    SharedPreferences.setMockInitialValues({});
    final style=FloatingStyle(opacity:0,color:3,effect:2,font:1);
    await style.save();
    final restored=await FloatingStyle.load();
    expect(restored.opacity,0);expect(restored.color,3);expect(restored.effect,2);expect(restored.font,1);
  });
  test('player button selection survives reopening',() async {
    SharedPreferences.setMockInitialValues({});
    final settings=BarPreferences();await settings.set({'百科','收藏夹'});
    final restored=BarPreferences();await restored.load();
    expect(restored.visible,{'百科','收藏夹'});
  });
}
