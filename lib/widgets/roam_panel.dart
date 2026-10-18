import 'phone_theme.dart';
import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import '../services/playback.dart';
import '../services/song_theme.dart';

class RoamPanel extends StatefulWidget {
  const RoamPanel({super.key, required this.music, this.playback});
  final MusicService music;
  final Playback? playback;
  @override
  State<RoamPanel> createState() => _RoamPanelState();
}

class _RoamPanelState extends State<RoamPanel> {
  List<MusicTrack> songs = [];
  String? error;
  bool loading = true;
  int generation = 0;
  String provider = '';
  @override
  void initState() {
    super.initState();
    provider = widget.music.audioProvider;
    widget.music.addListener(changed);
    load();
  }

  @override
  void dispose() {
    generation++;
    widget.music.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (provider != widget.music.audioProvider) {
      provider = widget.music.audioProvider;
      songs = [];
      load();
    }
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.music.roam(songs.map((s) => s.id).toList());
      if (mounted && generation == request) setState(() => songs = result);
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  void play(MusicTrack song) => widget.playback?.play(song, tracks: songs);
  Widget cover(MusicTrack song, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: size,
      height: size,
      child: song.cover.isEmpty
          ? const ColoredBox(color: Color(0xFFCBDDD1), child: Icon(Icons.album))
          : Image.network(
              widget.music.image(song.cover),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.album),
            ),
    ),
  );
  Future<void> showBatch() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AdaptiveDialog(
      child: SizedBox(
        width: 600,
        height: 650,
        child: Column(
          children: [
            ListTile(
              title: Text('本批漫游 · ${songs.length} 首'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, i) => ListTile(
                  leading: cover(songs[i], 42),
                  title: Text(songs[i].title, maxLines: 1),
                  subtitle: Text(songs[i].artist, maxLines: 1),
                  onTap: () {
                    play(songs[i]);
                    Navigator.pop(dialogContext);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(isPhoneLayout(context) ? 12 : 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        colors: [songAppearance.preset.panel, songAppearance.preset.background],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '歌曲漫游',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isPhoneLayout(context) ? 18 : 23,
                ),
              ),
            ),
            if (isPhoneLayout(context)) ...[
              if (songs.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: '开始漫游',
                  onPressed: () => play(songs.first),
                  icon: const Icon(Icons.play_arrow, size: 20),
                ),
              IconButton(
                tooltip: '查看本批 ${songs.length} 首',
                onPressed: songs.isEmpty ? null : showBatch,
                icon: const Icon(Icons.queue_music, size: 20),
              ),
              IconButton(
                tooltip: '换一批漫游歌曲',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.shuffle, size: 18),
              ),
            ] else
              TextButton.icon(
                onPressed: loading ? null : load,
                icon: const Icon(Icons.shuffle, size: 17),
                label: Text(loading ? '正在选曲…' : '换一批'),
              ),
          ],
        ),
        Text(
          isPhoneLayout(context)
              ? '${widget.music.audioLabel} · 每批 24 首 · 随机遇见'
              : '${widget.music.audioLabel} · 每批 24 首术曲，随机遇见下一首喜欢',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isPhoneLayout(context) ? 10 : 11,
            height: isPhoneLayout(context) ? 1.5 : 1.8,
          ),
        ),
        const SizedBox(height: 8),
        if (loading && songs.isEmpty)
          const SizedBox(
            height: 130,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null && songs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(error!, style: const TextStyle(fontSize: 12)),
          )
        else
          SizedBox(
            height: isPhoneLayout(context)
                ? 92 +
                      MediaQuery.textScalerOf(context).scale(12) * 1.6 +
                      MediaQuery.textScalerOf(context).scale(10) * 1.6
                : 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(
                width: isPhoneLayout(context) ? 84 : 112,
                child: InkWell(
                  onTap: () => play(songs[i]),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          cover(songs[i], isPhoneLayout(context) ? 84 : 112),
                          const Positioned(
                            right: 6,
                            bottom: 6,
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        songs[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        songs[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (songs.isNotEmpty && !isPhoneLayout(context))
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => play(songs.first),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始漫游'),
              ),
              const Spacer(),
              TextButton(
                onPressed: showBatch,
                child: Text('查看 ${songs.length} 首'),
              ),
            ],
          ),
        if (error != null && songs.isNotEmpty)
          Text(error!, style: const TextStyle(fontSize: 10, color: Colors.red)),
      ],
    ),
  );
}
