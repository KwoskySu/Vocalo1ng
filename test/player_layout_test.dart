import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/widgets/player_layout.dart';
import 'package:vocashelf/widgets/theme_settings.dart';

void main() {
  testWidgets(
    'PC keeps desktop settings while Android uses collapsed controls',
    (tester) async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(platform),
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 800)),
              child: const Scaffold(
                body: SingleChildScrollView(child: ThemeSettings()),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byType(ExpansionTile),
          platform == TargetPlatform.windows ? findsNothing : findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  test('maximized and ultrawide desktop keep a large vertical album', () {
    for (final size in [
      const Size(2560, 1380),
      const Size(2560, 720),
      const Size(1280, 720),
    ]) {
      final layout = PlayerLayout(
        viewport: size,
        available: Size(size.width, size.height - 140),
        mobile: false,
        cinema: false,
      );
      expect(layout.landscape, isFalse);
      expect(layout.phone, isFalse);
      expect(layout.horizontalAlbum, isFalse);
      expect(layout.coverSize, greaterThan(250));
    }
  });
  test('Android portrait and landscape retain their compact album sizes', () {
    final portrait = PlayerLayout(
      viewport: const Size(360, 800),
      available: const Size(360, 660),
      mobile: true,
      cinema: false,
    );
    final landscape = PlayerLayout(
      viewport: const Size(844, 390),
      available: const Size(844, 270),
      mobile: true,
      cinema: false,
    );
    expect(portrait.phone, isTrue);
    expect(portrait.coverSize, lessThanOrEqualTo(96));
    expect(landscape.landscape, isTrue);
    expect(landscape.coverSize, lessThanOrEqualTo(96));
  });
  testWidgets('desktop album stays in the center instead of the top left', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: ValueKey('pane'),
              width: 600,
              height: 540,
              child: CenteredAlbumPane(
                child: SizedBox(
                  key: ValueKey('album'),
                  width: 315,
                  height: 400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('album'))),
      tester.getCenter(find.byKey(const ValueKey('pane'))),
    );
    expect(tester.takeException(), isNull);
  });
}
