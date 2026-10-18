import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

/// Desktop release ships a private gateway beside the application.
Future<void> startBundledGateway() async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('vocalo1ng/runtime');
    await channel
        .invokeMethod<bool>('start')
        .timeout(const Duration(seconds: 45));
    for (var i = 0; i < 80; i++) {
      try {
        final response = await http
            .get(Uri.parse('http://127.0.0.1:5418/api/health'))
            .timeout(const Duration(milliseconds: 500));
        if (response.statusCode == 200 && response.body.contains('personal')) {
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final log = await channel.invokeMethod<String>('diagnostics');
    throw StateError('手机内置音乐服务未能启动。请重试或复制诊断信息。\n${log ?? ''}');
  }
  if (!Platform.isWindows) return;
  // Display-name changes must not discard the existing preferences or logins.
  final roaming = Platform.environment['APPDATA'];
  if (roaming != null) {
    final previous = File(
      '$roaming/app.vocashelf/Vocalo1ng-better player/shared_preferences.json',
    );
    final current = File(
      '$roaming/app.vocashelf/Vocalo1ng/shared_preferences.json',
    );
    if (!await current.exists() && await previous.exists()) {
      await current.parent.create(recursive: true);
      await previous.copy(current.path);
    }
  }
  final base = File(Platform.resolvedExecutable).parent.path;
  final gateway = Directory('$base/gateway');
  if (!await File('${gateway.path}/runtime/node.exe').exists()) return;
  Future<bool> ready() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5418/api/health'))
          .timeout(const Duration(milliseconds: 500));
      return response.statusCode == 200 && response.body.contains('personal');
    } catch (_) {
      return false;
    }
  }

  if (await ready()) return;
  final user = Platform.environment['LOCALAPPDATA'] ?? base;
  await Process.start(
    '${gateway.path}/runtime/node.exe',
    ['server/index.mjs'],
    workingDirectory: gateway.path,
    mode: ProcessStartMode.detached,
    environment: {
      'VOCASHELF_HOST': '127.0.0.1',
      'VOCASHELF_PORT': '5418',
      'VOCASHELF_SESSION_DIR': '$user/Vocalo1ng/gateway-session',
      'VOCASHELF_QQ_PYTHON': '${gateway.path}/runtime/python/python.exe',
    },
  );
  for (var i = 0; i < 20; i++) {
    if (await ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}
