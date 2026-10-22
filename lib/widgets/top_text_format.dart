import 'package:flutter/material.dart';
import '../models/top_chart.dart';
import 'adaptive_dialog.dart';
import 'player_visuals.dart' show lyricFontFamilies, lyricFontNames;

const topTextColors = [
  '',
  '#FFFFFF',
  '#20252B',
  '#667085',
  '#287C65',
  '#008FBA',
  '#B74870',
  '#754DB3',
  '#D5723A',
  '#AF892A',
  '#99DDBF',
  '#F3C9DE',
];

class TopTextFormatButton extends StatelessWidget {
  const TopTextFormatButton({
    super.key,
    required this.label,
    required this.style,
    required this.onChanged,
    this.onReset,
  });
  final String label;
  final TopTypography style;
  final ValueChanged<TopTypography> onChanged;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '设置「$label」字体与颜色',
    icon: const Icon(Icons.text_format),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _FormatDialog(
        label: label,
        initial: style,
        onChanged: onChanged,
        onReset: onReset,
      ),
    ),
  );
}

class _FormatDialog extends StatefulWidget {
  const _FormatDialog({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.onReset,
  });
  final String label;
  final TopTypography initial;
  final ValueChanged<TopTypography> onChanged;
  final VoidCallback? onReset;
  @override
  State<_FormatDialog> createState() => _FormatDialogState();
}

class _FormatDialogState extends State<_FormatDialog> {
  late final value = TopTypography.fromJson(widget.initial.toJson());
  late final color = TextEditingController(text: value.color);
  @override
  void dispose() {
    color.dispose();
    super.dispose();
  }

  void change(VoidCallback action) {
    setState(action);
    widget.onChanged(value);
  }

  Widget slider(
    String label,
    double current,
    double min,
    double max,
    ValueChanged<double> action,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(current.toStringAsFixed(1)),
        ],
      ),
      Slider(
        value: current,
        min: min,
        max: max,
        onChanged: (v) => change(() => action(v)),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: SizedBox(
      width: 480,
      height: 700,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.label} · 文字样式',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const CloseButton(),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  const Text('只修改这一个文本框的出图样式。'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: value.font,
                    decoration: const InputDecoration(labelText: '字体'),
                    items: [
                      for (final (i, name) in lyricFontNames.indexed)
                        DropdownMenuItem(value: i, child: Text(name)),
                    ],
                    onChanged: (v) {
                      if (v != null) change(() => value.font = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  slider('字号', value.size, 9, 72, (v) => value.size = v),
                  slider(
                    '字距',
                    value.tracking,
                    -1,
                    8,
                    (v) => value.tracking = v,
                  ),
                  slider('行距', value.height, 1, 2.4, (v) => value.height = v),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('加粗'),
                        selected: value.bold,
                        onSelected: (v) => change(() => value.bold = v),
                      ),
                      FilterChip(
                        label: const Text('斜体'),
                        selected: value.italic,
                        onSelected: (v) => change(() => value.italic = v),
                      ),
                      FilterChip(
                        label: const Text('下划线'),
                        selected: value.underline,
                        onSelected: (v) => change(() => value.underline = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: value.align,
                    decoration: const InputDecoration(labelText: '对齐方式'),
                    items: const [
                      DropdownMenuItem(value: -1, child: Text('沿用整体')),
                      DropdownMenuItem(value: 0, child: Text('左对齐')),
                      DropdownMenuItem(value: 1, child: Text('居中')),
                      DropdownMenuItem(value: 2, child: Text('右对齐')),
                    ],
                    onChanged: (v) {
                      if (v != null) change(() => value.align = v);
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text('文字颜色'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in topTextColors)
                        InkWell(
                          onTap: () {
                            color.text = hex;
                            change(() => value.color = hex);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: hex.isEmpty
                                  ? Colors.transparent
                                  : Color(
                                      0xff000000 |
                                          int.parse(
                                            hex.substring(1),
                                            radix: 16,
                                          ),
                                    ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: value.color == hex
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                width: value.color == hex ? 3 : 1,
                              ),
                            ),
                            child: hex.isEmpty
                                ? const Icon(Icons.format_color_reset, size: 20)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: color,
                    decoration: const InputDecoration(
                      labelText: '自定义颜色 #RRGGBB，留空自动',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) =>
                        v == null ||
                            v.isEmpty ||
                            RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(v)
                        ? null
                        : '请输入六位十六进制颜色',
                    onChanged: (v) {
                      if (v.isEmpty || RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(v))
                        change(() => value.color = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: value.color.toUpperCase() == '#FFFFFF'
                          ? const Color(0xff394452)
                          : const Color(0xffeff2f4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '让每一份喜欢，都有自己的形状。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: lyricFontFamilies[value.font],
                        fontSize: 21,
                        fontWeight: value.bold
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontStyle: value.italic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        decoration: value.underline
                            ? TextDecoration.underline
                            : null,
                        letterSpacing: value.tracking,
                        height: value.height,
                        color: value.color.isEmpty
                            ? const Color(0xff273831)
                            : Color(
                                0xff000000 |
                                    int.parse(
                                      value.color.substring(1),
                                      radix: 16,
                                    ),
                              ),
                      ),
                    ),
                  ),
                  if (widget.onReset != null)
                    TextButton(
                      onPressed: () {
                        widget.onReset!();
                        Navigator.pop(context);
                      },
                      child: const Text('恢复沿用榜单全局字体'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
