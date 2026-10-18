import 'phone_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../services/wiki.dart';
import 'song_detail.dart';
import 'wiki_image.dart';
import '../services/collections.dart';

class WikiReader extends StatefulWidget {
  const WikiReader({super.key, this.pageId, this.title, this.embedded = false});
  final bool embedded;
  final int? pageId;
  final String? title;
  @override
  State<WikiReader> createState() => _WikiReaderState();
}

class _WikiReaderState extends State<WikiReader> {
  final service = WikiService();
  late Future<WikiDocument> article;
  @override
  void initState() {
    super.initState();
    article = service.article(pageId: widget.pageId, title: widget.title);
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<bool> link(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return true;
    if (uri.host == 'voca.wiki' && uri.fragment.isEmpty) {
      final id = int.tryParse(uri.queryParameters['curid'] ?? '');
      final title =
          uri.queryParameters['title'] ??
          (uri.path != '/' && !uri.path.endsWith('.php')
              ? Uri.decodeComponent(uri.path.substring(1))
              : null);
      if (id != null || title != null) {
        if (widget.embedded) {
          setState(() => article = service.article(pageId: id, title: title));
          return true;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => WikiReader(pageId: id, title: title),
          ),
        );
        return true;
      }
    }
    if (uri.fragment.isNotEmpty && uri.host == 'voca.wiki') return false;
    if (['https', 'http'].contains(uri.scheme)) await openSource(context, uri);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? body(context)
      : Scaffold(
          appBar: AppBar(title: Text(widget.title ?? 'VocaWiki 条目')),
          body: body(context),
        );

  Widget body(BuildContext context) => FutureBuilder<WikiDocument>(
    future: article,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(
                    () => article = service.article(
                      pageId: widget.pageId,
                      title: widget.title,
                    ),
                  ),
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final page = snapshot.data!;
      return SelectionArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.title,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 24
                          : 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      ListenableBuilder(
                        listenable: collections,
                        builder: (context, _) => TextButton.icon(
                          onPressed: () =>
                              collections.toggleWiki(page.pageId, page.title),
                          icon: Icon(
                            collections.wikis.containsKey('${page.pageId}')
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          label: const Text('收藏百科'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => openSource(context, page.original),
                        icon: const Icon(Icons.open_in_new, size: 15),
                        label: const Text('来源：VocaWiki'),
                      ),
                      TextButton(
                        onPressed: () => openSource(context, page.history),
                        child: const Text('作者与修订历史'),
                      ),
                    ],
                  ),
                  const Text(
                    '文字依据 CC BY-NC-SA 4.0 展示；图片、歌词等可能另有许可，以原站说明为准。页面为适配阅读排版，部分交互组件可能省略。',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF74847C),
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  HtmlWidget(
                    page.html,
                    baseUrl: page.original,
                    onTapUrl: link,
                    customWidgetBuilder: buildWikiImage,
                    textStyle: TextStyle(
                      fontSize: isPhoneLayout(context) ? 13.5 : 15,
                      height: isPhoneLayout(context) ? 1.65 : 1.8,
                    ),
                    onErrorBuilder: (_, element, _) =>
                        element.localName == 'img'
                        ? const SizedBox.shrink()
                        : const Text('该内容暂无法展示，可查看原文。'),
                    customStylesBuilder: (element) =>
                        switch (element.localName) {
                          'table' => {
                            'max-width': '100%',
                            if (element.classes.contains('wikitable')) ...{
                              'border': '1px solid #a2a9b1',
                              'border-collapse': 'collapse',
                            },
                          },
                          'td' || 'th' => {
                            if (element.parent?.parent?.classes.contains(
                                      'wikitable',
                                    ) ==
                                    true ||
                                element.parent?.parent?.parent?.classes
                                        .contains('wikitable') ==
                                    true)
                              'border': '1px solid #a2a9b1',
                            'padding': '5px 8px',
                          },
                          'center' => {'text-align': 'center'},
                          'div' => {
                            if (element.classes.contains('center'))
                              'text-align': 'center',
                          },
                          'img' => {
                            'max-width': '100%',
                            'height': 'auto',
                            'object-fit': 'contain',
                          },
                          'h2' => {'margin-top': '28px'},
                          _ => null,
                        },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '来源：VocaWiki · 修订 ${page.revision}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF74847C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
