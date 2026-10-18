import 'dart:math';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import '../services/playback.dart';
import '../services/collections.dart';
import 'song_detail.dart';

class CommentPanel extends StatefulWidget {
  const CommentPanel({super.key, required this.music, this.track, this.bvid});
  final MusicService music;
  final MusicTrack? track;
  final String? bvid;
  @override
  State<CommentPanel> createState() => _CommentPanelState();
}

class _CommentPanelState extends State<CommentPanel> {
  List<Map<String, dynamic>> items = [];
  String sort = 'hot', source = '';
  String notice = '';
  String? error;
  bool loading = true, saved = false, more = false;
  int page = 1, generation = 0, total = 0;
  String nextCursor = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CommentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bvid != widget.bvid ||
        oldWidget.track?.id != widget.track?.id) {
      page = 1;
      saved = false;
      items = [];
      source = '';
      notice = '';
      load();
    }
  }

  Future<void> load({bool append = false}) async {
    final request = ++generation;
    final requestedPage = append ? page + 1 : 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.music.request(
        widget.bvid == null ? '/api/comments' : '/api/pv/comments',
        params: {
          if (widget.track != null) 'id': widget.track!.id,
          if (widget.bvid != null) 'bvid': widget.bvid!,
          'sort': sort == 'latest' ? 'latest' : 'hot',
          'page': '$requestedPage',
          if (widget.bvid != null) 'cursor': append ? nextCursor : '',
        },
      );
      if (!mounted || request != generation) return;
      final next = (data['comments'] as List)
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      setState(() {
        items = append
            ? {
                ...{for (final c in items) '${c['id']}': c},
                ...{for (final c in next) '${c['id']}': c},
              }.values.toList()
            : next;
        page = requestedPage;
        nextCursor = data['nextCursor'] as String? ?? '';
        source = data['source'] as String? ?? '';
        notice = data['notice'] as String? ?? '';
        more = data['more'] == true;
        total = (data['total'] as num?)?.toInt() ?? 0;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collections,
    builder: (context, _) {
      final scope = widget.bvid ?? widget.track!.id;
      final values = saved
          ? collections.comments.entries
                .where((e) => e.key.startsWith('$scope:'))
                .map((e) => e.value)
                .toList()
          : List<Map<String, dynamic>>.of(items);
      if (sort == 'likes') {
        values.sort((a, b) => (b['likes'] as num).compareTo(a['likes'] as num));
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: sort,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'NotoSansSC',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'hot', child: Text('平台热评')),
                      DropdownMenuItem(value: 'latest', child: Text('最新')),
                      DropdownMenuItem(
                        value: 'likes',
                        child: Text('点赞数 · 已加载'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        sort = v!;
                        page = 1;
                      });
                      load();
                    },
                  ),
                ),
                IconButton(
                  tooltip: saved ? '全部评论' : '已收藏评论',
                  onPressed: () => setState(() => saved = !saved),
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                ),
                IconButton(
                  tooltip: '刷新评论',
                  onPressed: () {
                    page = 1;
                    load();
                  },
                  icon: const Icon(Icons.refresh),
                ),
                if (source.isNotEmpty)
                  IconButton(
                    tooltip: '打开评论来源',
                    onPressed: () => openSource(context, Uri.parse(source)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(notice, style: const TextStyle(fontSize: 11)),
            ),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          Expanded(
            child: ListView(
              children: [
                if (values.isEmpty && !loading && (error == null || saved))
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无可显示的评论'),
                  ),
                for (final (index, c) in values.indexed)
                  SongCommentCard(
                    comment: c,
                    index: index,
                    platform: widget.bvid != null
                        ? 'B 站'
                        : widget.track!.platform,
                    avatar: (c['avatar'] as String? ?? '').isEmpty
                        ? ''
                        : widget.music.image(c['avatar'] as String),
                    saved: collections.comments.containsKey(
                      '$scope:${c['id']}',
                    ),
                    onSave: () =>
                        collections.toggleComment('$scope:${c['id']}', {
                          ...c,
                          'source': source,
                          'song': widget.track?.title ?? widget.bvid,
                        }),
                  ),
                if (more && !saved)
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            load(append: true);
                          },
                    child: Text('加载更多 · 已加载 ${items.length} / $total'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Separate, bordered cards keep long reviews readable in a themed panel.
class SongCommentCard extends StatelessWidget {
  const SongCommentCard({
    super.key,
    required this.comment,
    required this.index,
    required this.platform,
    required this.avatar,
    required this.saved,
    required this.onSave,
  });
  final Map<String, dynamic> comment;
  final int index;
  final String platform, avatar;
  final bool saved;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = comment['author'] as String? ?? '';
    final time = comment['time'];
    final date = time is num && time.isFinite && time > 0
        ? DateTime.fromMillisecondsSinceEpoch(time.toInt()).toLocal()
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 0,
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: index.isEven ? .07 : .025),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                  child: Text(
                    author.isEmpty ? '♪' : author.characters.first,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    author.isEmpty ? '匿名听众' : author,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: saved ? '取消收藏评论' : '收藏评论',
                  onPressed: onSave,
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              comment['text'] as String? ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '♡ ${comment['likes'] ?? 0}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  platform,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (date != null)
                  Text(
                    '${date.year}.${date.month}.${date.day}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HotReview extends StatefulWidget {
  const HotReview({super.key, required this.playback, this.onOpen});
  final Playback playback;
  final ValueChanged<MusicTrack>? onOpen;
  @override
  State<HotReview> createState() => _HotReviewState();
}

class _HotReviewState extends State<HotReview> {
  MusicTrack? track;
  Map<String, dynamic>? comment;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.playback.music.addListener(changed);
    changed();
  }

  @override
  void dispose() {
    widget.playback.music.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (track == null && !busy && widget.playback.music.lastTracks.isNotEmpty) {
      load();
    }
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    error = null;
    try {
      final pool = widget.playback.music.lastTracks;
      if (pool.isEmpty) return;
      final selected = pool[Random().nextInt(pool.length)];
      final data = await widget.playback.music.request(
        '/api/comments',
        params: {'id': selected.id, 'sort': 'hot'},
      );
      final list =
          (data['comments'] as List)
              .map((c) => Map<String, dynamic>.from(c))
              .toList()
            ..sort((a, b) => (b['likes'] as num).compareTo(a['likes'] as num));
      if (mounted) {
        setState(() {
          track = selected;
          comment = list.firstOrNull;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '热评暂未加载');
    } finally {
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: track == null
        ? null
        : () {
            if (widget.onOpen != null) {
              widget.onOpen!(track!);
            } else {
              widget.playback.play(track!);
            }
          },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment?['text'] as String? ?? error ?? '正在遇见下一条乐评…',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.8),
          ),
          if (track != null)
            Text(
              '— ${comment?['author'] ?? ''}\n${track!.title} · ${track!.platform} · ♡ ${comment?['likes'] ?? 0}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, height: 1.8),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '换一条热评',
              onPressed: load,
              icon: const Icon(Icons.refresh, size: 16),
            ),
          ),
        ],
      ),
    ),
  );
}
