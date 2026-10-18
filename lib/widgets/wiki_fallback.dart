import 'package:flutter/material.dart';
import 'song_detail.dart';

class WikiFallback extends StatelessWidget {
  const WikiFallback({super.key, required this.url, this.width, this.height});
  final String url;
  final double? width, height;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    width: width,
    height: height,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => TextButton.icon(
      onPressed: () => openSource(context, Uri.parse(url)),
      icon: const Icon(Icons.broken_image_outlined),
      label: const Text('原站图片受限 · 查看原图'),
    ),
  );
}
