import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PvPlayer extends StatelessWidget {
  const PvPlayer({super.key, required this.bvid, this.pageUrl});
  final String bvid;
  final String? pageUrl;
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    key: ValueKey(pageUrl ?? bvid),
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame.src = pageUrl ?? 'about:blank';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.allowFullscreen = true;
      frame.setAttribute('allow', 'autoplay; fullscreen; picture-in-picture');
      frame.setAttribute('title', 'Bilibili PV 播放器');
      frame.setAttribute('sandbox', 'allow-scripts allow-same-origin');
      frame.referrerPolicy = 'strict-origin-when-cross-origin';
    },
  );
}
