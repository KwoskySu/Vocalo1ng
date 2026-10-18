import 'phone_theme.dart';
import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../services/song_theme.dart';
import 'player_visuals.dart';

class ThemeSettings extends StatelessWidget {
  const ThemeSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: songAppearance,
    builder: (context, _) => Card(
      child: Padding(
        padding: EdgeInsets.all(isPhoneLayout(context) ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '音乐主题 · 40 套预设',
              style: TextStyle(
                fontSize: isPhoneLayout(context) ? 17 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('播放时自动适配歌曲封面'),
              subtitle: Text('当前：${songAppearance.preset.name}'),
              value: songAppearance.automatic,
              onChanged: songAppearance.setAutomatic,
            ),
            if (isPhoneLayout(context))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('选择配色预设'),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < songThemes.length; i++)
                        ChoiceChip(
                          selected: songAppearance.index == i,
                          avatar: CircleAvatar(
                            backgroundColor: songThemes[i].seed,
                            radius: 8,
                          ),
                          label: Text(songThemes[i].name),
                          onSelected: (_) => songAppearance.select(i),
                        ),
                    ],
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < songThemes.length; i++)
                    ChoiceChip(
                      selected: songAppearance.index == i,
                      avatar: CircleAvatar(
                        backgroundColor: songThemes[i].seed,
                        radius: 8,
                      ),
                      label: Text(songThemes[i].name),
                      onSelected: (_) => songAppearance.select(i),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            if (isPhoneLayout(context))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('背景视觉'),
                subtitle: Text(backgroundStyleNames[songAppearance.lyricStyle]),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (i, name) in backgroundStyleNames.indexed)
                        ChoiceChip(
                          selected: songAppearance.lyricStyle == i,
                          label: Text(name),
                          onSelected: (_) => songAppearance.setLyricStyle(i),
                        ),
                    ],
                  ),
                ],
              )
            else ...[
              const Text(
                '歌词视觉样式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final (i, name) in backgroundStyleNames.indexed)
                    ChoiceChip(
                      selected: songAppearance.lyricStyle == i,
                      label: Text(name),
                      onSelected: (_) => songAppearance.setLyricStyle(i),
                    ),
                ],
              ),
            ],
            if (!isPhoneLayout(context))
              const Text(
                '点击左下角歌曲封面展开播放详情。视觉律动为装饰效果；减少动态效果会遵循系统设置。',
                style: TextStyle(fontSize: 11, height: 1.8),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AdaptiveDialog(
                  child: SizedBox(
                    width: 580,
                    height: 460,
                    child: VisualOptions(),
                  ),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('视觉实验室 · 字体与效果'),
            ),
          ],
        ),
      ),
    ),
  );
}
