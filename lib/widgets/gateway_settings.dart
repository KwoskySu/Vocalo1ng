import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/music.dart';

class GatewaySettings extends StatefulWidget {
  const GatewaySettings({super.key});
  @override
  State<GatewaySettings> createState() => _GatewaySettingsState();
}

class _GatewaySettingsState extends State<GatewaySettings> {
  late final input = TextEditingController(text: gatewayBase());
  String? status;
  bool busy = false;
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> useLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vocalo1ng.connection.mode', 'local');
    await prefs.remove('vocalo1ng.gateway');
    nativeGatewayOverride = null;
    if (mounted) setState(() => status = '已切换为本机独立运行，重新打开应用后生效。无需电脑。');
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final uri = Uri.tryParse(input.text.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      setState(() => status = '请输入服务根地址，例如 http://192.168.1.8:5418');
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    final probe = MusicService(base: uri.origin);
    try {
      final response = await probe.request('/api/health');
      if (response['ok'] != true || response['provider'] != 'personal') {
        throw StateError('服务不匹配');
      }
      await (await SharedPreferences.getInstance()).setString(
        'vocalo1ng.gateway',
        uri.origin,
      );
      await (await SharedPreferences.getInstance()).setString(
        'vocalo1ng.connection.mode',
        'lan',
      );
      if (mounted) setState(() => status = '已验证并保存。完全关闭应用后重新打开，即使用新地址。');
    } catch (_) {
      if (mounted) {
        setState(() => status = '无法连接该可选服务。请检查地址、网络及对端服务；安卓可切回本机独立运行。');
      }
    } finally {
      probe.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '运行方式与可选局域网',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '安卓默认在手机内部运行音乐服务，移动网络或 Wi-Fi 均可，无需电脑。跨端数据请使用 JSON。仅在需要时手动连接自己信任的局域网服务。',
          ),
          if (android)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FilledButton.icon(
                onPressed: busy ? null : useLocal,
                icon: const Icon(Icons.phone_android),
                label: const Text('使用手机本机服务（默认）'),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: input,
            decoration: const InputDecoration(
              labelText: '可选局域网服务地址',
              hintText: 'http://192.168.1.8:5418',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? '正在验证…' : '验证并使用可选服务'),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(status!),
            ),
        ],
      ),
    ),
  );
}
