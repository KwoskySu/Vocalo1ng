import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/music.dart';
import 'song_detail.dart';
import 'login_qr_save.dart';

Future<bool> showMusicLogin(BuildContext context, MusicService music) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => MusicLogin(music: music),
    ) ??
    false;

class MusicLogin extends StatefulWidget {
  const MusicLogin({super.key, required this.music});
  final MusicService music;
  @override
  State<MusicLogin> createState() => _MusicLoginState();
}

class _MusicLoginState extends State<MusicLogin> {
  Timer? timer;
  String? url, error;
  String status = '正在生成二维码…';
  bool busy = false, checking = false, expired = false;
  @override
  void initState() {
    super.initState();
    generate();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> generate() async {
    timer?.cancel();
    setState(() {
      busy = true;
      url = null;
      error = null;
      expired = false;
      status = '正在生成二维码…';
    });
    try {
      final value = await widget.music.startLogin();
      if (!mounted) return;
      setState(() {
        url = value;
        status = '请用网易云音乐 App 扫码，并在手机上确认';
      });
      timer = Timer.periodic(const Duration(seconds: 3), (_) => check());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    if (checking) return;
    checking = true;
    try {
      final code = await widget.music.checkLogin();
      if (!mounted) return;
      if (code == 803) {
        timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
      if (code == 800) timer?.cancel();
      setState(() {
        expired = code == 800;
        status = switch (code) {
          800 => '二维码已过期，请刷新',
          802 => '扫码成功，请在网易云 App 确认登录',
          _ => '等待扫码，登录后可使用每日推荐和云端歌单',
        };
      });
    } catch (e) {
      timer?.cancel();
      if (mounted) setState(() => error = '$e');
    } finally {
      checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('连接网易云音乐'),
    content: SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '扫码登录，无需在这里输入账号密码。',
              style: TextStyle(fontSize: 12, color: Color(0xFF74847C)),
            ),
            const SizedBox(height: 22),
            if (busy)
              const SizedBox(
                height: 210,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (url != null && !expired)
              QrImageView(data: url!, size: 210, backgroundColor: Colors.white),
            const SizedBox(height: 16),
            if (url != null && !expired)
              LoginQrSave(url: url, platform: 'netease'),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.8),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (url != null && !expired)
              TextButton(
                onPressed: () => openSource(context, Uri.parse(url!)),
                child: const Text('在本机打开网易云登录链接'),
              ),
            const SizedBox(height: 8),
            const Text(
              '个人使用的第三方适配。登录状态在本机加密保存；关闭页面和重启服务后自动恢复，平台凭证失效时需重新登录。',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF74847C),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('稍后再说'),
      ),
      TextButton(onPressed: busy ? null : generate, child: const Text('刷新二维码')),
    ],
  );
}
