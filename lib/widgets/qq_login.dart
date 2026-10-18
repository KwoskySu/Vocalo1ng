import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/music.dart';
import 'account_avatar.dart';
import 'login_qr_save.dart';

Future<void> showQQLogin(BuildContext context, MusicService music) =>
    showDialog<void>(
      context: context,
      builder: (_) => QQLogin(music: music),
    );

class QQLogin extends StatefulWidget {
  const QQLogin({super.key, required this.music});
  final MusicService music;
  @override
  State<QQLogin> createState() => _QQLoginState();
}

class _QQLoginState extends State<QQLogin> {
  Timer? timer;
  String? image, error;
  String status = '正在生成二维码…';
  bool busy = false, checking = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.music.qqProfile == null) generate();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    super.dispose();
  }

  Future<void> generate() async {
    timer?.cancel();
    final revision = ++generation;
    setState(() {
      busy = true;
      image = null;
      error = null;
    });
    try {
      final value = await widget.music.startQQLogin();
      if (!mounted || generation != revision) return;
      setState(() {
        image = value;
        status = '使用手机 QQ 扫码并确认登录 QQ 音乐';
      });
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => check(revision),
      );
    } catch (e) {
      if (mounted && revision == generation) setState(() => error = '$e');
    } finally {
      if (mounted && revision == generation) setState(() => busy = false);
    }
  }

  Future<void> check(int revision) async {
    if (checking) return;
    checking = true;
    try {
      final code = await widget.music.checkQQLogin();
      if (!mounted || revision != generation) return;
      if (['DONE', 'TIMEOUT', 'REFUSE'].contains(code)) timer?.cancel();
      setState(() {
        status = switch (code) {
          'DONE' => 'QQ 音乐已登录，登录状态已保存',
          'CONF' => '已扫码，请在手机 QQ 确认',
          'TIMEOUT' => '二维码已过期，请刷新',
          'REFUSE' => '登录已取消',
          _ => '等待扫码…',
        };
      });
    } catch (e) {
      timer?.cancel();
      if (mounted && revision == generation) setState(() => error = '$e');
    } finally {
      checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('QQ 音乐 · 音频账号'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.music.qqProfile != null) ...[
            AccountAvatar(
              music: widget.music,
              bilibili: false,
              qq: true,
              size: 56,
            ),
            Text(widget.music.qqProfile!['nickname'] as String),
            const Text('登录状态已在本机加密保存'),
          ] else ...[
            if (busy)
              const SizedBox(
                height: 210,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (image != null)
              Image.memory(
                base64Decode(image!.split(',').last),
                width: 210,
                height: 210,
              ),
            Text(status, textAlign: TextAlign.center),
            if (image != null) LoginQrSave(image: image, platform: 'qq'),
            TextButton(
              onPressed: busy ? null : generate,
              child: const Text('刷新二维码'),
            ),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          const Text(
            '音频账号与视频账号独立。只有平台凭证失效或主动退出后才需重新登录。',
            style: TextStyle(fontSize: 11, height: 1.7),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.music.qqProfile != null)
        TextButton(
          onPressed: () async {
            await widget.music.logoutQQ();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('退出 QQ 音乐'),
        ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('完成'),
      ),
    ],
  );
}
