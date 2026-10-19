import 'phone_theme.dart';
import 'package:file_selector/file_selector.dart';
import 'desktop_mode.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/playback.dart';
import '../services/song_theme.dart';
import '../services/bar_preferences.dart';
import '../services/collections.dart';
import 'now_playing.dart';
import 'collections.dart';
import 'brand_mark.dart';
import 'player_tools.dart';
import 'live_mode.dart';

class AudioBar extends StatelessWidget {
  const AudioBar({
    super.key,
    required this.playback,
    required this.onJournal,
    required this.onWiki,
    required this.onQueue,
  });
  final Playback playback;
  final VoidCallback onWiki, onQueue;
  final void Function(MusicTrack track, {String lyrics, bool share}) onJournal;
  String time(Duration t) =>
      '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
  Future<void> pick(BuildContext context) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: '音频',
            extensions: ['mp3', 'wav', 'm4a', 'ogg', 'flac'],
            mimeTypes: ['audio/*'],
            uniformTypeIdentifiers: ['public.audio'],
          ),
        ],
      );
      if (file != null) await playback.local(file.path, file.name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开此音频文件')));
      }
    }
  }

  Future<void> configure(BuildContext context) async {
    final selected = Set<String>.of(barPreferences.visible);
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('自定义播放栏按钮'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('播放控制与音乐手记固定显示，其余按钮可自由选择。'),
                  for (final action in barActions)
                    CheckboxListTile(
                      title: Text(action),
                      value: selected.contains(action),
                      onChanged: (on) => update(
                        () => on!
                            ? selected.add(action)
                            : selected.remove(action),
                      ),
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
                await barPreferences.set(selected);
                if (dialog.mounted) Navigator.pop(dialog);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void lyrics(BuildContext context) => showNowPlaying(
    context,
    playback,
    (track, line) => onJournal(track, lyrics: line, share: true),
  );
  void seek(int seconds) {
    final p = playback.player;
    final ms = (p.state.position.inMilliseconds + seconds * 1000).clamp(
      0,
      p.state.duration.inMilliseconds,
    );
    p.seek(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      playback,
      playback.music,
      songAppearance,
      barPreferences,
      collections,
    ]),
    builder: (context, _) {
      final p = playback.player,
          t = playback.current,
          active = t != null || playback.localName != null;
      final info = Row(
        children: [
          InkWell(
            onTap: t == null ? null : () => lyrics(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox.square(
                dimension: isPhoneLayout(context) ? 36 : 42,
                child: t?.cover.isNotEmpty == true
                    ? Image.network(
                        playback.music.image(t!.cover),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.album),
                      )
                    : const Icon(Icons.graphic_eq),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t?.title ?? playback.localName ?? 'Vocalo1ng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  playback.error ??
                      (playback.loading
                          ? '正在加载…'
                          : t == null
                          ? '选择一首喜欢的歌'
                          : '${t.artist} · ${t.platform}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      );
      final controls = Padding(
        padding: const EdgeInsets.only(left: 40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一首',
              onPressed: playback.queue.isEmpty ? null : playback.previous,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              tooltip: '后退10秒',
              onPressed: active ? () => seek(-10) : null,
              icon: const Icon(Icons.replay_10),
            ),
            StreamBuilder<bool>(
              stream: p.stream.playing,
              initialData: p.state.playing,
              builder: (context, s) => IconButton(
                tooltip: s.data == true ? '暂停' : '播放',
                onPressed: active && !playback.loading
                    ? () async {
                        if (playback.error != null && t != null) {
                          await playback.play(t);
                        } else {
                          await p.playOrPause();
                        }
                      }
                    : null,
                icon: Icon(
                  s.data == true
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 32,
                ),
              ),
            ),
            IconButton(
              tooltip: '前进10秒',
              onPressed: active ? () => seek(10) : null,
              icon: const Icon(Icons.forward_10),
            ),
            IconButton(
              tooltip: '下一首',
              onPressed: playback.queue.isEmpty ? null : playback.next,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: '音乐手记与百科',
              onPressed: t == null ? null : () => onJournal(t),
              icon: const Icon(Icons.edit_note),
            ),
          ],
        ),
      );
      final v = barPreferences.visible;
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t != null)
            IconButton(
              tooltip: '刷新当前歌曲播放地址',
              onPressed: playback.loading
                  ? null
                  : () => playback.setQuality(playback.quality),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: '直播模式窗口',
            onPressed: () => showLiveMode(context, playback),
            icon: const Icon(Icons.sensors),
          ),
          if (desktopModeSupported)
            IconButton(
              tooltip: '桌面模式',
              onPressed: () => showDesktopMode(context, playback),
              icon: const Icon(Icons.desktop_windows_outlined),
            ),
          if (t != null && v.contains('歌词'))
            IconButton(
              tooltip: '歌词',
              onPressed: () => lyrics(context),
              icon: const Icon(Icons.lyrics_outlined),
            ),
          if (t != null && v.contains('百科'))
            IconButton(
              tooltip: '歌曲百科',
              onPressed: onWiki,
              icon: const Icon(Icons.menu_book_outlined),
            ),
          if (t != null && v.contains('喜爱'))
            IconButton(
              tooltip: collections.liked.contains(t.id)
                  ? '取消 Vocalo1ng 喜爱'
                  : '加入 Vocalo1ng 喜爱',
              onPressed: () => collections.toggleLike(t),
              icon: BrandMark(
                size: 22,
                inverted: collections.liked.contains(t.id),
              ),
            ),
          if (t != null && v.contains('收藏夹'))
            IconButton(
              tooltip: '收藏到收藏夹',
              onPressed: () => chooseFolders(context, t),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          if (active && v.contains('播放列表'))
            IconButton(
              tooltip: '播放列表与播放方式',
              onPressed: onQueue,
              icon: const Icon(Icons.queue_music),
            ),
          if (t != null && v.contains('音质与悬浮歌词'))
            PlayerTools(playback: playback),
          if (v.contains('本地音频'))
            IconButton(
              tooltip: '打开本地音频',
              onPressed: () => pick(context),
              icon: const Icon(Icons.folder_open),
            ),
          IconButton(
            tooltip: '自定义播放栏按钮',
            onPressed: () => configure(context),
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
        ],
      );
      return Material(
        color: songAppearance.preset.panel,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isPhoneLayout(context) ? 10 : 16,
            4,
            10,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, box) =>
                    isPhoneLayout(context) &&
                        MediaQuery.sizeOf(context).height < 480
                    ? Row(
                        children: [
                          Expanded(child: info),
                          SizedBox(
                            width: 250,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: controls,
                            ),
                          ),
                          IconButton(
                            tooltip: '播放工具',
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              builder: (_) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: actions,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : box.maxWidth >= 1050
                    ? Row(
                        children: [
                          Expanded(child: info),
                          SizedBox(width: 300, child: Center(child: controls)),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: actions,
                              ),
                            ),
                          ),
                        ],
                      )
                    : isPhoneLayout(context)
                    ? Row(
                        children: [
                          Expanded(child: info),
                          IconButton(
                            tooltip: '上一首',
                            onPressed: playback.queue.isEmpty
                                ? null
                                : playback.previous,
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          StreamBuilder<bool>(
                            stream: p.stream.playing,
                            initialData: p.state.playing,
                            builder: (context, state) => IconButton(
                              tooltip: state.data == true ? '暂停' : '播放',
                              onPressed: active && !playback.loading
                                  ? () async {
                                      if (playback.error != null && t != null) {
                                        await playback.play(t);
                                      } else {
                                        await p.playOrPause();
                                      }
                                    }
                                  : null,
                              icon: Icon(
                                state.data == true
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                size: 32,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '下一首',
                            onPressed: playback.queue.isEmpty
                                ? null
                                : playback.next,
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                          IconButton(
                            tooltip: '播放工具与自定义按钮',
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              showDragHandle: true,
                              builder: (_) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  20,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    IconButton(
                                      tooltip: '音乐手记与百科',
                                      onPressed: t == null
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              onJournal(t);
                                            },
                                      icon: const Icon(Icons.edit_note),
                                    ),
                                    ...actions.children,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          info,
                          Center(child: controls),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: actions,
                          ),
                        ],
                      ),
              ),
              if (active)
                StreamBuilder<Duration>(
                  stream: p.stream.duration,
                  initialData: p.state.duration,
                  builder: (context, d) => StreamBuilder<Duration>(
                    stream: p.stream.position,
                    initialData: p.state.position,
                    builder: (context, s) {
                      final max = d.data!.inMilliseconds.toDouble();
                      return SizedBox(
                        height: isPhoneLayout(context) ? 18 : 28,
                        child: Row(
                          children: [
                            Text(
                              time(s.data!),
                              style: const TextStyle(fontSize: 10),
                            ),
                            Expanded(
                              child: Slider(
                                value: s.data!.inMilliseconds.toDouble().clamp(
                                  0,
                                  max > 0 ? max : 1,
                                ),
                                max: max > 0 ? max : 1,
                                onChanged: max > 0
                                    ? (n) => p.seek(
                                        Duration(milliseconds: n.round()),
                                      )
                                    : null,
                              ),
                            ),
                            Text(
                              time(d.data!),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
