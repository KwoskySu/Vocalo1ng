import 'phone_theme.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/collections.dart';
import '../services/playback.dart';
import 'brand_mark.dart';

Future<String?> createCollectionFolder(BuildContext context) async {
  final input = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: const Text('新建收藏夹'),
      content: TextField(
        controller: input,
        maxLength: 30,
        autofocus: true,
        decoration: const InputDecoration(hintText: '收藏夹名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, input.text.trim()),
          child: const Text('创建'),
        ),
      ],
    ),
  );
  input.dispose();
  if (name != null && name.isNotEmpty) {
    await collections.createFolder(name);
    return name;
  }
  return null;
}

Future<void> chooseFolders(BuildContext context, MusicTrack track) async {
  final selected = collections.folders.entries
      .where((e) => e.value.contains(track.id))
      .map((e) => e.key)
      .toSet();
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: const Text('收藏到收藏夹'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final name in collections.folders.keys)
                  CheckboxListTile(
                    value: selected.contains(name),
                    title: Text(name),
                    onChanged: (on) => set(
                      () => on! ? selected.add(name) : selected.remove(name),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final name = await createCollectionFolder(context);
                      if (name != null && context.mounted) {
                        set(() => selected.add(name));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建收藏夹'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await collections.setFolders(track, selected);
              if (dialog.mounted) Navigator.pop(dialog);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class CollectionActions extends StatelessWidget {
  const CollectionActions({
    super.key,
    required this.track,
    this.compact = false,
  });
  final MusicTrack track;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collections,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: collections.liked.contains(track.id)
              ? '取消 Vocalo1ng 喜爱'
              : '加入 Vocalo1ng 喜爱',
          onPressed: () => collections.toggleLike(track),
          icon: BrandMark(
            size: compact ? 20 : 25,
            inverted: collections.liked.contains(track.id),
          ),
        ),
        IconButton(
          tooltip: '收藏到收藏夹',
          onPressed: () => chooseFolders(context, track),
          icon: Icon(
            collections.folders.values.any((f) => f.contains(track.id))
                ? Icons.folder_special
                : Icons.create_new_folder_outlined,
            size: compact ? 20 : 24,
          ),
        ),
      ],
    ),
  );
}

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, required this.playback});
  final Playback? playback;
  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  String? folder;
  bool likes = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collections,
    builder: (context, _) {
      final ids = likes
          ? collections.liked
          : folder != null
          ? collections.folders[folder] ?? <String>{}
          : {
              ...collections.liked,
              ...collections.folders.values.expand((f) => f),
            };
      final tracks = ids
          .map((id) => collections.tracks[id])
          .whereType<MusicTrack>()
          .toList();
      return ListView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  likes ? 'Vocalo1ng 喜爱' : folder ?? '我的收藏夹',
                  style: TextStyle(
                    fontSize: isPhoneLayout(context) ? 18 : 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Vocalo1ng 喜爱',
                onPressed: () => setState(() => likes = !likes),
                icon: BrandMark(size: isPhoneLayout(context) ? 24 : 32),
              ),
              IconButton(
                tooltip: '新建收藏夹',
                onPressed: () => createCollectionFolder(context),
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部收藏'),
                selected: !likes && folder == null,
                onSelected: (_) => setState(() {
                  likes = false;
                  folder = null;
                }),
              ),
              ChoiceChip(
                avatar: const BrandMark(size: 20),
                label: Text('VOCALO1ng 喜爱 · ${collections.liked.length}'),
                tooltip: '系统收藏夹 · 不可删除；与歌曲上的 VOCALO1ng 标志同步',
                selected: likes,
                onSelected: (_) => setState(() {
                  likes = true;
                  folder = null;
                }),
              ),
              for (final name in collections.folders.keys)
                ChoiceChip(
                  label: Text('$name · ${collections.folders[name]!.length}'),
                  selected: !likes && folder == name,
                  onSelected: (_) => setState(() {
                    likes = false;
                    folder = name;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('这里还没有歌曲。使用播放栏的 Vocalo1ng 按钮标记喜爱，或收藏到文件夹。'),
            ),
          for (final track in tracks)
            ListTile(
              leading: SizedBox.square(
                dimension: 52,
                child: Image.network(
                  widget.playback?.music.image(track.cover) ?? track.cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.album),
                ),
              ),
              title: Text(track.title),
              subtitle: Text('${track.artist} · ${track.platform}'),
              onTap: () => widget.playback?.play(track, tracks: tracks),
              trailing: CollectionActions(track: track, compact: true),
            ),
        ],
      );
    },
  );
}
