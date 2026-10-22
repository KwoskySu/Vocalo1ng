import 'dart:convert';
import 'dart:math' as math;

String topId() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
int _nextId = 0;
const topTextParts = {
  'title': '表格大标题',
  'subtitle': '副标题',
  'rank': '名次',
  'item': '条目标题',
  'detail': '条目副标题',
  'reason': '推荐理由',
  'badge': '标签 / 评分',
  'author': '署名',
  'footer': '页脚',
};

String _text(dynamic value, int max, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is! String || value.length > max) {
    throw const FormatException('榜单文字过长或格式错误');
  }
  return value;
}

int _int(dynamic v, int fallback, int min, int max) =>
    v is num && v.isFinite ? v.toInt().clamp(min, max) : fallback;
double _double(dynamic v, double fallback, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;

/// Embedded covers are bounded thumbnails, never original-size photographs.
void validateTopImage(String data, {bool background = false}) {
  final bytes = background ? 1024 * 1024 : 128 * 1024;
  if (data.isNotEmpty &&
      (data.length > bytes * 1.4 || base64Decode(data).length > bytes)) {
    throw const FormatException('封面缩略图超过限制');
  }
}

String _textColor(dynamic value) {
  final color = _text(value, 7);
  return RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(color) ? color : '';
}

class TopTypography {
  TopTypography({
    this.font = 0,
    this.size = 18,
    this.bold = false,
    this.color = '',
    this.italic = false,
    this.underline = false,
    this.tracking = 0,
    this.height = 1.42,
    this.align = -1,
  });
  int font;
  double size;
  bool bold;
  String color;
  bool italic, underline;
  double tracking, height;
  int align;
  Map<String, dynamic> toJson() => {
    'font': font,
    'size': size,
    'bold': bold,
    'color': color,
    'italic': italic,
    'underline': underline,
    'tracking': tracking,
    'height': height,
    'align': align,
  };
  factory TopTypography.fromJson(Map data) => TopTypography(
    font: _int(data['font'], 0, 0, 3),
    size: _double(data['size'], 18, 9, 72),
    bold: data['bold'] == true,
    color: _textColor(data['color']),
    italic: data['italic'] == true,
    underline: data['underline'] == true,
    tracking: _double(data['tracking'], 0, -1, 8),
    height: _double(data['height'], 1.42, 1, 2.4),
    align: _int(data['align'], -1, -1, 2),
  );
}

class TopEntry {
  TopEntry({
    String? id,
    this.title = '',
    this.subtitle = '',
    this.reason = '',
    this.badge = '',
    this.coverUrl = '',
    this.coverData = '',
    this.wikiTitle = '',
    this.pageId = 0,
  }) : id = id ?? topId();
  final String id;
  String title, subtitle, reason, badge, coverUrl, coverData, wikiTitle;
  int pageId;
  int frame = -1;
  final typography = <String, TopTypography>{};
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'reason': reason,
    'badge': badge,
    'coverUrl': coverUrl,
    'coverData': coverData,
    'wikiTitle': wikiTitle,
    'pageId': pageId,
    'frame': frame,
    'typography': typography.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory TopEntry.fromJson(Map data) {
    final image = _text(data['coverData'], 180000);
    validateTopImage(image);
    final entry = TopEntry(
      id: _text(data['id'], 100, topId()),
      title: _text(data['title'], 300),
      subtitle: _text(data['subtitle'], 500),
      reason: _text(data['reason'], 3000),
      badge: _text(data['badge'], 80),
      coverUrl: _text(data['coverUrl'], 3000),
      coverData: image,
      wikiTitle: _text(data['wikiTitle'], 300),
      pageId: _int(data['pageId'], 0, 0, 2147483647),
    );
    entry.frame = _int(data['frame'], -1, -1, 10);
    final types = data['typography'];
    if (types is Map) {
      for (final key in ['rank', 'item', 'detail', 'reason', 'badge']) {
        if (types[key] is Map)
          entry.typography[key] = TopTypography.fromJson(types[key]);
      }
    }
    return entry;
  }
  TopEntry copy({bool newId = false}) =>
      TopEntry.fromJson({...toJson(), if (newId) 'id': topId()});
}

class TopChart {
  TopChart({String? id}) : id = id ?? topId();
  final String id;
  String title = '',
      subtitle = '',
      author = '',
      footer = '',
      backgroundData = '',
      backgroundUrl = '',
      customColor = '';
  int limit = 10,
      perPage = 10,
      style = 0,
      palette = 0,
      columns = 0,
      format = 0,
      coverShape = 0,
      align = 0;
  int frame = 0;
  bool coverBackdrop = false, showDivider = false;
  double backdropBlur = 6,
      backdropZoom = 1.5,
      backdropOpacity = .38,
      glassOpacity = .18,
      borderWidth = 1.2,
      cardPadding = 18;
  double gap = 14, radius = 16, backgroundOpacity = .24, outerPadding = 32;
  bool showCover = true,
      showReason = true,
      showRank = true,
      coverContain = false;
  final entries = <TopEntry>[];
  final typography = <String, TopTypography>{
    'title': TopTypography(font: 1, size: 34, bold: true),
    'subtitle': TopTypography(size: 12),
    'rank': TopTypography(font: 3, size: 28, bold: true),
    'item': TopTypography(size: 19, bold: true),
    'detail': TopTypography(size: 12),
    'reason': TopTypography(size: 13),
    'badge': TopTypography(size: 11, bold: true),
    'footer': TopTypography(size: 11),
    'author': TopTypography(size: 11),
  };
  List<TopEntry> get visible => entries.take(limit).toList();
  int get pageCount => math.max(1, (visible.length / perPage).ceil());
  List<TopEntry> page(int index) =>
      visible.skip(index * perPage).take(perPage).toList();
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'author': author,
    'footer': footer,
    'limit': limit,
    'perPage': perPage,
    'style': style,
    'palette': palette,
    'columns': columns,
    'format': format,
    'coverShape': coverShape,
    'align': align,
    'outerPadding': outerPadding,
    'gap': gap,
    'radius': radius,
    'backgroundData': backgroundData,
    'backgroundUrl': backgroundUrl,
    'customColor': customColor,
    'backgroundOpacity': backgroundOpacity,
    'showCover': showCover,
    'showReason': showReason,
    'showRank': showRank,
    'coverContain': coverContain,
    'canvasVersion': 2,
    'frame': frame,
    'coverBackdrop': coverBackdrop,
    'showDivider': showDivider,
    'backdropBlur': backdropBlur,
    'backdropZoom': backdropZoom,
    'backdropOpacity': backdropOpacity,
    'glassOpacity': glassOpacity,
    'borderWidth': borderWidth,
    'cardPadding': cardPadding,
    'typography': typography.map((k, v) => MapEntry(k, v.toJson())),
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory TopChart.fromJson(Map data) {
    final c = TopChart(id: _text(data['id'], 100, topId()));
    c.title = _text(data['title'], 300, c.title);
    c.subtitle = _text(data['subtitle'], 500);
    c.author = _text(data['author'], 200);
    c.footer = _text(data['footer'], 1000);
    if (data['canvasVersion'] != 2) {
      if (c.title == '那些值得反复播放的歌') c.title = '';
      if (c.subtitle == 'MY VOCALOID SELECTION') c.subtitle = '';
      if (c.footer == '每一份喜欢，都值得被记录。') c.footer = '';
    }
    c.limit = _int(data['limit'], 10, 1, 100);
    c.perPage = _int(data['perPage'], 10, 1, 20);
    c.style = _int(data['style'], 0, 0, 17);
    c.palette = _int(data['palette'], 0, 0, 7);
    c.columns = _int(data['columns'], 0, 0, 4);
    c.format = _int(data['format'], 0, 0, 3);
    c.outerPadding = _double(data['outerPadding'], 32, 8, 64);
    c.coverShape = _int(data['coverShape'], 0, 0, 2);
    c.align = _int(data['align'], 0, 0, 2);
    c.frame = _int(data['frame'], 0, 0, 10);
    c.coverBackdrop = data['coverBackdrop'] == true;
    c.showDivider = data['showDivider'] == true;
    c.backdropBlur = _double(data['backdropBlur'], 6, 0, 12);
    c.backdropZoom = _double(data['backdropZoom'], 1.5, 1, 3);
    c.backdropOpacity = _double(data['backdropOpacity'], .38, 0, 1);
    c.glassOpacity = _double(data['glassOpacity'], .18, .05, .9);
    c.borderWidth = _double(data['borderWidth'], 1.2, .5, 5);
    c.cardPadding = _double(data['cardPadding'], 18, 6, 32);
    c.gap = _double(data['gap'], 14, 4, 32);
    c.radius = _double(data['radius'], 16, 0, 32);
    c.backgroundOpacity = _double(data['backgroundOpacity'], .24, 0, .8);
    c.backgroundData = _text(data['backgroundData'], 1400000);
    validateTopImage(c.backgroundData, background: true);
    c.backgroundUrl = _text(data['backgroundUrl'], 3000);
    c.customColor = _text(data['customColor'], 7);
    c.showCover = data['showCover'] != false;
    c.showReason = data['showReason'] != false;
    c.showRank = data['showRank'] != false;
    c.coverContain = data['coverContain'] == true;
    final types = data['typography'];
    if (types is Map)
      for (final key in topTextParts.keys) {
        if (types[key] is Map) {
          c.typography[key] = TopTypography.fromJson(types[key]);
        }
      }
    if (types is Map && types['author'] == null && types['footer'] is Map) {
      c.typography['author'] = TopTypography.fromJson(types['footer']);
    }
    final rows = data['entries'] ?? [];
    if (rows is! List || rows.length > 100) {
      throw const FormatException('每份榜单最多100个条目');
    }
    c.entries.addAll(rows.map((r) => TopEntry.fromJson(r as Map)));
    if (c.entries.map((e) => e.id).toSet().length != c.entries.length) {
      throw const FormatException('条目ID重复');
    }
    return c;
  }
  TopChart copy({bool newId = false}) =>
      TopChart.fromJson({...toJson(), if (newId) 'id': topId()});
}

List<TopChart> decodeTopCharts(String raw) {
  if (utf8.encode(raw).length > 8 * 1024 * 1024) {
    throw const FormatException('榜单数据超过8MB，请减少自选图片');
  }
  final data = jsonDecode(raw);
  if (data is! Map ||
      data['version'] != 1 ||
      data['charts'] is! List ||
      (data['charts'] as List).length > 30) {
    throw const FormatException('不是受支持的TOP榜单文件');
  }
  final result = (data['charts'] as List)
      .map((e) => TopChart.fromJson(e as Map))
      .toList();
  if (result.map((c) => c.id).toSet().length != result.length) {
    throw const FormatException('榜单ID重复');
  }
  return result;
}

String encodeTopCharts(List<TopChart> charts) => jsonEncode({
  'version': 1,
  'charts': charts.map((c) => c.toJson()).toList(),
});
