import 'dart:convert';

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.voice,
    required this.alias,
    required this.tags,
    required this.color,
    this.favorite = false,
    this.review = '',
    this.lyrics = '',
    this.lyricCredit = '',
    this.rating = 0,
    this.netease = '',
    this.bilibili = '',
    this.cover = '',
    this.coverUrl = '',
  });

  final String id, title, artist, voice, alias;
  final List<String> tags;
  final int color;
  final bool favorite;
  final String review, lyrics, lyricCredit, netease, bilibili, cover, coverUrl;
  final int rating;

  bool matches(String query) => '$title $artist $voice $alias ${tags.join(' ')}'
      .toLowerCase()
      .contains(query.trim().toLowerCase());

  Song copyWith({
    bool? favorite,
    String? review,
    String? lyrics,
    String? lyricCredit,
    int? rating,
    String? netease,
    String? bilibili,
    String? cover,
    String? coverUrl,
  }) => Song(
    id: id,
    title: title,
    artist: artist,
    voice: voice,
    alias: alias,
    tags: tags,
    color: color,
    favorite: favorite ?? this.favorite,
    review: review ?? this.review,
    lyrics: lyrics ?? this.lyrics,
    lyricCredit: lyricCredit ?? this.lyricCredit,
    rating: rating ?? this.rating,
    netease: netease ?? this.netease,
    bilibili: bilibili ?? this.bilibili,
    cover: cover ?? this.cover,
    coverUrl: coverUrl ?? this.coverUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'voice': voice,
    'alias': alias,
    'tags': tags,
    'color': color,
    'favorite': favorite,
    'review': review,
    'lyrics': lyrics,
    'lyricCredit': lyricCredit,
    'rating': rating,
    'netease': netease,
    'bilibili': bilibili,
    'cover': cover,
    'coverUrl': coverUrl,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    voice: json['voice'] as String,
    alias: json['alias'] as String? ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    color: json['color'] as int,
    favorite: json['favorite'] as bool? ?? false,
    review: json['review'] as String? ?? '',
    lyrics: json['lyrics'] as String? ?? '',
    lyricCredit: json['lyricCredit'] as String? ?? '',
    rating: ((json['rating'] as int?) ?? 0).clamp(0, 5),
    netease: json['netease'] as String? ?? '',
    bilibili: json['bilibili'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
    coverUrl: json['coverUrl'] as String? ?? '',
  );

  static String encode(List<Song> songs) =>
      jsonEncode(songs.map((s) => s.toJson()).toList());
}

const seedSongs = <Song>[
  Song(
    id: 'world-is-mine',
    title: 'ワールドイズマイン',
    artist: 'ryo (supercell)',
    voice: '初音未来',
    alias: 'World is Mine 世界第一的公主殿下',
    tags: ['经典入门', '流行'],
    color: 0xFF2B8C7D,
  ),
  Song(
    id: 'rolling-girl',
    title: 'ローリンガール',
    artist: 'wowaka',
    voice: '初音未来',
    alias: 'Rolling Girl 自转少女',
    tags: ['摇滚', '经典入门'],
    color: 0xFF596C9C,
  ),
  Song(
    id: 'meltdown',
    title: '炉心融解',
    artist: 'iroha(sasaki)',
    voice: '镜音铃',
    alias: 'Meltdown',
    tags: ['电子', '经典入门'],
    color: 0xFFC4863D,
  ),
  Song(
    id: 'lost-one',
    title: 'ロストワンの号哭',
    artist: 'Neru',
    voice: '镜音铃',
    alias: 'Lost One’s Weeping',
    tags: ['摇滚'],
    color: 0xFF748657,
  ),
  Song(
    id: 'vampire',
    title: 'ヴァンパイア',
    artist: 'DECO*27',
    voice: '初音未来',
    alias: 'The Vampire 吸血鬼',
    tags: ['流行'],
    color: 0xFFAD6E88,
  ),
  Song(
    id: 'phony',
    title: 'フォニイ',
    artist: 'ツミキ',
    voice: '可不',
    alias: 'phony 伪物',
    tags: ['CeVIO', '流行'],
    color: 0xFF9471A3,
  ),
];
