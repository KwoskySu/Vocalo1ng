import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/export.dart';

class LoginQrSave extends StatelessWidget {
  const LoginQrSave({super.key, this.url, this.image, this.platform});
  final String? url, image, platform;
  String get name => switch (platform) {
    'netease' => '网易云音乐',
    'bilibili' => '哔哩哔哩',
    'qq' => '手机QQ',
    _ => '对应平台App',
  };
  @override
  Widget build(BuildContext context) {
    final android =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        platform != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (android) ...[
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('保存并打开$name'),
            onPressed: () => save(context, openApp: true),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '在平台App中从相册扫码确认，再返回这里。',
              style: TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        TextButton.icon(
          icon: const Icon(Icons.save_alt),
          label: Text(android ? '仅保存二维码' : '保存二维码 · 本机扫码'),
          onPressed: () => save(context),
        ),
      ],
    );
  }

  Future<void> save(BuildContext context, {bool openApp = false}) async {
    try {
      final Uint8List bytes;
      if (image != null) {
        bytes = base64Decode(image!.split(',').last);
      } else {
        final painter = QrPainter(
          data: url!,
          version: QrVersions.auto,
          eyeStyle: const QrEyeStyle(color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
        canvas.translate(32, 32);
        painter.paint(canvas, const Size(576, 576));
        final picture = recorder.endRecording();
        final raster = await picture.toImage(640, 640);
        bytes = (await raster.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        raster.dispose();
        picture.dispose();
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel(
          'vocalo1ng/runtime',
        ).invokeMethod('saveQr', bytes);
      } else {
        await exportFile(bytes, 'Vocalo1ng-login.png', 'image/png');
      }
      bool opened = false;
      if (openApp) {
        opened =
            await const MethodChannel(
              'vocalo1ng/runtime',
            ).invokeMethod<bool>('openLoginApp', platform) ??
            false;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              openApp && !opened
                  ? '二维码已保存，但未找到可打开的$name。请安装对应App后从相册扫码。'
                  : '请在$name选择扫一扫 → 相册，选取刚保存的二维码并确认，再返回此应用。',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('二维码未保存：$error')));
      }
    }
  }
}
