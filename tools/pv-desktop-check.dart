// Manual Windows interaction check for the production PV widget. Does not load
// preferences, accounts or the user's library. Launch with PV_CHECK_URL set via
// --dart-define. This harness is not part of the shipped application's entrypoint.
import 'package:flutter/material.dart';
import 'package:vocashelf/widgets/pv_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Vocalo1ng · 内嵌播放器交互验收')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 900,
              height: 560,
              child: PvPlayer(
                bvid: 'BV1s54y1Z7Bi',
                pageUrl: String.fromEnvironment('PV_CHECK_URL'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
