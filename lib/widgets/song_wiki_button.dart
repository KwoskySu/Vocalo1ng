import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import 'wiki_reader.dart';
import 'wiki_explorer.dart';

class SongWikiButton extends StatefulWidget {
  const SongWikiButton({
    super.key,
    required this.music,
    required this.track,
    this.compact = false,
  });
  final MusicService music;
  final MusicTrack track;
  final bool compact;
  @override
  State<SongWikiButton> createState() => _SongWikiButtonState();
}

class _SongWikiButtonState extends State<SongWikiButton> {
  @override
  void initState() {
    super.initState();
    if (!widget.compact) widget.music.songWiki.prefetch(widget.track);
  }

  @override
  void didUpdateWidget(SongWikiButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.compact && oldWidget.track.id != widget.track.id) {
      widget.music.songWiki.prefetch(widget.track);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.music.songWiki,
    builder: (context, _) {
      final matches = widget.music.songWiki.results[widget.track.id];
      final match = matches?.firstOrNull;
      Future<void> open() async {
        if (matches == null) await widget.music.songWiki.prefetch(widget.track);
        if (!context.mounted) return;
        final resolved =
            widget.music.songWiki.results[widget.track.id]?.firstOrNull;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => resolved == null
                ? Scaffold(
                    appBar: AppBar(title: const Text('歌曲百科')),
                    body: WikiExplorer(initialQuery: widget.track.title),
                  )
                : WikiReader(pageId: resolved.pageId, title: resolved.title),
          ),
        );
      }

      final label = match == null
          ? (widget.music.songWiki.pending.containsKey(widget.track.id)
                ? '百科匹配中…'
                : matches == null
                ? '歌曲百科'
                : '搜索歌曲百科')
          : '百科 · ${match.title}';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.compact)
            IconButton(
              tooltip: label,
              onPressed: open,
              icon: const Icon(Icons.menu_book_outlined, size: 21),
            )
          else
            Flexible(
              child: TextButton.icon(
                onPressed: open,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (!widget.compact && matches != null && matches.length > 1)
            PopupMenuButton<int>(
              tooltip: '选择其他百科条目',
              onSelected: (id) {
                final entry = matches.firstWhere((e) => e.pageId == id);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WikiReader(pageId: id, title: entry.title),
                  ),
                );
              },
              itemBuilder: (_) => matches
                  .map(
                    (e) => PopupMenuItem(value: e.pageId, child: Text(e.title)),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}
