import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/music.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_wiki.dart';

String? nativeGatewayOverride;
String gatewayBase() {
  const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  return configured.isNotEmpty
      ? configured
      : kIsWeb
      ? Uri.base.origin
      : nativeGatewayOverride ?? 'http://127.0.0.1:5418';
}

String gatewayImage(String source) => Uri.parse(
  gatewayBase(),
).resolve('/api/image').replace(queryParameters: {'url': source}).toString();

class MusicApiException implements Exception {
  const MusicApiException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class MusicService extends ChangeNotifier {
  MusicService({http.Client? client, String? base})
    : client = client ?? http.Client(),
      base =
          base ??
          const String.fromEnvironment('API_BASE_URL', defaultValue: '') {
    if (this.base.isEmpty) this.base = gatewayBase();
  }
  final http.Client client;
  String base;
  String? _session;
  Future<void>? _sessionReady;
  Future<void>? _firstSessionRequest;
  Future<void> _loadSavedSession() async {
    try {
      _session = (await SharedPreferences.getInstance()).getString(
        'session:$base',
      );
    } catch (_) {}
  }

  Map<String, dynamic>? profile;
  Map<String, dynamic>? bilibiliProfile;
  Map<String, dynamic>? qqProfile;
  String audioProvider = 'netease';
  List<MusicTrack> lastTracks = [];
  final songWiki = SongWikiLookup();
  String get audioLabel => audioProvider == 'qq' ? 'QQ 音乐' : '网易云';
  bool get audioLoggedIn =>
      audioProvider == 'qq' ? qqProfile != null : loggedIn;
  Future<void> selectAudioProvider(String provider) async {
    audioProvider = provider == 'qq' ? 'qq' : 'netease';
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        'audioProvider',
        audioProvider,
      );
    } catch (_) {}
  }

  bool get loggedIn => profile != null;
  bool get bilibiliLoggedIn => bilibiliProfile != null;
  Map<String, String> get nativeHeaders =>
      !kIsWeb && _session != null ? {'X-VocaShelf-Session': _session!} : {};

  Uri uri(String path, [Map<String, String>? params]) =>
      Uri.parse(base).resolve(path).replace(queryParameters: params);
  String image(String source) =>
      source.isEmpty ? '' : uri('/api/image', {'url': source}).toString();

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, String>? params,
    Map<String, dynamic>? body,
  }) async {
    if (!kIsWeb) await (_sessionReady ??= _loadSavedSession());
    // The browser also needs its first Set-Cookie before concurrent startup
    // requests; otherwise slow anonymous responses can replace a login cookie.
    if (_firstSessionRequest == null) {
      final ready = Completer<void>();
      _firstSessionRequest = ready.future;
      try {
        return await _request(path, params: params, body: body);
      } finally {
        ready.complete();
      }
    }
    await _firstSessionRequest;
    return _request(path, params: params, body: body);
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, String>? params,
    Map<String, dynamic>? body,
  }) async {
    try {
      final sentSession = _session;
      final headers = {
        'X-VocaShelf': '1',
        if (!kIsWeb) 'X-VocaShelf-Native': '1',
        ...nativeHeaders,
        if (body != null) 'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? client.get(uri(path, params), headers: headers)
                  : client.post(
                      uri(path, params),
                      headers: headers,
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 40));
      if (!kIsWeb &&
          response.headers['x-vocashelf-session'] != null &&
          (_session == null || sentSession == _session)) {
        _session = response.headers['x-vocashelf-session'];
        try {
          await (await SharedPreferences.getInstance()).setString(
            'session:$base',
            _session!,
          );
        } catch (_) {}
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw MusicApiException(
          data['error'] as String? ?? '请求失败，请稍后重试',
          response.statusCode,
        );
      }
      return data;
    } on MusicApiException {
      rethrow;
    } catch (_) {
      throw const MusicApiException('音乐服务暂时无响应，请刷新重试；如仍失败，请在偏好与数据中检查运行方式。');
    }
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!kIsWeb) await (_sessionReady ??= _loadSavedSession());
      audioProvider = prefs.getString('audioProvider') ?? 'netease';
      final data = await request('/api/session');
      profile = data['profile'] as Map<String, dynamic>?;
      bilibiliProfile = data['bilibili'] as Map<String, dynamic>?;
      qqProfile = data['qq'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {
      /* discover view shows actionable connection error */
    }
  }

  Future<String> startLogin() async =>
      (await request('/api/login/qr', body: {}))['url'] as String;
  Future<int> checkLogin() async {
    final data = await request('/api/login/check');
    if (data['code'] == 803) {
      profile = data['profile'] as Map<String, dynamic>;
      notifyListeners();
    }
    return data['code'] as int;
  }

  Future<void> logout() async {
    await request('/api/logout', body: {});
    profile = null;
    notifyListeners();
  }

  Future<String> startBilibiliLogin() async =>
      (await request('/api/bilibili/login/qr', body: {}))['url'] as String;
  Future<int> checkBilibiliLogin() async {
    final data = await request('/api/bilibili/login/check');
    if (data['code'] == 0) {
      bilibiliProfile = data['profile'] as Map<String, dynamic>;
      notifyListeners();
    }
    return data['code'] as int;
  }

  Future<void> refreshBilibiliProfile() async {
    bilibiliProfile =
        (await request('/api/bilibili/profile'))['profile']
            as Map<String, dynamic>?;
    notifyListeners();
  }

  Future<void> logoutBilibili() async {
    await request('/api/bilibili/logout', body: {});
    bilibiliProfile = null;
    notifyListeners();
  }

  Future<({List<MusicTrack> songs, List<MusicPlaylist> playlists, String kind})>
  discover() async {
    if (audioProvider == 'qq') {
      final result = await search('初音未来 VOCALOID');
      return (songs: result.songs, playlists: <MusicPlaylist>[], kind: 'qq');
    }
    final data = await request('/api/music/discover');
    return (
      songs: _tracks(data),
      playlists: (data['playlists'] as List)
          .map((e) => MusicPlaylist.fromJson(e))
          .toList(),
      kind: data['kind'] as String,
    );
  }

  Future<({List<MusicTrack> songs, int total})> search(
    String query, {
    int offset = 0,
  }) async {
    final data = await request(
      audioProvider == 'qq' ? '/api/qq/search' : '/api/music/search',
      params: {'q': query, 'offset': '$offset'},
    );
    return (songs: _tracks(data), total: data['total'] as int);
  }

  List<MusicTrack> _tracks(Map<String, dynamic> data) {
    final result = (data['songs'] as List)
        .map((e) => MusicTrack.fromJson(e))
        .toList();
    if (result.isNotEmpty) {
      lastTracks = result;
      notifyListeners();
    }
    return result;
  }

  Future<({String url, bool preview})> stream(
    String id, {
    String quality = 'standard',
  }) async {
    final qq = id.startsWith('qq:');
    final data = await request(
      qq ? '/api/qq/url' : '/api/music/url',
      params: {'id': qq ? id.substring(3) : id, 'quality': quality},
    );
    return (
      url: Uri.parse(base).resolve(data['path'] as String).toString(),
      preview: data['preview'] as bool,
    );
  }

  Future<({String original, String translated})> lyrics(String id) async {
    final qq = id.startsWith('qq:');
    final data = await request(
      qq ? '/api/qq/lyrics' : '/api/music/lyrics',
      params: {'id': qq ? id.substring(3) : id},
    );
    return (
      original: data['original'] as String,
      translated: data['translated'] as String,
    );
  }

  Future<List<MusicPlaylist>> playlists() async =>
      ((await request('/api/playlists'))['playlists'] as List)
          .map((e) => MusicPlaylist.fromJson(e))
          .toList();
  Future<List<MusicTrack>> playlist(String id, {int offset = 0}) async =>
      _tracks(
        await request('/api/playlist', params: {'id': id, 'offset': '$offset'}),
      );
  Future<MusicPlaylist> createPlaylist(
    String name, {
    bool private = true,
  }) async => MusicPlaylist.fromJson(
    (await request(
      '/api/playlists',
      body: {'name': name, 'private': private},
    ))['playlist'],
  );
  Future<void> addToPlaylist(String playlist, String song) async {
    await request(
      '/api/playlist/tracks',
      body: {'playlist': playlist, 'song': song},
    );
  }

  Future<List<MusicTrack>> roam(List<String> previous) async => _tracks(
    await request(
      '/api/music/roam',
      params: {'provider': audioProvider, 'previous': previous.join(',')},
    ),
  );
  Future<String> startQQLogin() async =>
      (await request('/api/qq/login/qr', body: {}))['image'] as String;
  Future<String> checkQQLogin() async {
    final data = await request('/api/qq/login/check');
    if (data['code'] == 'DONE') {
      qqProfile = data['profile'] as Map<String, dynamic>;
      notifyListeners();
    }
    return data['code'] as String;
  }

  Future<void> logoutQQ() async {
    await request('/api/qq/logout', body: {});
    qqProfile = null;
    notifyListeners();
  }

  Future<List<PvVideo>> pvs(
    String title,
    String artist, {
    String order = 'click',
    bool refresh = false,
  }) async =>
      ((await request(
                '/api/pv/search',
                params: {
                  'title': title,
                  'artist': artist,
                  'order': order,
                  if (refresh) 'refresh': '1',
                },
              ))['videos']
              as List)
          .map((e) => PvVideo.fromJson(e))
          .toList();
  @override
  void dispose() {
    songWiki.dispose();
    client.close();
    super.dispose();
  }
}
