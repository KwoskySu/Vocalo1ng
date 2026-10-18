import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../models/song.dart';
import '../services/library.dart';
import '../services/playback.dart';
import 'song_detail.dart';
import 'playback_panels.dart';

Library? journalLibrary;

Future<void> showJournalWorkspace(
  BuildContext context,
  Playback playback,
  MusicTrack track,
) => showDialog<void>(
  context: context,
  builder: (dialog) => AdaptiveDialog(
    child: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .85,
      child: PanelFrame(
        title: '音乐手记 · ${track.title}',
        onClose: () => Navigator.pop(dialog),
        child: JournalWorkspace(playback: playback, track: track),
      ),
    ),
  ),
);

class JournalWorkspace extends StatefulWidget {
  const JournalWorkspace({
    super.key,
    required this.playback,
    required this.track,
  });
  final Playback playback;
  final MusicTrack track;
  @override
  State<JournalWorkspace> createState() => _JournalWorkspaceState();
}

class _JournalWorkspaceState extends State<JournalWorkspace> {
  int tab = 0;
  late final Future<Song> prepared = prepare();
  Future<Song> prepare() async {
    final library = journalLibrary;
    if (library == null) throw StateError('音乐手记尚未初始化');
    final t = widget.track,
        id = t.isQQ ? 'qq-${t.id.substring(3)}' : 'netease-${t.id}';
    final existing = library.songs.where((s) => s.id == id).firstOrNull;
    if (existing != null) return existing;
    final song = Song(
      id: id,
      title: t.title,
      artist: t.producer,
      voice: t.voice,
      alias: t.alias,
      tags: [t.platform],
      color: 0xFF287C65,
      coverUrl: t.cover,
      netease: t.isQQ ? '' : 'https://music.163.com/song?id=${t.id}',
    );
    await library.add(song);
    return song;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.edit_note),
              label: Text('音乐手记'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.menu_book_outlined),
              label: Text('对应百科'),
            ),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: tab,
          children: [
            FutureBuilder<Song>(
              future: prepared,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SongDetail(
                  compact: true,
                  key: ValueKey(snapshot.data!.id),
                  song: snapshot.data!,
                  onSave: (song) => journalLibrary!.update(song),
                  music: widget.playback.music,
                  playback: widget.playback,
                );
              },
            ),
            SongWikiPanel(
              key: ValueKey('note-wiki:${widget.track.id}'),
              music: widget.playback.music,
              track: widget.track,
            ),
          ],
        ),
      ),
    ],
  );
}
