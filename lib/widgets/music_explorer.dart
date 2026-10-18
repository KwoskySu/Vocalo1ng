import 'phone_theme.dart';
import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/music.dart';
import '../services/playback.dart';
import 'cloud_playlists.dart';
import 'pv_browser.dart';
import 'track_lyrics.dart';
import 'roam_panel.dart';
import 'song_wiki_button.dart';
import 'accounts.dart';
import 'collections.dart';

class MusicExplorer extends StatefulWidget {
  const MusicExplorer({
    super.key,
    required this.music,
    required this.playback,
    required this.onJournal,
  });
  final MusicService music;
  final Playback? playback;
  final void Function(MusicTrack track, {String lyrics, bool share}) onJournal;
  @override
  State<MusicExplorer> createState() => _MusicExplorerState();
}

class _MusicExplorerState extends State<MusicExplorer> {
  final input = TextEditingController();
  List<MusicTrack> songs = [];
  List<MusicPlaylist> recommended = [], cloud = [];
  String? error, playlistTitle;
  MusicPlaylist? activePlaylist;
  Future<void> refresh() async {
    if (mode == 'search') {
      input.text = searched;
      await search();
    } else if (mode == 'playlist' && activePlaylist != null) {
      await openPlaylist(activePlaylist!);
    } else if (mode == 'cloud') {
      await loadCloud();
    } else {
      await discover();
    }
  }

  String mode = 'discover', kind = 'vocaloid', searched = '';
  bool loading = true, moreLoading = false, hasMore = false;
  int generation = 0;
  String? musicUid;
  @override
  void initState() {
    super.initState();
    musicUid =
        '${widget.music.audioProvider}:${widget.music.profile?['uid']}:${widget.music.qqProfile?['uid']}';
    widget.music.addListener(sessionChanged);
    discover();
  }

  @override
  void dispose() {
    generation++;
    widget.music.removeListener(sessionChanged);
    input.dispose();
    super.dispose();
  }

  void sessionChanged() {
    final nextUid =
        '${widget.music.audioProvider}:${widget.music.profile?['uid']}:${widget.music.qqProfile?['uid']}';
    if (nextUid == musicUid) return;
    final providerChanged =
        musicUid?.split(':').first != nextUid.split(':').first;
    musicUid = nextUid;
    if (mounted) {
      if (providerChanged) {
        discover();
        return;
      }
      if (mode == 'cloud') {
        loadCloud();
      } else if (mode == 'discover') {
        discover();
      }
    }
  }

