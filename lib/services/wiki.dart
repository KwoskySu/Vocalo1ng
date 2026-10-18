import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'music.dart';

class WikiEntry {
  const WikiEntry(
    this.title,
    this.pageId, [
    this.snippet = '',
    this.image = '',
  ]);
  final String title, snippet, image;
  final int pageId;
  Uri get uri => Uri.https('voca.wiki', '/', {'curid': '$pageId'});
}

class WikiService {
  WikiService({http.Client? client, bool? useGateway})
    : direct = !(useGateway ?? client == null),
      client = client ?? http.Client();
  final bool direct;
  bool _legacyGateway = false;
  Future<http.Response> get(Uri target) async {
    if (!direct && !_legacyGateway) {
      try {
        final response = await client
            .get(
              Uri.parse(gatewayBase())
                  .resolve('/api/wiki')
                  .replace(queryParameters: target.queryParameters),
              headers: {'X-VocaShelf': '1'},
            )
            .timeout(const Duration(seconds: 36));
        Map<String, dynamic>? body;
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) body = decoded;
        } catch (_) {}
        if (response.statusCode == 200 &&
            body != null &&
            (body.containsKey('query') ||
                body.containsKey('parse') ||
                body.containsKey('error'))) {
          return response;
        }
        // Older bundled gateways return a 404 or the old web application's HTML.
        // Remember only a missing route, never a temporary network failure.
        if ([404, 405, 501].contains(response.statusCode) ||
            (response.statusCode == 200 && body == null)) {
          _legacyGateway = true;
        }
      } catch (_) {}
    }
    return client
        .get(
          target,
          headers: kIsWeb
              ? {}
              : {'User-Agent': 'Vocalo1ng/0.4.4 (personal music reader)'},
        )
        .timeout(const Duration(seconds: 12));
  }

  final http.Client client;
  final Map<String, List<WikiEntry>> _cache = {};
  final Map<int, WikiDocument> _articles = {};

  Future<List<WikiEntry>> randomEntries(int count) async {
    final response = await get(
      Uri.https('voca.wiki', '/api.php', {
        'action': 'query',
        'list': 'random',
        'rnnamespace': '0',
        'rnlimit': '${count.clamp(5, 8)}',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      }),
    ).timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) throw StateError('百科服务暂时不可用');
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) throw StateError('百科服务繁忙');
    final entries = (body['query']['random'] as List)
        .map((e) => WikiEntry(e['title'] as String, e['id'] as int))
        .toList();
    return Future.wait(
      entries.map((entry) async {
        try {
          final doc = await article(pageId: entry.pageId);
          final images = html_parser
              .parseFragment(doc.html)
              .querySelectorAll('img');
          final candidates = images.where((img) {
            final src = img.attributes['src'] ?? '';
            final original = Uri.tryParse(src)?.queryParameters['url'] ?? src;
            final width = int.tryParse(img.attributes['width'] ?? '') ?? 0;
            final height = int.tryParse(img.attributes['height'] ?? '') ?? 0;
            return !original.toLowerCase().endsWith('.svg') &&
                !(width > 0 && width < 100) &&
                !(height > 0 && height < 70);
          }).toList();
          final cover =
              candidates
                  .where(
                    (img) =>
                        (int.tryParse(img.attributes['width'] ?? '0') ?? 0) >=
                        150,
                  )
                  .firstOrNull ??
              candidates.firstOrNull;
          return WikiEntry(
            entry.title,
            entry.pageId,
            '',
            cover?.attributes['src'] ?? '',
          );
        } catch (_) {
          return entry;
        }
      }),
    );
  }

  Future<WikiDocument> article({int? pageId, String? title}) async {
    if (pageId != null && _articles.containsKey(pageId)) {
      return _articles[pageId]!;
    }
    final response = await get(
      Uri.https('voca.wiki', '/api.php', {
        'action': 'parse',
        if (pageId != null) 'pageid': '$pageId' else 'page': title!,
        'prop': 'text|revid',
        'disableeditsection': '1',
        'disabletoc': '1',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
        'maxlag': '5',
      }),
    ).timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) throw StateError('百科服务暂时不可用');
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) throw StateError('该条目暂时无法读取');
    final parsed = body['parse'] as Map<String, dynamic>;
    final doc = WikiDocument(
      parsed['title'] as String,
      parsed['pageid'] as int,
      sanitizeWikiHtml(parsed['text'] as String),
      parsed['revid'] as int? ?? 0,
    );
    if (_articles.length >= 20) _articles.remove(_articles.keys.first);
    _articles[doc.pageId] = doc;
    return doc;
  }

  Future<List<WikiEntry>> search(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return [];
    if (_cache.containsKey(keyword)) return _cache[keyword]!;
    final response = await get(
      Uri.https('voca.wiki', '/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': keyword,
        'srnamespace': '0',
        'srprop': 'snippet',
        'srlimit': '12',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
        'maxlag': '5',
      }),
    ).timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) throw StateError('百科服务暂时不可用');
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) throw StateError('百科服务繁忙，请稍后再试');
    final entries = (body['query']['search'] as List)
        .map(
          (e) => WikiEntry(
            e['title'] as String,
            e['pageid'] as int,
            (e['snippet'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), ''),
          ),
        )
        .toList();
    if (_cache.length >= 20) _cache.remove(_cache.keys.first);
    _cache[keyword] = entries;
    return entries;
  }

  void dispose() => client.close();
}

