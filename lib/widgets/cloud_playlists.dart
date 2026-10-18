import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import 'music_login.dart';

Future<void> addTrackToPlaylist(
  BuildContext context,
  MusicService music,
  MusicTrack track,
) async {
  if (!music.loggedIn && !await showMusicLogin(context, music)) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => PlaylistPicker(music: music, track: track),
  );
}

Future<MusicPlaylist?> createCloudPlaylist(
  BuildContext context,
  MusicService music,
) async => showDialog<MusicPlaylist>(
  context: context,
  builder: (_) => CreatePlaylistDialog(music: music),
);

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key, required this.music});
  final MusicService music;
  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final name = TextEditingController();
  bool private = true, saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = '请填写歌单名称');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final playlist = await widget.music.createPlaylist(
        name.text.trim(),
        private: private,
      );
      if (mounted) Navigator.pop(context, playlist);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('新建网易云歌单'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '歌单名称'),
            enabled: !saving,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('私密歌单'),
            subtitle: const Text('默认仅自己可见', style: TextStyle(fontSize: 11)),
            value: private,
            onChanged: saving ? null : (v) => setState(() => private = v),
          ),
          const Text(
            '创建后将保存到你当前登录的网易云账号。',
            style: TextStyle(fontSize: 11, color: Color(0xFF74847C)),
          ),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving ? null : create,
        child: Text(saving ? '正在创建…' : '创建歌单'),
      ),
    ],
  );
}

class PlaylistPicker extends StatefulWidget {
  const PlaylistPicker({super.key, required this.music, required this.track});
  final MusicService music;
  final MusicTrack track;
  @override
  State<PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends State<PlaylistPicker> {
  List<MusicPlaylist>? lists;
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await widget.music.playlists();
      if (mounted) setState(() => lists = values.where((p) => p.own).toList());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> add(MusicPlaylist playlist) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.music.addToPlaylist(playlist.id, widget.track.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已加入「${playlist.title}」')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('加入网易云歌单'),
    content: SizedBox(
      width: 400,
      height: 350,
      child: Column(
        children: [
          Text(
            widget.track.title,
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          if (saving) const LinearProgressIndicator(),
          Expanded(
            child: lists == null
                ? const Center(child: CircularProgressIndicator())
                : lists!.isEmpty
                ? const Center(child: Text('还没有自己创建的歌单。'))
                : ListView(
                    children: [
                      for (final list in lists!)
                        ListTile(
                          leading: Icon(
                            list.private
                                ? Icons.lock_outline
                                : Icons.queue_music,
                          ),
                          title: Text(list.title),
                          subtitle: Text('${list.count} 首'),
                          enabled: !saving,
                          onTap: () => add(list),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
      FilledButton.icon(
        onPressed: saving
            ? null
            : () async {
                final playlist = await createCloudPlaylist(
                  context,
                  widget.music,
                );
                if (playlist != null) {
                  await load();
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('新建歌单'),
      ),
    ],
  );
}
