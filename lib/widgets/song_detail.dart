import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song.dart';
import '../models/music.dart';
import '../services/music.dart';
import '../services/playback.dart';
import '../services/sources.dart';
import 'cover_art.dart';
import 'share_card.dart';
import 'pv_browser.dart';
import 'wiki_explorer.dart';
import 'song_wiki_button.dart';

Future<void> openSource(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('launch failed');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接，请检查浏览器设置或稍后重试。')));
    }
  }
}

class SongDetail extends StatefulWidget {
  const SongDetail({
    super.key,
    required this.song,
    required this.onSave,
    this.onClose,
    this.music,
    this.playback,
    this.compact = false,
  });
  final Song song;
  final Future<void> Function(Song) onSave;
  final VoidCallback? onClose;
  final MusicService? music;
  final Playback? playback;
  final bool compact;
  @override
  State<SongDetail> createState() => _SongDetailState();
}

class _SongDetailState extends State<SongDetail> {
  late TextEditingController review, lyrics, credit;
  late int rating;
  late Song current;
  bool dirty = false;
  Timer? autosave;
  @override
  void initState() {
    super.initState();
    current = widget.song;
    rating = current.rating;
    review = TextEditingController(text: current.review);
    lyrics = TextEditingController(text: current.lyrics);
    credit = TextEditingController(text: current.lyricCredit);
    for (final c in [review, lyrics, credit]) {
      c.addListener(changed);
    }
  }

  void changed() {
    if (!dirty) setState(() => dirty = true);
    autosave?.cancel();
    autosave = Timer(const Duration(milliseconds: 600), () => save(draft()));
  }

  @override
  void didUpdateWidget(SongDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    current = widget.song;
  }

  @override
  void dispose() {
    autosave?.cancel();
    if (dirty) {
      final snapshot = draft();
      final persist = widget.onSave;
      Future.microtask(() async {
        try {
          await persist(snapshot);
        } catch (_) {
          /* retain explicit save error handling while mounted */
        }
      });
    }
    review.dispose();
    lyrics.dispose();
    credit.dispose();
    super.dispose();
  }

  Song draft() => current.copyWith(
    review: review.text.trim(),
    lyrics: lyrics.text.trim(),
    lyricCredit: credit.text.trim(),
    rating: rating,
  );

  Future<bool> save(Song song, {bool message = false}) async {
    autosave?.cancel();
    try {
      await widget.onSave(song);
      if (!mounted) return true;
      setState(() {
        current = song;
        dirty =
            review.text.trim() != song.review ||
            lyrics.text.trim() != song.lyrics ||
            credit.text.trim() != song.lyricCredit ||
            rating != song.rating;
      });
      if (message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存到本机')));
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请备份内容后重试')));
      }
      return false;
    }
  }

