import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'song_detail.dart';

class WikiFallback extends StatefulWidget {
  const WikiFallback({super.key, required this.url, this.width, this.height});
  final String url;
  final double? width, height;
  @override
  State<WikiFallback> createState() => _WikiFallbackState();
}

class _WikiFallbackState extends State<WikiFallback> {
  bool failed = false;
  @override
  Widget build(BuildContext context) => failed
      ? TextButton.icon(
          onPressed: () => openSource(context, Uri.parse(widget.url)),
          icon: const Icon(Icons.broken_image_outlined),
          label: const Text('原站图片受限 · 查看原图'),
        )
      : SizedBox(
          width: widget.width ?? 280,
          height: widget.height ?? 220,
          child: HtmlElementView.fromTagName(
            tagName: 'img',
            onElementCreated: (element) {
              final img = element as web.HTMLImageElement;
              img.src = widget.url;
              img.alt = '百科插画';
              img.referrerPolicy = 'no-referrer';
              img.style.cssText = 'width:100%;height:100%;object-fit:contain';
              img.addEventListener(
                'error',
                ((web.Event e) {
                  if (mounted) setState(() => failed = true);
                }).toJS,
              );
            },
          ),
        );
}