  Future<void> discover() async {
    final request = ++generation;
    setState(() {
      mode = 'discover';
      loading = true;
      error = null;
      playlistTitle = null;
      input.clear();
    });
    try {
      final data = await widget.music.discover();
      if (mounted && generation == request) {
        setState(() {
          songs = data.songs;
          recommended = data.playlists;
          kind = data.kind;
          hasMore = false;
        });
      }
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  Future<void> search({bool more = false}) async {
    final query = input.text.trim();
    if (query.isEmpty) return discover();
    if (more && (loading || moreLoading)) return;
    final request = ++generation;
    setState(() {
      mode = 'search';
      error = null;
      playlistTitle = null;
      searched = query;
      if (more) {
        moreLoading = true;
      } else {
        loading = true;
        songs = [];
      }
    });
    try {
      final data = await widget.music.search(
        query,
        offset: more ? songs.length : 0,
      );
      if (mounted && generation == request) {
        setState(() {
          songs = more ? [...songs, ...data.songs] : data.songs;
          hasMore = data.songs.isNotEmpty && songs.length < data.total;
        });
      }
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) {
        setState(() {
          loading = false;
          moreLoading = false;
        });
      }
    }
  }

  Future<void> loadCloud() async {
    final request = ++generation;
    setState(() {
      mode = 'cloud';
      loading = true;
      error = null;
    });
    if (!widget.music.loggedIn) {
      setState(() => loading = false);
      return;
    }
    try {
      final data = await widget.music.playlists();
      if (mounted && generation == request) setState(() => cloud = data);
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  Future<void> openPlaylist(MusicPlaylist list) async {
    final request = ++generation;
    setState(() {
      mode = 'playlist';
      activePlaylist = list;
      playlistTitle = list.title;
      loading = true;
      error = null;
    });
    try {
      final data = await widget.music.playlist(list.id);
      if (mounted && generation == request) {
        setState(() {
          songs = data;
          hasMore = false;
        });
      }
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  Widget image(String url, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: url.isEmpty
          ? const ColoredBox(
              color: Color(0xFFE0EADF),
              child: Icon(Icons.music_note, color: Color(0xFF287C65)),
            )
          : Image.network(
              widget.music.image(url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE0EADF),
                child: Icon(Icons.music_note),
              ),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      isPhoneLayout(context) ? 12 : 24,
      4,
      isPhoneLayout(context) ? 12 : 24,
      16,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  hintText: '直接搜歌、P 主或专辑…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: '搜索${widget.music.audioLabel}',
                    onPressed: () => search(),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: loading ? '重新请求当前结果' : '刷新当前结果',
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Offstage(
          offstage: mode != 'discover',
          child: RoamPanel(music: widget.music, playback: widget.playback),
        ),
        if (mode == 'discover')
          SizedBox(height: isPhoneLayout(context) ? 10 : 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('网易云音乐'),
              selected: widget.music.audioProvider == 'netease',
              onSelected: (_) => widget.music.selectAudioProvider('netease'),
            ),
            ChoiceChip(
              label: const Text('QQ 音乐'),
              selected: widget.music.audioProvider == 'qq',
              onSelected: (_) => widget.music.selectAudioProvider('qq'),
            ),
            if (isPhoneLayout(context))
              IconButton(
                tooltip: '管理音频账号',
                onPressed: () => showAccounts(context, widget.music),
                icon: const Icon(Icons.headphones, size: 20),
              )
            else
              TextButton.icon(
                onPressed: () => showAccounts(context, widget.music),
                icon: const Icon(Icons.headphones, size: 18),
                label: const Text('管理音频账号'),
              ),
          ],
        ),
        SizedBox(height: isPhoneLayout(context) ? 8 : 30),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('在线推荐'),
              selected: mode == 'discover',
              onSelected: (_) => discover(),
            ),
            if (widget.music.audioProvider == 'netease')
              ChoiceChip(
                label: const Text('我的网易云歌单'),
                selected: mode == 'cloud',
                onSelected: (_) => loadCloud(),
              ),
            if (mode == 'cloud' && widget.music.loggedIn)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('新建歌单'),
                onPressed: () async {
                  if (await createCloudPlaylist(context, widget.music) !=
                      null) {
                    loadCloud();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null)
          Container(
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!, style: const TextStyle(fontSize: 12, height: 1.8)),
                TextButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        if (!loading && error == null && mode == 'cloud') ...[
          if (!widget.music.loggedIn)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: FilledButton(
                  onPressed: () => showAccounts(context, widget.music),
                  child: const Text('登录后查看和创建歌单'),
                ),
              ),
            )
          else ...[
            const Text(
              '你创建与收藏的歌单',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _playlists(cloud),
            if (cloud.isEmpty) const Text('还没有歌单，点击上方“新建歌单”。'),
          ],
        ],
        if (!loading && error == null && mode != 'cloud') ...[
          if (mode == 'discover' && recommended.isNotEmpty) ...[
            Text(
              '网易云 · 术力口主题歌单',
              style: TextStyle(
                fontSize: isPhoneLayout(context) ? 16 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _playlists(recommended),
            const SizedBox(height: 26),
          ],
          Text(
            mode == 'search'
                ? '“$searched”的搜索结果'
                : mode == 'playlist'
                ? playlistTitle!
                : kind == 'qq'
                ? 'QQ 音乐 · 术曲精选'
                : kind == 'daily'
                ? '网易云每日推荐 · 依照你的听歌偏好'
                : '从热门术曲歌单开始听',
            style: TextStyle(
              fontSize: isPhoneLayout(context) ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (mode == 'playlist')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '当前载入前 50 首歌曲',
                style: TextStyle(fontSize: 11, color: Color(0xFF74847C)),
              ),
            ),
          const SizedBox(height: 8),
          if (songs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text('暂时没有歌曲，试试其他关键词。'),
            ),
          for (final (index, song) in songs.indexed) _track(song, index),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: moreLoading ? null : () => search(more: true),
                child: Text(moreLoading ? '正在加载…' : '加载更多歌曲'),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _playlists(List<MusicPlaylist> lists) => LayoutBuilder(
    builder: (context, box) {
      final count = box.maxWidth >= 750
          ? 4
          : isPhoneLayout(context) && box.maxWidth >= 320
          ? 3
          : 2;
      final width = (box.maxWidth - (count - 1) * 10) / count;
      return Wrap(
        spacing: 10,
        runSpacing: 16,
        children: [
          for (final list in lists)
            SizedBox(
              width: width,
              child: InkWell(
                onTap: () => openPlaylist(list),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: image(list.cover, width),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      list.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${list.count} 首${list.own ? ' · 我创建的' : ''}${list.private ? ' · 私密' : ''}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF74847C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _track(MusicTrack track, int index) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        horizontalTitleGap: isPhoneLayout(context) ? 10 : 16,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isPhoneLayout(context) ? 10 : 12,
          vertical: isPhoneLayout(context) ? 2 : 5,
        ),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            image(track.cover, isPhoneLayout(context) ? 40 : 48),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isPhoneLayout(context)
              ? '${track.artist}${track.album.isEmpty ? '' : ' · ${track.album}'}'
              : '${track.artist}\n${track.album}',
          maxLines: isPhoneLayout(context) ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            height: 1.7,
            color: Color(0xFF74847C),
          ),
        ),
        onTap: () => widget.playback?.play(track, tracks: songs),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SongWikiButton(music: widget.music, track: track, compact: true),
            if (MediaQuery.sizeOf(context).width >= 600)
              IconButton(
                tooltip: '直接观看 PV',
                icon: const Icon(Icons.smart_display_outlined, size: 21),
                onPressed: () async {
                  await widget.playback?.player.pause();
                  if (mounted) {
                    await showPvs(
                      context,
                      widget.music,
                      track.title,
                      track.artist,
                    );
                  }
                },
              ),
            PopupMenuButton<String>(
              tooltip: '歌曲操作',
              onSelected: (value) async {
                switch (value) {
                  case 'pv':
                    await widget.playback?.player.pause();
                    if (mounted) {
                      await showPvs(
                        context,
                        widget.music,
                        track.title,
                        track.artist,
                      );
                    }
                  case 'playlist':
                    if (track.isQQ) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QQ 音乐歌曲可保存到私人手记；当前云端歌单功能属于网易云。'),
                          ),
                        );
                      }
                      break;
                    }
                    await addTrackToPlaylist(context, widget.music, track);
                  case 'journal':
                    widget.onJournal(track, lyrics: '', share: false);
                  case 'collect':
                    await chooseFolders(context, track);
                  case 'lyrics':
                    await showDialog<void>(
                      context: context,
                      builder: (_) => TrackLyrics(
                        music: widget.music,
                        track: track,
                        playback: widget.playback,
                        onShare: (lyrics) => widget.onJournal(
                          track,
                          lyrics: lyrics,
                          share: true,
                        ),
                      ),
                    );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pv', child: Text('观看 PV · 多个版本')),
                PopupMenuItem(value: 'lyrics', child: Text('歌词 / 歌词分享卡')),
                PopupMenuItem(value: 'playlist', child: Text('加入网易云歌单')),
                PopupMenuItem(value: 'collect', child: Text('收藏到收藏夹')),
                PopupMenuItem(value: 'journal', child: Text('听后感 / 分享手记')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
