import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../services/collections.dart';
import 'wiki_reader.dart';
import 'song_detail.dart';

class SavedWikiList extends StatelessWidget {
  const SavedWikiList({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collections,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (collections.wikis.isEmpty)
          const ListTile(title: Text('在百科文章中点击收藏，保存在这里。')),
        for (final item in collections.wikis.values)
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(item['title'] as String),
              subtitle: const Text('VocaWiki · 应用内阅读'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AdaptiveDialog(
                  child: SizedBox(
                    width: 960,
                    height: 760,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: CloseButton(
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        Expanded(
                          child: WikiReader(
                            pageId: item['id'] as int,
                            title: item['title'] as String,
                            embedded: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              trailing: IconButton(
                tooltip: '取消收藏',
                icon: const Icon(Icons.bookmark_remove_outlined),
                onPressed: () => collections.toggleWiki(
                  item['id'] as int,
                  item['title'] as String,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class SavedCommentList extends StatelessWidget {
  const SavedCommentList({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collections,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (collections.comments.isEmpty)
          const ListTile(title: Text('在歌曲或视频评论区收藏热评，保存在这里。')),
        for (final entry in collections.comments.entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value['text'] as String? ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${entry.value['author']} · ${entry.value['song'] ?? ''} · ♡ ${entry.value['likes']}',
                  ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          final uri = Uri.tryParse(
                            entry.value['source'] as String? ?? '',
                          );
                          if (uri != null && uri.scheme == 'https') {
                            openSource(context, uri);
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('查看出处'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            collections.toggleComment(entry.key, entry.value),
                        icon: const Icon(
                          Icons.bookmark_remove_outlined,
                          size: 16,
                        ),
                        label: const Text('取消收藏'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
