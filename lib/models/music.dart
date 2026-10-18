class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.cover = '',
    this.alias = '',
    this.duration = 0,
  });
  final String id, title, artist, album, cover, alias;
  final int duration;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'cover': cover,
    'alias': alias,
    'duration': duration,
  };
  bool get isQQ => id.startsWith('qq:');
  String get platform => isQQ ? 'QQ 音乐' : '网易云';
  static const _voices = <String, String>{
    '初音ミク': '初音未来',
    '初音未来': '初音未来',
    '鏡音リン': '镜音铃',
    '镜音铃': '镜音铃',
    '鏡音レン': '镜音连',
    '镜音连': '镜音连',
    '巡音ルカ': '巡音流歌',
    'GUMI': 'GUMI',
    'KAITO': 'KAITO',
    'MEIKO': 'MEIKO',
    '可不': '可不',
    '重音テト': '重音 Teto',
    '重音Teto': '重音 Teto',
    '洛天依': '洛天依',
    'IA': 'IA',
    'flower': 'flower',
  };
  String get voice => artist
      .split(' / ')
      .where(_voices.containsKey)
      .map((name) => _voices[name]!)
      .toSet()
      .join(' / ');
  String get producer {
    final names = artist
        .split(' / ')
        .where((name) => !_voices.containsKey(name))
        .toList();
    return names.isEmpty ? artist : names.join(' / ');
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
    alias: json['alias'] as String? ?? '',
    duration: json['duration'] as int? ?? 0,
  );
}

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.title,
    this.cover = '',
    this.count = 0,
    this.own = false,
    this.private = false,
    this.creator = '',
  });
  final String id, title, cover, creator;
  final int count;
  final bool own, private;
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    title: json['title'] as String,
    cover: json['cover'] as String? ?? '',
    count: json['count'] as int? ?? 0,
    own: json['own'] as bool? ?? false,
    private: json['private'] as bool? ?? false,
    creator: json['creator'] as String? ?? '',
  );
}

class PvVideo {
  const PvVideo({
    required this.bvid,
    required this.title,
    this.author = '',
    this.duration = '',
    this.plays = 0,
    this.cover = '',
  });
  final String bvid, title, author, duration, cover;
  final int plays;
  factory PvVideo.fromJson(Map<String, dynamic> json) => PvVideo(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    author: json['author'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    plays: (json['plays'] as num?)?.toInt() ?? 0,
    cover: json['cover'] as String? ?? '',
  );
}
