import 'package:flutter/material.dart';
import '../services/desktop_overlay.dart';
import '../services/playback.dart';
import 'adaptive_dialog.dart';
export '../services/desktop_overlay.dart' show desktopModeSupported;

Future<void> showDesktopMode(BuildContext context, Playback playback) =>
    showDialog<void>(
      context: context,
      builder: (_) => AdaptiveDialog(
        child: SizedBox(
          width: 580,
          height: 650,
          child: DesktopModeSettings(playback: playback),
        ),
      ),
    );

class DesktopModeSettings extends StatefulWidget {
  const DesktopModeSettings({super.key, required this.playback});
  final Playback playback;
  @override
  State<DesktopModeSettings> createState() => _DesktopModeSettingsState();
}

class _DesktopModeSettingsState extends State<DesktopModeSettings> {
  late final DesktopOverlay overlay;
  String selectedBlock = 'lyrics';
  @override
  void initState() {
    super.initState();
    overlay = desktopOverlayFor(widget.playback);
    overlay.load();
  }

  Widget slider(
    String title,
    double value,
    double min,
    double max,
    void Function(double) update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      Slider(
        key: ValueKey(title.split(' · ').first),
        value: value,
        min: min,
        max: max,
        onChanged: (v) {
          update(v);
          overlay.save();
        },
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: overlay,
    builder: (context, _) => Column(
      children: [
        const ListTile(title: Text('桌面模式'), trailing: CloseButton()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text(
                '先配置，再开启。展示层位于桌面图标后方，支持完全透明背景和点击穿透。Ctrl+Alt+D 或托盘双击可显示/隐藏，关闭后停止采集。',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开启桌面展示'),
                value: overlay.enabled,
                onChanged: desktopModeSupported ? overlay.toggle : null,
              ),
              const SizedBox(height: 8),
              const Text('独立组件布局 · 拖动移动，右下角拖动缩放'),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, box) => Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff1a2230),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        for (final entry in overlay.layout.entries)
                          Positioned(
                            left: entry.value[0] * box.maxWidth,
                            top: entry.value[1] * box.maxHeight,
                            width: entry.value[2] * box.maxWidth,
                            height: entry.value[3] * box.maxHeight,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => selectedBlock = entry.key),
                              onPanUpdate: (d) {
                                setState(() => selectedBlock = entry.key);
                                entry.value[0] =
                                    (entry.value[0] + d.delta.dx / box.maxWidth)
                                        .clamp(0, 1 - entry.value[2]);
                                entry.value[1] =
                                    (entry.value[1] +
                                            d.delta.dy / box.maxHeight)
                                        .clamp(0, 1 - entry.value[3]);
                                overlay.save();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedBlock == entry.key
                                        ? Colors.tealAccent
                                        : Colors.white30,
                                    width: 2,
                                  ),
                                  color: Colors.white.withValues(alpha: .06),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        {
                                          'cover': '封面 / 歌曲',
                                          'lyrics': '双语歌词',
                                          'graph': '音频频谱',
                                          'stats': 'CPU / GPU / RAM',
                                          'progress': '播放进度',
                                        }[entry.key]!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanUpdate: (d) {
                                          entry.value[2] =
                                              (entry.value[2] +
                                                      d.delta.dx / box.maxWidth)
                                                  .clamp(
                                                    .06,
                                                    1 - entry.value[0],
                                                  );
                                          entry.value[3] =
                                              (entry.value[3] +
                                                      d.delta.dy /
                                                          box.maxHeight)
                                                  .clamp(
                                                    .06,
                                                    1 - entry.value[1],
                                                  );
                                          overlay.save();
                                        },
                                        child: const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Icon(
                                            Icons.open_in_full,
                                            color: Colors.tealAccent,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final key in overlay.layout.keys)
                    ChoiceChip(
                      label: Text(
                        {
                          'cover': '封面',
                          'lyrics': '歌词',
                          'graph': '频谱',
                          'stats': '系统信息',
                          'progress': '进度条',
                        }[key]!,
                      ),
                      selected: selectedBlock == key,
                      onSelected: (_) => setState(() => selectedBlock = key),
                    ),
                ],
              ),
              for (final (i, label) in ['横向位置', '纵向位置', '组件宽度', '组件高度'].indexed)
                slider(
                  label,
                  overlay.layout[selectedBlock]![i],
                  i < 2 ? 0 : .06,
                  i < 2
                      ? 1 - overlay.layout[selectedBlock]![i + 2]
                      : 1 - overlay.layout[selectedBlock]![i - 2],
                  (v) => overlay.layout[selectedBlock]![i] = v,
                ),

              if (!desktopModeSupported)
                const Text('当前提供 Windows 桌面模式；安卓保留原有悬浮歌词，不额外申请桌面覆盖权限。'),
              Wrap(
                spacing: 8,
                children: [
                  for (final (i, text) in [
                    '顶部',
                    '底部',
                    '左侧',
                    '右侧',
                    '全屏环绕',
                  ].indexed)
                    ChoiceChip(
                      label: Text(text),
                      selected: overlay.edge == i,
                      onSelected: (_) {
                        overlay.edge = i;
                        overlay.save();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('桌面主题'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, label) in [
                    '冰川仪表',
                    '极光控制台',
                    '黑胶舞台',
                    '赛博监控',
                    '极简线条',
                    '樱色镜面',
                  ].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: overlay.style == i,
                      onSelected: (_) {
                        overlay.style = i;
                        overlay.save();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('音频图样式'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, label) in [
                    '频率柱',
                    '镜面频谱',
                    '真实波形',
                    '环形声场',
                    '分段电平',
                  ].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: overlay.graphStyle == i,
                      onSelected: (_) {
                        overlay.graphStyle = i;
                        overlay.save();
                      },
                    ),
                ],
              ),
              SwitchListTile(
                title: const Text('文字随边框自动适配'),
                subtitle: const Text('调整组件宽高时实时缩放，长歌词自动收小；下方比例可微调'),
                value: overlay.autoFont,
                onChanged: (v) {
                  overlay.autoFont = v;
                  overlay.save();
                },
              ),
              slider(
                '进度条粗细',
                overlay.progressThickness,
                1,
                24,
                (v) => overlay.progressThickness = v,
              ),
              slider(
                '进度圆点大小',
                overlay.progressThumb,
                0,
                20,
                (v) => overlay.progressThumb = v,
              ),
              const Text('进度条可在预览中单独拖动、缩放，或选中“进度条”调整宽高。'),
              slider(
                '字体大小 · ${(overlay.fontScale * 100).round()}%',
                overlay.fontScale,
                .65,
                2,
                (v) => overlay.fontScale = v,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in {
                    '歌曲名': overlay.title,
                    '歌手': overlay.artist,
                    '翻译': overlay.translation,
                  }.entries)
                    FilterChip(
                      label: Text(entry.key),
                      selected: entry.value,
                      onSelected: (v) {
                        if (entry.key == '歌曲名') overlay.title = v;
                        if (entry.key == '歌手') overlay.artist = v;
                        if (entry.key == '翻译') overlay.translation = v;
                        overlay.save();
                      },
                    ),
                  FilterChip(
                    label: const Text('封面'),
                    selected: overlay.cover,
                    onSelected: (v) {
                      overlay.cover = v;
                      overlay.save();
                    },
                  ),
                  FilterChip(
                    label: const Text('双语歌词'),
                    selected: overlay.lyrics,
                    onSelected: (v) {
                      overlay.lyrics = v;
                      overlay.save();
                    },
                  ),
                  FilterChip(
                    label: const Text('歌曲进度'),
                    selected: overlay.progress,
                    onSelected: (v) {
                      overlay.progress = v;
                      overlay.save();
                    },
                  ),
                  FilterChip(
                    label: const Text('歌曲音频图'),
                    selected: overlay.graph,
                    onSelected: (v) {
                      overlay.graph = v;
                      overlay.save();
                    },
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('CPU / GPU / 内存信息'),
                value: overlay.stats,
                onChanged: (v) {
                  overlay.stats = v;
                  overlay.save();
                },
              ),
              if (overlay.stats)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in {
                      'cpu': 'CPU占用',
                      'gpu': 'GPU占用',
                      'ram': '内存占用',
                      'clock': '内存配置频率',
                      'cpuClock': 'CPU 实时频率',
                      'gpuClock': 'GPU 实时频率',
                      'gpuMemoryClock': '显存实时频率',
                    }.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: overlay.statItems.contains(entry.key),
                        onSelected: (v) {
                          if (v) {
                            overlay.statItems.add(entry.key);
                          } else {
                            overlay.statItems.remove(entry.key);
                          }
                          overlay.save();
                        },
                      ),
                  ],
                ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '频谱仅分析本应用的音频输出，不采集麦克风。背景始终逐像素透明，所有内容位于桌面图标和其他窗口之下。CPU/GPU 频率来自系统与驱动；内存频率为配置报告值。驱动未提供数据时显示 --。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (overlay.error != null)
                Text(
                  overlay.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DesktopQuickToggle extends StatefulWidget {
  const DesktopQuickToggle({super.key, required this.playback});
  final Playback playback;
  @override
  State<DesktopQuickToggle> createState() => _DesktopQuickToggleState();
}

class _DesktopQuickToggleState extends State<DesktopQuickToggle> {
  late final DesktopOverlay overlay;
  @override
  void initState() {
    super.initState();
    overlay = desktopOverlayFor(widget.playback);
    overlay.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: overlay,
    builder: (context, _) => IconButton(
      tooltip: '桌面模式 · 设置并开启',
      isSelected: overlay.enabled,
      onPressed: () async {
        await overlay.load();
        if (context.mounted) await showDesktopMode(context, widget.playback);
      },
      icon: const Icon(Icons.desktop_windows_outlined),
      selectedIcon: const Icon(Icons.desktop_windows),
    ),
  );
}
