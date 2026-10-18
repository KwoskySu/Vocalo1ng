import 'package:flutter/material.dart';
import 'dart:async';
import 'package:html/dom.dart' as dom;
import 'wiki_fallback.dart'
    if (dart.library.js_interop) 'wiki_fallback_web.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Images keep their source proportions even when a wiki table expands its cell.
Widget? buildWikiImage(dom.Element element) {
  if (element.localName != 'img') return null;
  final source = element.attributes['src'];
  if (source == null || source.isEmpty) {
    return null;
  }
  double? dimension(String key) {
    final value = double.tryParse(element.attributes[key] ?? '');
    return value != null && value > 0 && value.isFinite ? value : null;
  }

  return RetryWikiImage(
    source: source,
    width: dimension('width'),
    height: dimension('height'),
    label: element.attributes['alt'],
  );
}

class RetryWikiImage extends StatefulWidget {
  const RetryWikiImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.label,
  });
  final String source;
  final double? width, height;
  final String? label;
  @override
  State<RetryWikiImage> createState() => _RetryWikiImageState();
}

class _RetryWikiImageState extends State<RetryWikiImage> {
  int attempt = 0;
  Timer? retry;
  @override
  void didUpdateWidget(RetryWikiImage old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      retry?.cancel();
      retry = null;
      attempt = 0;
    }
  }

  @override
  void dispose() {
    retry?.cancel();
    super.dispose();
  }

  Widget failed(BuildContext context, Object error, StackTrace? trace) {
    if (attempt < 2 && retry == null) {
      retry = Timer(Duration(milliseconds: 600 * (attempt + 1)), () async {
        await NetworkImage(widget.source).evict();
        if (mounted) setState(() => attempt++);
        retry = null;
      });
    }
    if (attempt < 2) {
      return SizedBox(
        width: widget.width,
        height: widget.height?.clamp(24, 160) ?? 48,
        child: const Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() => attempt = 0);
            NetworkImage(widget.source).evict();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('重新加载图片'),
        ),
        WikiFallback(
          url:
              Uri.tryParse(widget.source)?.queryParameters['url'] ??
              widget.source,
          width: widget.width,
          height: widget.height,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final original = Uri.tryParse(source)?.queryParameters['url'] ?? source;
    if (Uri.tryParse(original)?.path.toLowerCase().endsWith('.svg') == true) {
      return SvgPicture.network(
        source,
        key: ValueKey('$source:$attempt'),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        semanticsLabel: widget.label,
        errorBuilder: failed,
      );
    }

    return Image.network(
      source,
      key: ValueKey('$source:$attempt'),
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      semanticLabel: widget.label,
      errorBuilder: failed,
    );
  }
}
