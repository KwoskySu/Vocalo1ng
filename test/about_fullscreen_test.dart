import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/services/app_info.dart';
import 'package:vocashelf/services/player_fullscreen.dart';
import 'package:vocashelf/widgets/about.dart';

void main() {
  testWidgets(
    'exiting while fullscreen entry is pending restores state after the in-flight request',
    (tester) async {
      final gate = Completer<void>();
      final calls = <bool>[];
      const channel = MethodChannel('vocalo1ng/window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.arguments as bool);
        if (call.arguments == true) await gate.future;
        return true;
      });
      final enter = setPlayerFullscreen(true);
      await tester.pump();
      final exit = setPlayerFullscreen(false);
      gate.complete();
      await tester.pump();
      await Future.wait([enter, exit]);
      expect(calls, [true, false]);
      expect(playerFullscreenActive, isFalse);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    },
  );
  testWidgets(
    'about page fits phone portrait and landscape and includes project actions',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(844, 320)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(1.3),
              ),
              child: const AboutVocalo1ng(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('关于 Vocalo1ng'), findsOneWidget);
        expect(find.text('版本 $appVersion'), findsOneWidget);
        expect(find.text('GitHub 开源项目'), findsOneWidget);
        expect(projectUrl, 'https://github.com/KwoskySu/Vocalo1ng');
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'window fullscreen can enter and restore through its native channel',
    (tester) async {
      final calls = <bool>[];
      const channel = MethodChannel('vocalo1ng/window');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'fullscreen');
            calls.add(call.arguments as bool);
            return call.arguments;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await setPlayerFullscreen(true);
      expect(playerFullscreenActive, isTrue);
      await setPlayerFullscreen(false);
      expect(playerFullscreenActive, isFalse);
      expect(calls, [true, false]);
    },
  );
}