class WikiDocument {
  const WikiDocument(this.title, this.pageId, this.html, this.revision);
  final String title, html;
  final int pageId, revision;
  Uri get original => Uri.https('voca.wiki', '/', {'curid': '$pageId'});
  Uri get history => Uri.https('voca.wiki', '/index.php', {
    'title': title,
    'action': 'history',
  });
}

String sanitizeWikiHtml(String input) {
  final document = html_parser.parseFragment(input);
  for (final node in document.querySelectorAll(
    'script, style, iframe, object, embed, form, input, button, link, meta, svg, .mw-editsection, .noprint, .sidebar-character',
  )) {
    node.remove();
  }
  final base = Uri.https('voca.wiki', '/');
  final seenImages = <String>{};
  for (final node in document.querySelectorAll('*')) {
    if (node.localName == 'img') {
      final lazy =
          node.attributes['data-src'] ??
          node.attributes['data-original'] ??
          node.attributes['data-lazy-src'];
      if (lazy != null && lazy.isNotEmpty) node.attributes['src'] = lazy;
    }
    for (final attribute in node.attributes.keys.toList()) {
      if (attribute.toString().toLowerCase().startsWith('on')) {
        node.attributes.remove(attribute);
      }
    }
    for (final attr in ['src', 'href']) {
      final value = node.attributes[attr];
      if (value == null) continue;
      final target = base.resolve(value);
      if (!['http', 'https'].contains(target.scheme) ||
          target.userInfo.isNotEmpty) {
        node.attributes.remove(attr);
      } else {
        node.attributes[attr] =
            attr == 'src' &&
                [
                  'voca.wiki',
                  'nicovideo.cdn.nimg.jp',
                  'tn.smilevideo.jp',
                  'i.pximg.net',
                  'cdn.piapro.jp',
                  'pbs.twimg.com',
                  'upload.wikimedia.org',
                  'static.wikia.nocookie.net',
                ].any(
                  (host) =>
                      target.host == host || target.host.endsWith('.$host'),
                )
            ? gatewayImage(target.toString())
            : target.toString();
      }
    }
    node.attributes.remove('srcset');
    // Keep both image dimensions: deleting only width stretches portraits in tables.
    if (node.localName == 'img') {
      final source = node.attributes['src'];
      if (source != null && !seenImages.add(source)) {
        node.remove();
        continue;
      }
      // Nico thumbnails have no HTML dimensions; without a width the reader
      // expands their low-resolution bitmap across the whole article column.
      final original =
          Uri.tryParse(source ?? '')?.queryParameters['url'] ?? source ?? '';
      if (Uri.tryParse(original)?.host == 'nicovideo.cdn.nimg.jp' &&
          !node.attributes.containsKey('width')) {
        node.attributes['width'] = '320';
      }
      node.attributes['style'] =
          'max-width:100%;height:auto;object-fit:contain';
    } else {
      // Preserve editorial formatting, while dropping layout that escapes the reader.
      final styles = <String, String>{};
      const allowed = {
        'color',
        'background-color',
        'font-family',
        'font-size',
        'font-weight',
        'font-style',
        'text-align',
        'text-decoration',
        'vertical-align',
        'line-height',
        'letter-spacing',
        'border',
        'border-color',
        'border-width',
        'border-style',
        'border-collapse',
        'border-spacing',
        'padding',
        'padding-left',
        'padding-right',
        'padding-top',
        'padding-bottom',
        'margin',
        'margin-left',
        'margin-right',
        'margin-top',
        'margin-bottom',
        'width',
        'max-width',
        'min-width',
      };
      for (final declaration in (node.attributes['style'] ?? '').split(';')) {
        final colon = declaration.indexOf(':');
        if (colon < 1) continue;
        final key = declaration.substring(0, colon).trim().toLowerCase();
        final value = declaration.substring(colon + 1).trim();
        if (key == 'background' &&
            !RegExp(
              r'url\s*\(|expression|javascript',
              caseSensitive: false,
            ).hasMatch(value)) {
          final color = RegExp(
            r'#[0-9a-fA-F]{3,8}\b|rgba?\([\d\s.,%]+\)|\b(?:white|black|transparent)\b',
          ).firstMatch(value)?.group(0);
          if (color != null) styles['background-color'] = color;
        }
        if (value.isNotEmpty &&
            allowed.contains(key) &&
            !RegExp(
              r'url\s*\(|expression|javascript|[<>]',
              caseSensitive: false,
            ).hasMatch(value)) {
          styles[key] = value;
        }
      }
      final align = node.attributes['align'];
      if (['left', 'center', 'right', 'justify'].contains(align)) {
        styles.putIfAbsent('text-align', () => align!);
      }
      if (node.localName == 'center' || node.classes.contains('center')) {
        styles.putIfAbsent('text-align', () => 'center');
      }
      if (node.localName == 'table') {
        styles.putIfAbsent('border-collapse', () => 'collapse');
        styles['max-width'] = '100%';
      }
      if (styles.isNotEmpty) {
        node.attributes['style'] = styles.entries
            .map((e) => '${e.key}:${e.value}')
            .join(';');
      } else {
        node.attributes.remove('style');
      }
    }
  }
  return document.outerHtml;
}