  Future<void> cover() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: '封面',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
            uniformTypeIdentifiers: [
              'public.png',
              'public.jpeg',
              'org.webmproject.webp',
            ],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) throw StateError('请使用小于 2 MB 的封面');
      // Decode once before persisting so invalid images never enter the library.
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      await save(draft().copyWith(cover: base64Encode(bytes)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('封面导入失败：$e')));
      }
    }
  }

  Future<void> editLinks() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => LinkDialog(song: current),
    );
    if (result != null) {
      await save(
        draft().copyWith(netease: result.$1, bilibili: result.$2),
        message: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '歌曲手记',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF788B83),
                  letterSpacing: 2,
                ),
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: '关闭详情',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!widget.compact)
          AspectRatio(aspectRatio: 1.35, child: CoverArt(song: current)),
        if (!widget.compact)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: cover,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
              label: const Text('导入封面', style: TextStyle(fontSize: 11)),
            ),
          ),
        Text(
          current.title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${current.artist}  /  ${current.voice}',
          style: const TextStyle(color: Color(0xFF6C8077), fontSize: 12),
        ),
        const SizedBox(height: 18),
        if (!widget.compact)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final uri = Sources.parseLink(
                    Source.netease,
                    current.netease,
                  );
                  final route = uri != null && uri.fragment.isNotEmpty
                      ? Uri.tryParse(uri.fragment)
                      : uri;
                  final id = current.id.startsWith('qq-')
                      ? 'qq:${current.id.substring(3)}'
                      : route?.queryParameters['id'];
                  if (id != null && widget.playback != null) {
                    widget.playback!.play(
                      MusicTrack(
                        id: id,
                        title: current.title,
                        artist: current.artist,
                        cover: current.coverUrl,
                      ),
                    );
                  } else {
                    openSource(
                      context,
                      uri ??
                          Sources.search(
                            Source.netease,
                            '${current.title} ${current.artist}',
                          ),
                    );
                  }
                },
                icon: const Icon(Icons.headphones_rounded, size: 17),
                label: Text(
                  current.netease.isEmpty && !current.id.startsWith('qq-')
                      ? '网易云找歌'
                      : '直接播放',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  if (widget.music != null) {
                    await widget.playback?.player.pause();
                    if (context.mounted) {
                      await showPvs(
                        context,
                        widget.music!,
                        current.title,
                        current.artist,
                      );
                    }
                  } else {
                    openSource(
                      context,
                      Sources.parseLink(Source.bilibili, current.bilibili) ??
                          Sources.search(
                            Source.bilibili,
                            '${current.title} ${current.artist} PV',
                          ),
                    );
                  }
                },
                icon: const Icon(Icons.smart_display_outlined, size: 17),
                label: const Text('观看 PV'),
              ),
            ],
          ),
        if (!widget.compact)
          Row(
            children: [
              if (widget.music != null)
                Flexible(
                  child: SongWikiButton(
                    music: widget.music!,
                    track: MusicTrack(
                      id: current.id,
                      title: current.title,
                      artist: current.artist,
                      alias: current.alias,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('VocaWiki 资料')),
                        body: WikiExplorer(initialQuery: current.title),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('VocaWiki 资料'),
                ),
              const Spacer(),
              TextButton(onPressed: editLinks, child: const Text('绑定链接')),
            ],
          ),
        if (!widget.compact && widget.music != null)
          PvPreview(
            music: widget.music!,
            title: current.title,
            artist: current.artist,
          ),
        if (!widget.compact)
          const Text(
            '歌曲按当前账号权限播放；PV 自动匹配并保留多个候选版本。',
            style: TextStyle(fontSize: 10, color: Color(0xFF788B83)),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        ),
        const Text(
          '这首歌，留下了什么？',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i 星；再次点击可清除',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    rating = rating == i ? 0 : i;
                  });
                  changed();
                },
                icon: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFC49B50),
                  size: 26,
                ),
              ),
          ],
        ),
        TextField(
          controller: review,
          maxLength: 500,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(hintText: '写下你的听后感，只有你能看到…'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: lyrics,
          maxLength: 120,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '想分享的歌词摘录',
            hintText: '手动填写有权分享的歌词',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: credit,
          maxLength: 100,
          decoration: const InputDecoration(labelText: '歌词 / 翻译来源'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: dirty ? () => save(draft(), message: true) : null,
                child: Text(dirty ? '保存听后感' : '已保存'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final song = draft();
                  if (!await save(song) || !context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (_) => ShareCardDialog(song: song),
                  );
                },
                icon: const Icon(Icons.ios_share, size: 17),
                label: const Text('生成分享卡'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class LinkDialog extends StatefulWidget {
  const LinkDialog({super.key, required this.song});
  final Song song;
  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  final form = GlobalKey<FormState>();
  late final netease = TextEditingController(text: widget.song.netease);
  late final bilibili = TextEditingController(text: widget.song.bilibili);
  @override
  void dispose() {
    netease.dispose();
    bilibili.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('关联同一个歌曲版本'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请确认 P 主、声库与版本一致。留空可以解除绑定。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: netease,
              decoration: const InputDecoration(
                labelText: '网易云歌曲 ID 或 HTTPS 歌曲链接',
              ),
              validator: (v) =>
                  v!.trim().isEmpty ||
                      Sources.parseLink(Source.netease, v) != null
                  ? null
                  : '请输入有效的 music.163.com 歌曲链接或数字 ID',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: bilibili,
              decoration: const InputDecoration(
                labelText: 'BV 号或 B 站 HTTPS 视频链接',
              ),
              validator: (v) =>
                  v!.trim().isEmpty ||
                      Sources.parseLink(Source.bilibili, v) != null
                  ? null
                  : '请输入完整 BV 号或 bilibili.com 视频链接',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              Sources.parseLink(Source.netease, netease.text)?.toString() ?? '',
              Sources.parseLink(Source.bilibili, bilibili.text)?.toString() ??
                  '',
            ));
          }
        },
        child: const Text('保存关联'),
      ),
    ],
  );
}
