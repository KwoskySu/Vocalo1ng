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
              const Text('沿桌面四边展示歌曲。窗口始终透明穿透、不抢焦点，所有位置和尺寸在这里调整；再次关闭开关即可移除。'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开启桌面展示'),
                value: overlay.enabled,
                onChanged: desktopModeSupported ? overlay.toggle : null,
              ),
              if (!desktopModeSupported)
                const Text('当前提供 Windows 桌面模式；安卓保留原有悬浮歌词，不额外申请桌面覆盖权限。'),
              Wrap(
                spacing: 8,
                children: [
                  for (final (i, text) in ['顶部', '底部', '左侧', '右侧'].indexed)
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
              slider('展示大小', overlay.scale, .65, 1.5, (v) => overlay.scale = v),
              slider(
                '沿边长度',
                overlay.extent,
                .3,
                .95,
                (v) => overlay.extent = v,
              ),
              slider('沿边位置', overlay.offset, 0, 1, (v) => overlay.offset = v),
              slider(
                '不透明度',
                overlay.opacity,
                .3,
                1,
                (v) => overlay.opacity = v,
              ),
              Wrap(
                spacing: 8,
                children: [
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
                    label: const Text('系统音频电平图'),
                    selected: overlay.graph,
                    onSelected: (v) {
                      overlay.graph = v;
                      overlay.save();
                    },
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '音频图显示默认输出设备的实际电平历史，包含其他程序的声音；设备不可用时保持静止，不生成模拟频谱。',
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
