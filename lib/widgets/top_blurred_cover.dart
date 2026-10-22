import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Blur is rasterized once onto a 96px square, never onto the full card/page.
/// The pool owns <=24 bitmaps (864KiB RGBA); mounted widgets own small clones.
final topBlurCache = TopBlurCache();

class TopBlurCache {
  final _images = LinkedHashMap<(ImageProvider, int), ui.Image>();
  final _pending = <(ImageProvider, int), Future<ui.Image?>>{};
  Future<void>? _tail;
  int _generation = 0;
  int get length => _images.length;
  bool get isPending => _pending.isNotEmpty;
  Future<ui.Image?> request(ImageProvider provider, double blur) {
    final key = (provider, blur.round().clamp(0, 12));
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return Future.value(cached.clone());
    }
    final old = _pending[key];
    if (old != null) return old.then((image) => image?.clone());
    final generation = _generation;
    final work = (_tail ?? Future<void>.value()).then((_) async {
      if (generation != _generation) return null;
      ui.Image? image;
      try {
        image = await _raster(provider, key.$2);
      } catch (_) {
        return null;
      }
      if (generation != _generation) {
        image?.dispose();
        return null;
      }
      if (image == null) return null;
      _images[key] = image;
      while (_images.length > 24) {
        _images.remove(_images.keys.first)!.dispose();
      }
      return image;
    });
    _pending[key] = work;
    final tail = work.then<void>((_) {});
    _tail = tail;
    unawaited(
      work.whenComplete(() {
        if (identical(_pending[key], work)) _pending.remove(key);
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return work.then((image) => image?.clone());
  }

  Future<ui.Image?> _raster(ImageProvider provider, int blur) async {
    final stream = provider.resolve(ImageConfiguration.empty);
    final ready = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) {
        if (ready.isCompleted) {
          info.dispose();
        } else {
          ready.complete(info);
        }
      },
      onError: (error, trace) {
        if (!ready.isCompleted) ready.completeError(error, trace);
      },
    );
    stream.addListener(listener);
    ImageInfo? info;
    ui.Picture? picture;
    try {
      info = await ready.future.timeout(const Duration(seconds: 4));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.low;
      if (blur > 0)
        paint.imageFilter = ui.ImageFilter.blur(
          sigmaX: blur.toDouble(),
          sigmaY: blur.toDouble(),
          tileMode: TileMode.clamp,
        );
      canvas.drawImageRect(
        info.image,
        Rect.fromLTWH(
          0,
          0,
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
        const Rect.fromLTWH(0, 0, 96, 96),
        paint,
      );
      picture = recorder.endRecording();
      return await picture.toImage(96, 96);
    } finally {
      stream.removeListener(listener);
      info?.dispose();
      picture?.dispose();
    }
  }

  Future<void> settle() async {
    while (true) {
      final current = _tail;
      await current;
      if (identical(current, _tail)) return;
    }
  }

  void clear() {
    _generation++;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _pending.clear();
  }
}

class TopBlurredCover extends StatefulWidget {
  const TopBlurredCover({
    super.key,
    required this.provider,
    required this.blur,
    required this.zoom,
    required this.opacity,
  });
  final ImageProvider provider;
  final double blur, zoom, opacity;
  @override
  State<TopBlurredCover> createState() => _TopBlurredCoverState();
}

class _TopBlurredCoverState extends State<TopBlurredCover> {
  ui.Image? image;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(TopBlurredCover old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider ||
        old.blur.round() != widget.blur.round())
      load();
  }

  void load() {
    final request = ++revision;
    topBlurCache.request(widget.provider, widget.blur).then((result) {
      if (!mounted || request != revision) {
        result?.dispose();
        return;
      }
      setState(() {
        image?.dispose();
        image = result;
      });
    });
  }

  @override
  void dispose() {
    revision++;
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => image == null
      ? const SizedBox()
      : ClipRect(
          child: Transform.scale(
            scale: widget.zoom,
            child: RawImage(
              image: image,
              fit: BoxFit.cover,
              color: Colors.white.withValues(alpha: widget.opacity),
              colorBlendMode: BlendMode.modulate,
              filterQuality: FilterQuality.low,
            ),
          ),
        );
}
