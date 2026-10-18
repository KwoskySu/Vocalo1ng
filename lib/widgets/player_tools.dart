import 'package:flutter/material.dart';
import '../services/playback.dart';
import 'song_detail.dart';
import 'floating_lyrics.dart';

Future<void> showQuality(BuildContext context, Playback playback) async {
  final messenger = ScaffoldMessenger.of(context);
  final track = playback.current;
  if (track == null) return;
  Future<Map<String, dynamic>> fetch() =>
      playback.music.request('/api/music/qualities', params: {'id': track.id});
  var pending = fetch();
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        scrollable: true,
        title: Text('${track.platform} · 音质'),
        content: SizedBox(
          width: 370,
          child: FutureBuilder<Map<String, dynamic>>(
            future: pending,
            builder: (context, snap) {
              if (snap.hasError) return Text('${snap.error}');
              if (snap.connectionState == ConnectionState.waiting ||
                  !snap.hasData) {
                return const SizedBox(
                  height: 70,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final q in snap.data!['qualities'] as List)
                    ListTile(
                      leading: Icon(
                        q['locked'] == true
                            ? Icons.lock_outline
                            : playback.quality == q['id']
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(q['label'] as String),
                      subtitle: Text(q['reason'] as String? ?? ''),
                      onTap: q['locked'] == true
                          ? null
                          : () async {
                              Navigator.pop(dialog);
                              await playback.setQuality(q['id'] as String);
                              if (messenger.mounted && playback.error != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(playback.error!)),
                                );
                              }
                            },
                    ),
                  Text(
                    snap.data!['notice'] as String,
                    style: const TextStyle(fontSize: 11, height: 1.7),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => update(() => pending = fetch()),
            icon: const Icon(Icons.refresh),
            label: const Text('刷新实际音质权限'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('关闭'),
          ),
        ],
      ),
    ),
  );
}

Future<void> downloadTrack(BuildContext context, Playback playback) async {
  final track = playback.current;
  if (track == null) return;
  try {
    if (track.isQQ) {
      await openSource(
        context,
        Uri.parse(
          'https://y.qq.com/n/ryqq/songDetail/${track.id.substring(3)}',
        ),
      );
      return;
    }
    final data = await playback.music.request(
      '/api/download',
      params: {'id': track.id, 'quality': playback.quality, 'check': '1'},
    );
    if (context.mounted) {
      await openSource(
        context,
        Uri.parse(playback.music.base).resolve(data['path'] as String),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class PlayerTools extends StatelessWidget {
  const PlayerTools({super.key, required this.playback});
  final Playback playback;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '音质、下载与悬浮歌词',
    color: Theme.of(context).colorScheme.surface,
    icon: const Icon(Icons.tune, size: 21),
    onSelected: (v) {
      if (v == 'quality') showQuality(context, playback);
      if (v == 'download') downloadTrack(context, playback);
      if (v == 'floating') showFloatingLyrics(context, playback);
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'quality', child: Text('音质选择 · 账号权限')),
      PopupMenuItem(
        value: 'download',
        child: Text(
          playback.current?.isQQ == true ? 'QQ 音乐客户端下载' : '下载 · 验证平台权限',
        ),
      ),
      const PopupMenuItem(value: 'floating', child: Text('悬浮歌词窗口')),
    ],
  );
}
