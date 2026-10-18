import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../services/library.dart';
import '../services/collections.dart';
import '../services/export.dart';
import '../services/song_theme.dart';
import '../services/bar_preferences.dart';
import '../services/portable_data.dart';

// Account tokens, gateway URLs and device-specific paths are never shared.
bool _portable(String key) => portableKeys.contains(key);

class DataTransfer extends StatefulWidget {
  const DataTransfer({super.key, required this.library});
  final Library library;
  @override
  State<DataTransfer> createState() => _DataTransferState();
}

class _DataTransferState extends State<DataTransfer> {
  bool busy = false;
  String? status;
  Future<void> transfer(bool importing) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final prefs = widget.library.preferences;
      if (!importing) {
        final values = {
          for (final key in prefs.getKeys().where(_portable))
            key: prefs.get(key),
        };
        final saved = await exportFile(
          utf8.encode(
            jsonEncode({
              'format': 'vocalo1ng',
              'version': 1,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'data': values,
            }),
          ),
          'Vocalo1ng-data.json',
          'application/json',
        );
        if (mounted && saved) {
          setState(() => status = '已导出，可在另一设备导入。账号需要在各设备分别登录。');
        }
      } else {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'JSON',
              extensions: ['json'],
              mimeTypes: ['application/json'],
            ),
          ],
        );
        if (file == null) return;
        if (await file.length() > 10 * 1024 * 1024) {
          throw const FormatException('文件超过 10 MB');
        }
        final values = parsePortableData(await file.readAsString());
        if (!mounted) return;
        final merge = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('导入跨端数据'),
            content: const Text(
              '将合并收藏和歌曲手记，同一 ID 的手记采用导入内容。外观设置采用导入文件，账号保持不变。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('导入'),
              ),
            ],
          ),
        );
        if (merge != true) return;
        // Keep a local snapshot before the explicit import, without credentials.
        await prefs.setString(
          'vocalo1ng.import.previous',
          jsonEncode({
            for (final key in prefs.getKeys().where(_portable))
              key: prefs.get(key),
          }),
        );
        for (final entry in values.entries) {
          dynamic value = entry.value;
          if (entry.key == 'vocashelf.library.v1') {
            final songs = {
              for (final s in widget.library.songs) s.id: s.toJson(),
            };
            for (final row in jsonDecode(value) as List) {
              songs[row['id'] as String] = row;
            }
            value = jsonEncode(songs.values.toList());
          } else if (entry.key == 'vocalo1ng.collections.v1') {
            final c = jsonDecode(value) as Map;
            final old =
                jsonDecode(
                      prefs.getString(entry.key) ??
                          '{"tracks":[],"liked":[],"folders":{},"comments":{},"wikis":{}}',
                    )
                    as Map;
            final tracks = {
              for (final t in old['tracks'] as List) t['id']: t,
              for (final t in c['tracks'] as List) t['id']: t,
            };
            final folders = Map<String, dynamic>.from(old['folders']);
            for (final f in (c['folders'] as Map).entries) {
              folders[f.key as String] = {
                ...?folders[f.key] as List?,
                ...f.value as List,
              }.toList();
            }
            value = jsonEncode({
              'tracks': tracks.values.toList(),
              'liked': {
                ...old['liked'] as List,
                ...c['liked'] as List,
              }.toList(),
              'folders': folders,
              'comments': {
                ...?old['comments'] as Map?,
                ...?c['comments'] as Map?,
              },
              'wikis': {...?old['wikis'] as Map?, ...?c['wikis'] as Map?},
            });
          }
          final ok = value is String
              ? await prefs.setString(entry.key, value)
              : value is bool
              ? await prefs.setBool(entry.key, value)
              : value is int
              ? await prefs.setInt(entry.key, value)
              : value is double
              ? await prefs.setDouble(entry.key, value)
              : await prefs.setStringList(entry.key, List<String>.from(value));
          if (!ok) throw StateError('保存失败');
        }
        widget.library.reload();
        await collections.load();
        await songAppearance.load();
        await barPreferences.load();
        if (mounted) setState(() => status = '导入完成。收藏与手记已合并。');
      }
    } catch (error) {
      if (mounted) setState(() => status = '操作未完成：$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('跨设备数据 · JSON', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('安卓与电脑各自独立运行。收藏、百科、评论、手记可通过文件互通，无需处于同一网络。'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : () => transfer(false),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('导出 JSON'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => transfer(true),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('导入 JSON'),
          ),
        ],
      ),
      if (status != null) Text(status!),
    ],
  );
}
