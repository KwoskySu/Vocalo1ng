import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/lyrics.dart';
import '../services/music.dart';
import '../services/playback.dart';
import 'song_wiki_button.dart';

class TrackLyrics extends StatefulWidget {
  const TrackLyrics({
    super.key,
    required this.music,
    required this.track,
    required this.playback,
    required this.onShare,
  });
  final MusicService music;
  final MusicTrack track;
  final Playback? playback;
  final void Function(String lyrics) onShare;
  @override
  State<TrackLyrics> createState() => _TrackLyricsState();
}

class _TrackLyricsState extends State<TrackLyrics> {
  List<LyricLine>? lines;
  List<String?> translations = [];
  final Set<int> selected = {};
  String? error;
  bool translated = true;
  String original = '', translation = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.music.lyrics(widget.track.id);
      if (mounted) {
        setState(() {
          original = data.original;
          translation = data.translated;
          lines = parseLyrics(original);
          translations = alignTranslations(lines!, translation);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  String excerptLine(int i) => translated && translations[i] != null
      ? '${lines![i].text}\n${translations[i]}'
      : lines![i].text;
  String get excerpt => selected.toList().sorted().map(excerptLine).join('\n');
  void select(int index, bool value) {
    final next = {...selected};
    if (value) {
      next.add(index);
    } else {
      next.remove(index);
    }
    final text = (next.toList()..sort()).map(excerptLine).join('\n');
    if (text.characters.length > 120) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享摘录最多 120 字，请减少选中行')));
      return;
    }
    setState(() {
      selected.clear();
      selected.addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: SizedBox(
      width: 580,
      height: 650,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.track.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '歌词来自${widget.track.platform} · 选择少量歌词制作分享卡',
              style: const TextStyle(fontSize: 11, color: Color(0xFF74847C)),
            ),
            SongWikiButton(music: widget.music, track: widget.track),
            if (translation.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示双语歌词'),
                value: translated,
                onChanged: (v) => setState(() {
                  translated = v;
                  selected.clear();
                }),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: lines == null
                  ? Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : Text(error!),
                    )
                  : lines!.isEmpty
                  ? const Center(child: Text('这首歌暂时没有歌词。'))
                  : StreamBuilder<Duration>(
                      stream: widget.playback?.player.stream.position,
                      initialData:
                          widget.playback?.player.state.position ??
                          Duration.zero,
                      builder: (context, position) {
                        final active =
                            widget.playback?.current?.id == widget.track.id
                            ? lines!.lastIndexWhere(
                                (l) =>
                                    l.time != null && l.time! <= position.data!,
                              )
                            : -1;
                        return ListView.builder(
                          itemCount: lines!.length,
                          itemBuilder: (context, i) => CheckboxListTile(
                            value: selected.contains(i),
                            onChanged: (v) => select(i, v!),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              lines![i].text,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.7,
                                color: active == i
                                    ? const Color(0xFF287C65)
                                    : null,
                                fontWeight: active == i
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            subtitle: translated && translations[i] != null
                                ? Text(
                                    translations[i]!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      height: 1.6,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      final text = excerpt;
                      Navigator.pop(context);
                      widget.onShare(text);
                    },
              icon: const Icon(Icons.ios_share),
              label: Text('用选中歌词制作分享卡（${excerpt.characters.length}/120）'),
            ),
          ],
        ),
      ),
    ),
  );
}

extension _SortedIndices on List<int> {
  List<int> sorted() {
    sort();
    return this;
  }
}
