import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import '../services/playback.dart';
import '../services/song_theme.dart';
import '../services/wiki.dart';
import 'wiki_reader.dart';
import 'journal_workspace.dart';

IconData modeIcon(PlayMode mode) => switch (mode) {
  PlayMode.sequential => Icons.arrow_right_alt,
  PlayMode.loop => Icons.repeat,
  PlayMode.single => Icons.repeat_one,
  PlayMode.shuffle => Icons.shuffle,
};

class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key, required this.playback});
  final Playback playback;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<PlayMode>(
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'NotoSansSC',
                  ),
                  value: playback.mode,
                  isExpanded: true,
                  items: PlayMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(modeIcon(mode), size: 18),
                              const SizedBox(width: 10),
                              Text(mode.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (mode) {
                    if (mode != null) playback.setMode(mode);
                  },
                ),
              ),
              TextButton(
                onPressed: playback.keepCurrentOnly,
                child: const Text('仅保留当前'),
              ),
            ],
          ),
        ),
        Expanded(
          child: playback.queue.isEmpty
              ? const Center(child: Text('还没有待播歌曲，点击歌曲开始收听'))
              : ListView.builder(
                  itemCount: playback.queue.length,
                  itemBuilder: (context, i) {
                    final track = playback.queue[i];
                    final selected = i == playback.index;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .12),
                      leading: SizedBox(
                        width: 34,
                        child: selected
                            ? const Icon(Icons.graphic_eq)
                            : Text('${i + 1}', textAlign: TextAlign.center),
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.artist} · ${track.platform}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => playback.selectAt(i),
                      trailing: selected
                          ? const Text('当前', style: TextStyle(fontSize: 11))
                          : IconButton(
                              tooltip: '从待播列表移除',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () => playback.removeAt(i),
                            ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class SongWikiPanel extends StatefulWidget {
  const SongWikiPanel({super.key, required this.music, required this.track});
  final MusicService music;
  final MusicTrack track;
  @override
  State<SongWikiPanel> createState() => _SongWikiPanelState();
}

class _SongWikiPanelState extends State<SongWikiPanel> {
  List<WikiEntry> entries = [];
  WikiEntry? selected;
  bool loading = true;
  String? error;
  final query = TextEditingController();
  @override
  void initState() {
    super.initState();
    query.text = widget.track.title;
    load();
  }

  Future<void> load({bool manual = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      List<WikiEntry> found;
      if (manual) {
        found = await widget.music.songWiki.service.search(query.text.trim());
      } else {
        await widget.music.songWiki.prefetch(
          widget.track,
          retry: widget.music.songWiki.failed.contains(widget.track.id),
        );
        if (widget.music.songWiki.failed.contains(widget.track.id)) {
          throw StateError('百科暂时无法加载');
        }
        found = widget.music.songWiki.results[widget.track.id] ?? [];
      }
      if (mounted) {
        setState(() {
          entries = found;
          selected = found.firstOrNull;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = '百科暂时无法加载，请重试';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: query,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '搜索其他百科条目',
                  fillColor: Colors.transparent,
                ),
                onSubmitted: (_) => load(manual: true),
              ),
            ),
            IconButton(
              tooltip: '搜索百科',
              onPressed: () => load(manual: true),
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: '重新加载百科',
              onPressed: loading ? null : () => load(manual: true),
              icon: const Icon(Icons.refresh),
            ),
            if (entries.length > 1)
              PopupMenuButton<int>(
                tooltip: '选择其他百科条目',
                onSelected: (id) => setState(
                  () => selected = entries.firstWhere((e) => e.pageId == id),
                ),
                itemBuilder: (_) => entries
                    .map(
                      (e) =>
                          PopupMenuItem(value: e.pageId, child: Text(e.title)),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : selected == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error ?? '未找到匹配条目，可以修改上方关键词搜索'),
                    TextButton(
                      onPressed: () => load(manual: true),
                      child: const Text('重新查询'),
                    ),
                  ],
                ),
              )
            : WikiReader(
                key: ValueKey(selected!.pageId),
                pageId: selected!.pageId,
                title: selected!.title,
                embedded: true,
              ),
      ),
    ],
  );
}

class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 24,
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭面板',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// Only the content area is overlaid, leaving the player and navigation live.
class PlaybackPanelHost extends StatelessWidget {
  const PlaybackPanelHost({
    super.key,
    required this.child,
    required this.playback,
    required this.panel,
  });
  final Widget child;
  final Playback playback;
  final ValueNotifier<String?> panel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([panel, playback, songAppearance]),
    builder: (context, _) => Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomRight,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
              child: panel.value == null
                  ? const SizedBox.shrink()
                  : FractionallySizedBox(
                      key: ValueKey(panel.value),
                      heightFactor: .9,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: PanelFrame(
                          title: panel.value == 'queue'
                              ? '播放列表 · ${playback.queue.length} 首'
                              : panel.value == 'journal'
                              ? '音乐手记 · ${playback.current?.title ?? ''}'
                              : '歌曲百科 · ${playback.current?.title ?? ''}',
                          onClose: () => panel.value = null,
                          child: panel.value == 'queue'
                              ? QueuePanel(playback: playback)
                              : playback.current == null
                              ? const Center(child: Text('请选择歌曲'))
                              : panel.value == 'journal'
                              ? JournalWorkspace(
                                  key: ValueKey(
                                    'journal:${playback.current!.id}',
                                  ),
                                  playback: playback,
                                  track: playback.current!,
                                )
                              : SongWikiPanel(
                                  key: ValueKey(playback.current!.id),
                                  music: playback.music,
                                  track: playback.current!,
                                ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
