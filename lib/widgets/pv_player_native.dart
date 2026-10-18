import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as windows;

class PvPlayer extends StatefulWidget {
  const PvPlayer({super.key, required this.bvid, this.pageUrl});
  final String bvid;
  final String? pageUrl;
  @override
  State<PvPlayer> createState() => _PvPlayerState();
}

class _PvPlayerState extends State<PvPlayer> {
  windows.WebviewController? desktop;
  WebViewController? mobile;
  bool ready = false;
  String? error;
  String get url => widget.pageUrl ?? 'about:blank';
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      if (Platform.isWindows) {
        desktop = windows.WebviewController();
        await desktop!.initialize();
        if (!mounted) return;
        await desktop!.loadUrl(url);
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        mobile = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted);
        if (mobile!.platform is AndroidWebViewController) {
          await (mobile!.platform as AndroidWebViewController)
              .setMediaPlaybackRequiresUserGesture(false);
        }
        await mobile!.loadRequest(Uri.parse(url));
      } else {
        throw StateError('此平台暂不支持嵌入播放器');
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => error = '播放器未能加载，可尝试在 B 站打开。Windows 需要 WebView2 运行时。');
      }
    }
  }

  @override
  void didUpdateWidget(PvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bvid != widget.bvid || oldWidget.pageUrl != widget.pageUrl) {
      desktop?.loadUrl(url);
      mobile?.loadRequest(Uri.parse(url));
    }
  }

  @override
  void dispose() {
    desktop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)),
      );
    }
    if (!ready) return const Center(child: CircularProgressIndicator());
    return desktop != null
        ? windows.Webview(desktop!)
        : WebViewWidget(controller: mobile!);
  }
}
