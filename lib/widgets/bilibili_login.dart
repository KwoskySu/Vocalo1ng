import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/music.dart';
import 'account_avatar.dart';
import 'login_qr_save.dart';

Future<void> showBilibiliLogin(BuildContext context, MusicService music) =>
    showDialog<void>(
      context: context,
      builder: (_) => BilibiliLogin(music: music),
    );

class BilibiliLogin extends StatefulWidget {
  const BilibiliLogin({super.key, required this.music});
  final MusicService music;
  @override
  State<BilibiliLogin> createState() => _BilibiliLoginState();
}

class _BilibiliLoginState extends State<BilibiliLogin> {
  Timer? timer;
  String? url, error;
  String status = '正在生成二维码…';
  bool loading = false, checking = false, expired = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.music.bilibiliLoggedIn) generate();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    super.dispose();
  }

  Future<void> generate() async {
    timer?.cancel();
    final request = ++generation;
    setState(() {
      loading = true;
      url = null;
      error = null;
      expired = false;
      status = '正在生成二维码…';
    });
    try {
      final result = await widget.music.startBilibiliLogin();
      if (!mounted || generation != request) return;
      setState(() {
        url = result;
        status = '使用哔哩哔哩 App 扫码，并在手机上确认登录';
      });
      timer = Timer.periodic(const Duration(seconds: 3), (_) => check(request));
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  Future<void> check(int request) async {
    if (checking) return;
    checking = true;
    try {
      final code = await widget.music.checkBilibiliLogin();
      if (!mounted || generation != request) return;
      if (code == 0 || code == 86038) timer?.cancel();
      setState(() {
        expired = code == 86038;
        status = switch (code) {
          0 => 'B 站账号已连接',
          86038 => '二维码已过期，请刷新',
          86090 => '扫码成功，请在哔哩哔哩 App 确认登录',
          _ => '等待扫码…',
        };
      });
    } catch (e) {
      timer?.cancel();
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      checking = false;
    }
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.music.refreshBilibiliProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.music.bilibiliProfile;
    return AlertDialog(
      scrollable: true,
      title: Text(profile == null ? '连接 B 站账号' : 'B 站账号'),
      content: SizedBox(
        width: 370,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (profile == null) ...[
                const Text(
                  '扫码连接，无需在应用中输入密码。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF74847C)),
                ),
                const SizedBox(height: 18),
                if (loading)
                  const SizedBox(
                    height: 210,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (url != null && !expired)
                  QrImageView(
                    data: url!,
                    size: 210,
                    backgroundColor: Colors.white,
                  ),
                const SizedBox(height: 12),
                if (url != null && !expired)
                  LoginQrSave(url: url, platform: 'bilibili'),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.8),
                ),
                TextButton(
                  onPressed: loading ? null : generate,
                  child: const Text('刷新二维码'),
                ),
              ] else ...[
                AccountAvatar(music: widget.music, bilibili: true, size: 52),
                const SizedBox(height: 12),
                Text(
                  profile['nickname'] as String,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'UID ${profile['uid']} · 账号已连接',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF74847C),
                  ),
                ),
                TextButton(
                  onPressed: loading ? null : refresh,
                  child: Text(loading ? '正在刷新…' : '刷新账号状态'),
                ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              const Divider(),
              const SizedBox(height: 6),
              const Text(
                '登录后，内置播放器直接使用此账号的播放权限与可用画质。画质切换在应用内完成。',
                style: TextStyle(fontSize: 12, height: 1.8),
              ),
              const SizedBox(height: 12),
              const Text(
                '账号连接与网易云互相独立。连接凭证在本机加密保存，服务重启后自动恢复；平台凭证失效时需重新扫码。',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.7,
                  color: Color(0xFF74847C),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (profile != null)
          TextButton(
            onPressed: loading
                ? null
                : () async {
                    try {
                      await widget.music.logoutBilibili();
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => error = '$e');
                    }
                  },
            child: const Text('断开本机连接'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
