import 'phone_theme.dart';
import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/sources.dart';
import '../services/wiki.dart';
import 'song_detail.dart';
import 'wiki_reader.dart';
import 'wiki_mosaic.dart';

class WikiExplorer extends StatefulWidget {
  const WikiExplorer({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  State<WikiExplorer> createState() => _WikiExplorerState();
}

class _WikiExplorerState extends State<WikiExplorer> {
  final service = WikiService();
  final input = TextEditingController();
  List<WikiEntry>? results;
  List<WikiEntry> random = [];
  bool randomLoading = false;
  String? randomError;
  String? error;
  String searched = '';
  bool loading = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) search(widget.initialQuery);
    loadRandom();
  }

  Future<void> loadRandom() async {
    setState(() {
      randomLoading = true;
      randomError = null;
    });
    try {
      final found = await service.randomEntries(5 + Random().nextInt(4));
      if (mounted) setState(() => random = found);
    } catch (_) {
      if (mounted) setState(() => randomError = '随机条目暂未加载，点击换一批重试');
    } finally {
      if (mounted) setState(() => randomLoading = false);
    }
  }

  void open(WikiEntry entry) => showDialog<void>(
    context: context,
    builder: (dialog) => AdaptiveDialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 900,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭百科',
                    onPressed: () => Navigator.pop(dialog),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: WikiReader(
                pageId: entry.pageId,
                title: entry.title,
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    generation++;
    service.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> search([String? preset]) async {
    if (preset != null) input.text = preset;
    final query = input.text.trim();
    if (query.isEmpty) return;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      searched = query;
      results = null;
    });
    try {
      final entries = await service.search(query);
      if (mounted && request == generation) setState(() => results = entries);
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = '暂时无法查询 VocaWiki，请检查网络或打开原站搜索。');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (MediaQuery.sizeOf(context).height >= 500)
          Text(
            isPhoneLayout(context) ? '发现歌曲背后的故事' : '每一首歌背后，\n都有一个值得读的故事。',
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 18 : 30,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        if (MediaQuery.sizeOf(context).height >= 500) const SizedBox(height: 6),
        if (MediaQuery.sizeOf(context).height >= 500)
          const Text(
            '查找歌曲、P 主与虚拟歌手',
            style: TextStyle(color: Color(0xFF74847C), height: 1.8),
          ),
        if (MediaQuery.sizeOf(context).height >= 500)
          const SizedBox(height: 12),
        TextField(
          controller: input,
          maxLength: 100,
          onSubmitted: (_) => search(),
          decoration: const InputDecoration(
            labelText: '搜索 VocaWiki',
            hintText: '例如：初音未来、wowaka、炉心融解',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: loading ? null : search,
              icon: Icon(
                loading ? Icons.hourglass_top : Icons.search,
                size: 17,
              ),
              label: Text(loading ? '正在查询…' : '搜索百科'),
            ),
            TextButton.icon(
              onPressed: () => openSource(
                context,
                input.text.trim().isEmpty
                    ? Uri.https('voca.wiki', '/')
                    : Sources.search(Source.wiki, input.text.trim()),
              ),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('打开原站'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xFFAA5A4D))),
        if (results != null) ...[
          Text(
            '“$searched”的搜索结果',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (results!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('没有找到条目，试试日文原名或 P 主名。'),
            ),
          for (final entry in results!)
            Card(
              elevation: 0,
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
                leading: const Icon(
                  Icons.article_outlined,
                  color: Color(0xFF287C65),
                ),
                title: Text(entry.title),
                subtitle: const Text(
                  'VocaWiki · 在应用内阅读',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.north_east, size: 17),
                onTap: () => open(entry),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                '百科漫游 · 随机遇见',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: randomLoading ? null : loadRandom,
              icon: const Icon(Icons.shuffle, size: 17),
              label: const Text('换一批'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (randomLoading) const LinearProgressIndicator(),
        if (randomError != null) Text(randomError!),
        WikiMosaic(entries: random, onOpen: open),
        const SizedBox(height: 32),
        const Text(
          '搜索与正文由 VocaWiki MediaWiki API 提供，条目可在应用内阅读。VocaWiki 与本应用无隶属关系。',
          style: TextStyle(color: Color(0xFF74847C), fontSize: 11, height: 1.8),
        ),
      ],
    ),
  );
}
