enum Source { wiki, netease, bilibili }

class Sources {
  static Uri search(Source source, String query) => switch (source) {
    Source.wiki => Uri.https('voca.wiki', '/Special:Search', {'search': query}),
    Source.netease => Uri.parse(
      'https://music.163.com/#/search/m/?s=${Uri.encodeComponent(query)}&type=1',
    ),
    Source.bilibili => Uri.https('search.bilibili.com', '/all', {
      'keyword': query,
    }),
  };

  /// Accept only canonical song/video links, not arbitrary URLs or redirectors.
  static Uri? parseLink(Source source, String value) {
    final input = value.trim();
    if (input.isEmpty) return null;
    if (source == Source.netease && RegExp(r'^\d+$').hasMatch(input)) {
      return Uri.parse('https://music.163.com/song?id=$input');
    }
    if (source == Source.bilibili &&
        RegExp(r'^BV[0-9A-Za-z]{10}$').hasMatch(input)) {
      return Uri.https('www.bilibili.com', '/video/$input');
    }
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    if (source == Source.netease && uri.host == 'music.163.com') {
      final route = uri.fragment.isNotEmpty ? Uri.tryParse(uri.fragment) : uri;
      if (route != null &&
          const ['/song', '/m/song'].contains(route.path) &&
          RegExp(r'^\d+$').hasMatch(route.queryParameters['id'] ?? '')) {
        return uri;
      }
    }
    if (source == Source.bilibili &&
        const [
          'www.bilibili.com',
          'bilibili.com',
          'm.bilibili.com',
        ].contains(uri.host) &&
        RegExp(r'^/video/BV[0-9A-Za-z]{10}/?$').hasMatch(uri.path)) {
      return uri;
    }
    return null;
  }
}
