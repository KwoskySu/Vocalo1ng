import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import 'embedded_pv.dart';
import 'account_avatar.dart';
import 'bilibili_login.dart';
import 'comments.dart';

Future<void> showPvs(
  BuildContext context,
  MusicService music,
  String title,
  String artist,
) async => showDialog<void>(
  context: context,
  useSafeArea: MediaQuery.sizeOf(context).shortestSide >= 600,
  builder: (_) => MediaQuery.sizeOf(context).shortestSide < 600
      ? Dialog.fullscreen(
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '关闭视频',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Expanded(
                      child: Text(
                        '歌曲视频 · B 站 PV',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: PvBrowser(
                    music: music,
                    title: title,
                    artist: artist,
                    embedded: true,
                  ),
                ),
              ],
            ),
          ),
        )
      : PvBrowser(music: music, title: title, artist: artist),
);

class PvBrowser extends StatefulWidget {
  const PvBrowser({
    super.key,
    required this.music,
    required this.title,
    required this.artist,
    this.embedded = false,
  });
  final MusicService music;
  final String title, artist;
  final bool embedded;
  @override
  State<PvBrowser> createState() => _PvBrowserState();
}

class _PvBrowserState extends State<PvBrowser> {
  List<PvVideo>? videos;
  PvVideo? selected;
  String? error;
  String order = 'click', pane = 'versions';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    final request = ++generation;
    setState(() {
      error = null;
      videos = null;
    });
    try {
      final result = await widget.music.pvs(
        widget.title,
        widget.artist,
        order: order,
        refresh: refresh,
      );
      if (mounted && request == generation) {
        setState(() {
          videos = result;
          selected ??= result.firstOrNull;
        });
      }
    } catch (e) {
      if (mounted && request == generation) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? content(context)
      : AdaptiveDialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: content(context),
          ),
        );
  Widget content(BuildContext context) => SingleChildScrollView(
    padding: widget.embedded
        ? const EdgeInsets.fromLTRB(12, 0, 12, 16)
        : const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('排序'),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: order,
                isExpanded: true,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'NotoSansSC',
                ),
                items: const [
                  DropdownMenuItem(value: 'click', child: Text('播放量优先')),
                  DropdownMenuItem(value: 'default', child: Text('B 站默认排序')),
                ],
                onChanged: (v) {
                  setState(() => order = v!);
                  load();
                },
              ),
            ),
            IconButton(
              tooltip: '刷新视频搜索',
              onPressed: () => load(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (selected != null)
          frame(
            EmbeddedPv(
              key: ValueKey(selected!.bvid),
              bvid: selected!.bvid,
              music: widget.music,
            ),
          )
        else
          frame(
            Center(
              child: videos == null && error == null
                  ? const CircularProgressIndicator()
                  : Text(error ?? '暂未找到可播放的 PV'),
            ),
          ),
        if (error != null || (videos != null && videos!.isEmpty))
          TextButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新自动搜索'),
          ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          Text(
            selected!.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'UP 主：${selected!.author} · ${selected!.duration}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF74847C)),
          ),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            TextButton.icon(
              onPressed: () async {
                await showBilibiliLogin(context, widget.music);
                if (mounted) setState(() {});
              },
              icon: AccountAvatar(
                music: widget.music,
                bilibili: true,
                size: 26,
              ),
              label: Text(
                widget.music.bilibiliLoggedIn
                    ? 'B 站 · ${widget.music.bilibiliProfile!['nickname']}'
                    : '登录 B 站解锁账号可用画质',
              ),
            ),
          ],
        ),
        const Divider(),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'versions', label: Text('多个版本')),
            ButtonSegment(value: 'comments', label: Text('评论区')),
          ],
          selected: {pane},
          onSelectionChanged: (v) => setState(() => pane = v.first),
        ),
        if (pane == 'comments' && selected != null)
          SizedBox(
            height: 480,
            child: CommentPanel(
              key: ValueKey('comments:${selected!.bvid}'),
              music: widget.music,
              bvid: selected!.bvid,
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '按作品名与创作者自动匹配；候选可能包含字幕、翻调或现场版，请结合标题和 UP 主判断。',
          style: TextStyle(fontSize: 11, color: Color(0xFF74847C), height: 1.7),
        ),
        if (pane == 'versions')
          for (final video in videos ?? <PvVideo>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 92,
                height: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.cover.isNotEmpty)
                        Image.network(
                          widget.music.image(video.cover),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0x33287865)),
                        )
                      else
                        const ColoredBox(color: Color(0x33287865)),
                      Center(
                        child: Icon(
                          video.bvid == selected?.bvid
                              ? Icons.play_circle_filled
                              : Icons.play_circle_outline,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                '${video.author} · ${video.duration} · ${video.plays} 次播放',
                style: const TextStyle(fontSize: 10),
              ),
              selected: video.bvid == selected?.bvid,
              onTap: () => setState(() => selected = video),
            ),
      ],
    ),
  );
  Widget frame(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1400),
      child: LayoutBuilder(
        builder: (context, box) {
          final mobile = MediaQuery.sizeOf(context).shortestSide < 600;
          final height = box.maxWidth * 9 / 16 + (mobile ? 94 : 50);
          return SizedBox(
            height: mobile
                ? height.clamp(
                    160,
                    (MediaQuery.sizeOf(context).height * .78).clamp(160, 1200),
                  )
                : height,
            child: child,
          );
        },
      ),
    ),
  );
}

class PvPreview extends StatefulWidget {
  const PvPreview({
    super.key,
    required this.music,
    required this.title,
    required this.artist,
  });
  final MusicService music;
  final String title, artist;
  @override
  State<PvPreview> createState() => _PvPreviewState();
}

class _PvPreviewState extends State<PvPreview> {
  late Future<List<PvVideo>> future;
  @override
  void initState() {
    super.initState();
    future = widget.music.pvs(widget.title, widget.artist);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PvVideo>>(
    future: future,
    builder: (context, snapshot) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.hasError
                ? 'PV 自动搜索暂不可用'
                : !snapshot.hasData
                ? '正在自动匹配 PV…'
                : '匹配到 ${snapshot.data!.length} 个 PV 候选版本',
            style: const TextStyle(fontSize: 11, color: Color(0xFF74847C)),
          ),
          if (snapshot.data?.isNotEmpty == true)
            Text(
              snapshot.data!.first.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          TextButton.icon(
            onPressed: () =>
                showPvs(context, widget.music, widget.title, widget.artist),
            icon: const Icon(Icons.smart_display_outlined),
            label: const Text('观看 PV / 切换版本'),
          ),
        ],
      ),
    ),
  );
}
