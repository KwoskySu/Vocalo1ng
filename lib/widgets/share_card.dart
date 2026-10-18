import 'adaptive_dialog.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/song.dart';
import '../services/export.dart';
import '../services/sources.dart';
import '../services/music.dart';
import 'cover_art.dart';
import 'player_visuals.dart' show lyricFontFamilies, lyricFontNames;
import 'brand_mark.dart';

class ShareCardDialog extends StatefulWidget {
  const ShareCardDialog({super.key, required this.song});
  final Song song;
  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final boundaryKey = GlobalKey();
  int template = 0;
  int palette = 0, font = 0;
  double lyricSize = 18;
  bool artType = false;
  static const templates = [
    '歌词卡',
    '乐评卡',
    '收藏卡',
    '黑白海报',
    '唱片票根',
    '霓虹舞台',
    '杂志封面',
    '极简便笺',
  ];
  bool exporting = false;
  String? error;

  Future<void> export() async {
    setState(() {
      exporting = true;
      error = null;
    });
    ui.Image? image;
    try {
      if (widget.song.cover.isEmpty && widget.song.coverUrl.isNotEmpty) {
        await precacheImage(
          NetworkImage(gatewayImage(widget.song.coverUrl)),
          context,
          onError: (_, _) {},
        );
        if (!mounted) return;
      }
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('图片生成失败');
      final saved = await exportFile(
        bytes.buffer.asUint8List(),
        'vocalo1ng-${widget.song.id}.png',
        'image/png',
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享图片已导出')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '导出失败，请重试。$e');
    } finally {
      image?.dispose();
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '让喜欢，有迹可循',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<int>(
                  value: template,
                  items: List.generate(
                    templates.length,
                    (i) =>
                        DropdownMenuItem(value: i, child: Text(templates[i])),
                  ),
                  onChanged: exporting
                      ? null
                      : (v) => setState(() => template = v!),
                ),
                DropdownButton<int>(
                  value: font,
                  items: List.generate(
                    lyricFontNames.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(lyricFontNames[i]),
                    ),
                  ),
                  onChanged: exporting
                      ? null
                      : (v) => setState(() => font = v!),
                ),
              ],
            ),
            Wrap(
              spacing: 7,
              children: [
                for (final (i, name) in [
                  '原色',
                  '墨白',
                  '樱粉',
                  '海盐',
                  '琥珀',
                  '紫夜',
                ].indexed)
                  ChoiceChip(
                    label: Text(name),
                    selected: palette == i,
                    onSelected: exporting
                        ? null
                        : (_) => setState(() => palette = i),
                  ),
              ],
            ),
            Row(
              children: [
                const Text('歌词字号'),
                Expanded(
                  child: Slider(
                    value: lyricSize,
                    min: 14,
                    max: 30,
                    divisions: 16,
                    onChanged: exporting
                        ? null
                        : (v) => setState(() => lyricSize = v),
                  ),
                ),
                Text('${lyricSize.round()}'),
              ],
            ),
            SwitchListTile(
              title: const Text('艺术字 · 光影 / 描边'),
              value: artType,
              onChanged: exporting ? null : (v) => setState(() => artType = v),
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: boundaryKey,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: lyricFontFamilies[font],
                ),
                child: _card(),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '仅导出当前卡片 · 歌曲封面或你导入的封面\n请仅使用有权分享的封面与歌词。二维码打开歌曲来源或 Wiki 搜索。',
              style: TextStyle(fontSize: 11, color: Color(0xFF697B77)),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: exporting ? null : export,
              icon: Icon(
                exporting ? Icons.hourglass_top : Icons.download_rounded,
              ),
              label: Text(exporting ? '正在生成…' : '导出高清 PNG'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _card() {
    final song = widget.song;
    final target =
        Sources.parseLink(Source.netease, song.netease) ??
        Sources.search(Source.wiki, song.title);
    final color = [
      Color(song.color),
      Colors.black,
      const Color(0xFFA63D6B),
      const Color(0xFF296B80),
      const Color(0xFF9C5E23),
      const Color(0xFF69459B),
    ][palette];
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.white, .95),
        border: Border.all(
          color: template == 3 ? Colors.black : color.withValues(alpha: .3),
          width: template == 3 ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(
          template == 4
              ? 2
              : template == 7
              ? 20
              : 0,
        ),
        gradient: template == 5
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: .12),
                  Colors.white,
                  color.withValues(alpha: .22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (template >= 3)
            Row(
              children: [
                BrandMark(size: template == 3 ? 60 : 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    templates[template].toUpperCase(),
                    style: TextStyle(
                      fontSize: template == 6 ? 28 : 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          if (template >= 3) const SizedBox(height: 20),
          Text(
            'Vocalo1ng / ${['LYRIC NOTES', 'LISTENING JOURNAL', 'IN MY COLLECTION'][template % 3]}',
            style: TextStyle(fontSize: 9, letterSpacing: .6, color: color),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: template == 6
                ? .85
                : template == 4
                ? 2.2
                : template == 2
                ? 1.5
                : 1.2,
            child: CoverArt(song: song, radius: 4),
          ),
          const SizedBox(height: 20),
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${song.artist} / ${song.voice}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF67726F)),
          ),
          const SizedBox(height: 20),
          if (template % 3 == 0 || template >= 3) ...[
            Text(
              song.lyrics.isEmpty ? '写下打动你的那一句。' : song.lyrics,
              style: TextStyle(
                fontSize: lyricSize,
                height: 1.8,
                color: color,
                fontFamily: lyricFontFamilies[font],
                fontWeight: artType ? FontWeight.w900 : FontWeight.w500,
                letterSpacing: artType ? 1.8 : 0,
                shadows: artType
                    ? [
                        Shadow(
                          color: color.withValues(alpha: .3),
                          offset: const Offset(2, 2),
                          blurRadius: 3,
                        ),
                      ]
                    : null,
              ),
            ),
            if (song.lyricCredit.isNotEmpty)
              Text(
                '歌词来源：${song.lyricCredit}',
                style: const TextStyle(fontSize: 10),
              ),
            const SizedBox(height: 14),
          ],
          if (template != 2 && song.review.isNotEmpty)
            Text(
              song.review,
              style: const TextStyle(fontSize: 13, height: 1.8),
            ),
          if (template == 2)
            Text(song.tags.join('  /  '), style: TextStyle(color: color)),
          const SizedBox(height: 22),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (song.rating > 0)
                      Text(
                        '${'★' * song.rating}${'☆' * (5 - song.rating)}',
                        style: TextStyle(color: color, letterSpacing: 3),
                      ),
                    const SizedBox(height: 5),
                    const Text(
                      '我的声音收藏夹',
                      style: TextStyle(fontSize: 11, color: Color(0xFF67726F)),
                    ),
                  ],
                ),
              ),
              QrImageView(
                data: target.toString(),
                size: 62,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
