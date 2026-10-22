import 'widgets/adaptive_dialog.dart';
import 'widgets/phone_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/song.dart';
import 'models/music.dart';
import 'services/export.dart';
import 'services/library.dart';
import 'services/music.dart';
import 'services/playback.dart';
import 'widgets/audio_bar.dart';
import 'widgets/playback_panels.dart';
import 'widgets/cover_art.dart';
import 'widgets/song_detail.dart';
import 'widgets/wiki_explorer.dart';
import 'widgets/music_explorer.dart';
import 'widgets/share_card.dart';
import 'widgets/accounts.dart';
import 'services/song_theme.dart';
import 'widgets/account_avatar.dart';
import 'widgets/theme_settings.dart';
import 'widgets/about.dart';
import 'services/app_info.dart';
import 'services/collections.dart';
import 'widgets/collections.dart';
import 'widgets/birthday_calendar.dart';
import 'widgets/comments.dart';
import 'widgets/brand_mark.dart';
import 'widgets/now_playing.dart';
import 'services/theme_art.dart';
import 'widgets/theme_art_view.dart';
import 'widgets/gateway_settings.dart';
import 'widgets/journal_workspace.dart';
import 'services/bar_preferences.dart';
import 'widgets/data_transfer.dart';
import 'widgets/top_charts_page.dart';
import 'services/native_bootstrap_stub.dart'
    if (dart.library.io) 'services/native_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final (name, path) in [
      ('Noto Sans SC', 'assets/fonts/OFL.txt'),
      ('Noto Serif SC', 'assets/fonts/NotoSerifSC-OFL.txt'),
      ('ZCOOL KuaiLe', 'assets/fonts/ZCOOLKuaiLe-OFL.txt'),
      ('Node.js Mobile', 'assets/licenses/Nodejs-Mobile-LICENSE.txt'),
      ('Vocalo1ng / QQMusicApi', 'assets/licenses/GPL-3.0.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(path));
    }
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const StartupApp());
}

class StartupApp extends StatefulWidget {
  const StartupApp({super.key});
  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late Future<Library> startup;
  @override
  void initState() {
    super.initState();
    startup = initializeApp();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Library>(
    future: startup,
    builder: (context, state) {
      if (state.hasData) return VocaShelfApp(library: state.data!);
      return MaterialApp(
        title: 'Vocalo1ng',
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Vocalo1ng',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!state.hasError) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('正在准备本机音乐服务…首次启动需要解压资源'),
                        ] else ...[
                          const Text('启动遇到问题'),
                          const SizedBox(height: 12),
                          SelectableText('${state.error}'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                setState(() => startup = initializeApp()),
                            child: const Text('重新尝试'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<Library> initializeApp() async {
  await startBundledGateway();
  MediaKit.ensureInitialized();
  final library = Library(await SharedPreferences.getInstance())..load();
  await songAppearance.load();
  await collections.load();
  await barPreferences.load();
  final preferences = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    nativeGatewayOverride =
        defaultTargetPlatform == TargetPlatform.android &&
            preferences.getString('vocalo1ng.connection.mode') != 'lan'
        ? null
        : preferences.getString('vocalo1ng.gateway');
  }
  if (preferences.getBool('vocalo1ng.legacyImported') != true &&
      !library.recovered) {
    for (final song in library.songs) {
      final id = song.id.startsWith('netease-')
          ? song.id.substring(8)
          : song.id.startsWith('qq-')
          ? 'qq:${song.id.substring(3)}'
          : null;
      if (id == null || collections.tracks.containsKey(id)) continue;
      collections.tracks[id] = MusicTrack(
        id: id,
        title: song.title,
        artist: song.artist,
        cover: song.coverUrl,
        alias: song.alias,
      );
      if (song.favorite) collections.liked.add(id);
      collections.folders.putIfAbsent('默认收藏夹', () => {}).add(id);
    }
    await collections.persist();
    await preferences.setBool('vocalo1ng.legacyImported', true);
  }
  return library;
}

const ink = Color(0xFF203F36);
const muted = Color(0xFF74847C);
const green = Color(0xFF287C65);

class VocaShelfApp extends StatelessWidget {
  const VocaShelfApp({
    super.key,
    required this.library,
    this.showAudio = true,
    this.online = true,
  });
  final Library library;
  final bool showAudio;
  final bool online;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: songAppearance,
    builder: (context, _) => MaterialApp(
      title: 'Vocalo1ng',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => isPhoneLayout(context)
          ? Theme(data: phoneTheme(Theme.of(context)), child: child!)
          : child!,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: songAppearance.preset.background,
        fontFamily: 'NotoSansSC',
        fontFamilyFallback: const [
          'PingFang SC',
          'Noto Sans CJK SC',
          'sans-serif',
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: songAppearance.preset.seed,
          surface: songAppearance.preset.background,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE5DD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE5DD)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: songAppearance.preset.seed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          ),
        ),
        dividerColor: const Color(0xFFE1E7DE),
      ),
      home: ShelfHome(library: library, showAudio: showAudio, online: online),
    ),
  );
}

class ShelfHome extends StatefulWidget {
  const ShelfHome({
    super.key,
    required this.library,
    this.showAudio = true,
    this.online = true,
  });
  final Library library;
  final bool showAudio;
  final bool online;
  @override
  State<ShelfHome> createState() => _ShelfHomeState();
}

class _ShelfHomeState extends State<ShelfHome> {
  final playerPanel = ValueNotifier<String?>(null);
  int page = 0;
  final visitedPages = <int>{0};
  void selectPage(int value) => setState(() {
    page = value;
    visitedPages.add(value);
  });
  String query = '', filter = '全部';
  String? selectedId;
  final search = TextEditingController();
  late final MusicService music;
  Playback? playback;
  @override
  void initState() {
    super.initState();
    journalLibrary = widget.library;
    music = MusicService()..addListener(profileChanged);
    if (widget.showAudio) playback = Playback(music);
    if (widget.online) music.restoreSession();
  }

  void profileChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    playerPanel.dispose();
    search.dispose();
    playback?.dispose();
    music.removeListener(profileChanged);
    music.dispose();
    super.dispose();
  }

  Future<void> update(Song song) async => widget.library.update(song);
  Future<void> favorite(Song song) async {
    try {
      await update(song.copyWith(favorite: !song.favorite));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏保存失败，请重试')));
      }
    }
  }

  void select(Song song, bool wide) {
    if (wide) {
      setState(() => selectedId = song.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('歌曲手记')),
            body: ListenableBuilder(
              listenable: widget.library,
              builder: (context, child) => SongDetail(
                key: ValueKey(song.id),
                song: widget.library.songs.firstWhere((s) => s.id == song.id),
                onSave: update,
                music: widget.online ? music : null,
                playback: playback,
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> addSong() async {
    final song = await showDialog<Song>(
      context: context,
      builder: (_) => const AddSongDialog(),
    );
    if (song == null) return;
    try {
      await widget.library.add(song);
      if (mounted) {
        setState(() {
          page = widget.online ? 1 : 0;
          filter = '全部';
          query = '';
          search.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('歌曲保存失败，请重试')));
      }
    }
  }

  Future<void> backup() async {
    try {
      final data = widget.library.recovered
          ? widget.library.preferences.getString('vocashelf.library.v1')!
          : Song.encode(widget.library.songs);
      final saved = await exportFile(
        utf8.encode(data),
        'vocalo1ng-backup.json',
        'application/json',
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('资料备份已导出')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
      }
    }
  }

  Future<void> journal(
    MusicTrack track, {
    String lyrics = '',
    bool share = false,
  }) async {
    try {
      final id = track.isQQ
          ? 'qq-${track.id.substring(3)}'
          : 'netease-${track.id}';
      final existing = widget.library.songs
          .where((s) => s.id == id)
          .firstOrNull;
      var song =
          existing ??
          Song(
            id: id,
            title: track.title,
            artist: track.producer,
            voice: track.voice.isEmpty ? '声库待补充' : track.voice,
            alias: track.alias,
            tags: [track.platform],
            color: 0xFF2B8C7D,
            favorite: false,
            netease: track.isQQ
                ? ''
                : 'https://music.163.com/song?id=${track.id}',
            coverUrl: track.cover,
          );
      if (lyrics.isNotEmpty) {
        song = song.copyWith(
          lyrics: lyrics,
          lyricCredit: '${track.platform} · ${track.artist}',
        );
      }
      if (existing == null) {
        await widget.library.add(song);
      } else {
        await widget.library.update(song);
      }
      if (!mounted) return;
      if (share) {
        await showDialog<void>(
          context: context,
          builder: (_) => ShareCardDialog(song: song),
        );
      } else {
        playerPanel.value = 'journal';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存手记失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.library,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final landscapePhone =
            box.maxHeight < 540 &&
            box.maxWidth > box.maxHeight &&
            box.maxWidth >= 540;
        final desktop = box.maxWidth >= 900 && !landscapePhone;
        final wide = desktop && box.maxWidth >= 1280;
        final selected = selectedId == null
            ? null
            : widget.library.songs.where((s) => s.id == selectedId).firstOrNull;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: songAppearance.preset.panel,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _withPlaybackPanels(
                      Row(
                        children: [
                          if (desktop) _sidebar(),
                          if (landscapePhone)
                            SizedBox(
                              width: 56,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final (index, icon, label) in [
                                      (0, Icons.explore_outlined, '发现'),
                                      (1, Icons.favorite_outline, '收藏'),
                                      (2, Icons.menu_book_outlined, '百科'),
                                      (3, Icons.cake_outlined, '生日日历'),
                                      (4, Icons.emoji_events_outlined, 'TOP'),
                                    ])
                                      IconButton(
                                        tooltip: label,
                                        isSelected: page == index,
                                        onPressed: () => selectPage(index),
                                        icon: Icon(icon),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                _header(desktop),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: IndexedStack(
                                          index: page,
                                          children: [
                                            if (widget.online)
                                              MusicExplorer(
                                                music: music,
                                                playback: playback,
                                                onJournal: journal,
                                              )
                                            else
                                              _library(wide),
                                            CollectionsPage(playback: playback),
                                            if (visitedPages.contains(2))
                                              const WikiExplorer()
                                            else
                                              const SizedBox.shrink(),
                                            if (visitedPages.contains(3))
                                              BirthdayCalendar(music: music)
                                            else
                                              const SizedBox.shrink(),
                                            if (visitedPages.contains(4))
                                              TopChartsPage(active: page == 4)
                                            else
                                              const SizedBox.shrink(),
                                          ],
                                        ),
                                      ),
                                      if (wide && selected != null && page < 2)
                                        Container(
                                          width: 380,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            border: Border(
                                              left: BorderSide(
                                                color: Color(0xFFE2E8DE),
                                              ),
                                            ),
                                          ),
                                          child: SongDetail(
                                            key: ValueKey(selected.id),
                                            song: selected,
                                            onSave: update,
                                            music: widget.online ? music : null,
                                            playback: playback,
                                            onClose: () => setState(
                                              () => selectedId = null,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (playback != null)
                    AudioBar(
                      playback: playback!,
                      onJournal: journal,
                      onWiki: () => playerPanel.value =
                          playerPanel.value == 'wiki' ? null : 'wiki',
                      onQueue: () => playerPanel.value =
                          playerPanel.value == 'queue' ? null : 'queue',
                    ),
                  if (!desktop && !landscapePhone)
                    NavigationBar(
                      height: 54,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.onlyShowSelected,
                      selectedIndex: page,
                      onDestinationSelected: selectPage,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          label: '发现',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.favorite_outline),
                          label: '收藏',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.menu_book_outlined),
                          label: '百科',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.cake_outlined),
                          label: '生日',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          label: 'TOP',
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _withPlaybackPanels(Widget child) => playback == null
      ? child
      : PlaybackPanelHost(
          playback: playback!,
          panel: playerPanel,
          child: Stack(
            children: [
              if (selectedThemeArt(
                    songAppearance.themeArt,
                    identity:
                        '${playback?.current?.title ?? ''} ${playback?.current?.artist ?? ''}',
                    fallback: songAppearance.index,
                  )
                  case final art?)
                Positioned.fill(
                  child: ThemeArtView(art: art, light: true, opacity: .12),
                ),
              Positioned.fill(child: child),
            ],
          ),
        );

  Widget _sidebar() => Container(
    width: 216,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    decoration: BoxDecoration(
      color: songAppearance.preset.panel,
      border: Border(right: BorderSide(color: Color(0xFFE1E7DC))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 40),
            const SizedBox(width: 10),
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vocalo1ng',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 46),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 14),
          child: Text(
            '你的音乐空间',
            style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1),
          ),
        ),
        for (final (index, icon, label) in [
          (0, Icons.explore_outlined, '发现音乐'),
          (1, Icons.favorite_outline, '我的收藏'),
          (2, Icons.menu_book_outlined, 'VOCALOID百科'),
          (3, Icons.cake_outlined, '生日日历'),
          (4, Icons.emoji_events_outlined, 'TOP'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: page == index
                  ? const Color(0xFFDDE9D9)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => selectPage(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: page == index ? green : muted,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: page == index
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: page == index ? ink : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (playback != null)
          HotReview(
            playback: playback!,
            onOpen: (track) {
              playback!.play(track);
              showNowPlaying(
                context,
                playback!,
                (track, lyrics) => journal(track, lyrics: lyrics, share: true),
              );
            },
          ),
        const SizedBox(height: 20),
        const Text(
          'Vocalo1ng / v$appVersion',
          style: TextStyle(fontSize: 9, color: muted),
        ),
      ],
    ),
  );

  Widget _header(bool desktop) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: desktop ? 20 : 12,
      vertical: desktop ? 8 : 2,
    ),
    child: Row(
      children: [
        if (!desktop) ...[const BrandMark(size: 25), const SizedBox(width: 8)],
        Expanded(
          child: Text(
            ['发现音乐', '我的收藏', 'VOCALOID百科', '生日日历', 'TOP 榜单工坊'][page],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (widget.online) ...[
          if (!desktop)
            IconButton(
              tooltip: '音频账号',
              onPressed: () => showAccounts(context, music),
              icon: AccountAvatar(
                music: music,
                bilibili: false,
                qq: music.audioProvider == 'qq',
                size: 26,
              ),
            )
          else
            TextButton.icon(
              onPressed: () => showAccounts(context, music),
              icon: AccountAvatar(
                music: music,
                bilibili: false,
                qq: music.audioProvider == 'qq',
                size: 26,
              ),
              label: const Text('音频'),
            ),
          if (!desktop)
            IconButton(
              tooltip: '视频账号',
              onPressed: () => showAccounts(context, music, video: true),
              icon: AccountAvatar(music: music, bilibili: true, size: 26),
            )
          else
            TextButton.icon(
              onPressed: () => showAccounts(context, music, video: true),
              icon: AccountAvatar(music: music, bilibili: true, size: 26),
              label: const Text('视频'),
            ),
        ],
        IconButton(
          tooltip: '添加歌曲',
          onPressed: addSong,
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AdaptiveDialog(
              child: SizedBox(
                width: 820,
                height: 900,
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('偏好与数据'),
                      trailing: CloseButton(),
                    ),
                    Expanded(child: _settings()),
                  ],
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );

  Widget _library(bool wide) {
    final songs = widget.library.songs
        .where((song) => song.matches(query))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page == 0) _hero(),
          const SizedBox(height: 22),
          TextField(
            controller: search,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: '搜索个人手记',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '个人音乐手记 · ${songs.length} 首',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          if (songs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(
                    Icons.library_music_outlined,
                    size: 40,
                    color: muted,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    page == 1 && query.isEmpty
                        ? '还没有收藏，点亮歌曲旁的爱心吧。'
                        : '没有找到匹配的歌曲，试试其他关键词。',
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: addSong, child: const Text('添加一首歌曲')),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 950
                    ? 4
                    : box.maxWidth >= 580
                    ? 3
                    : box.maxWidth >= 370
                    ? 2
                    : 1;
                final width = (box.maxWidth - (columns - 1) * 18) / columns;
                return Wrap(
                  spacing: 18,
                  runSpacing: 22,
                  children: [
                    for (final song in songs)
                      SizedBox(width: width, child: _songCard(song, wide)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _hero() => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFE1EBDD),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -25,
          bottom: -50,
          child: Icon(
            Icons.album_outlined,
            size: 250,
            color: green.withValues(alpha: .09),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A LITTLE SHELF FOR YOUR FAVORITE VOICES',
                style: TextStyle(fontSize: 9, color: green, letterSpacing: 1.6),
              ),
              const SizedBox(height: 16),
              const Text(
                '把喜欢的声音，\n收进自己的世界。',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '听一首歌，读一段故事，留下属于你的注脚。',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF62806C),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: addSong,
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('添加你的第一首歌'),
                  ),
                  TextButton(
                    onPressed: () => selectPage(2),
                    child: const Text('去 VocaWiki 探索  ↗'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _songCard(Song song, bool wide) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => select(song, wide),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 1.15, child: CoverArt(song: song)),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  tooltip: song.favorite ? '取消收藏' : '收藏歌曲',
                  onPressed: () => favorite(song),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .9),
                    minimumSize: const Size(32, 32),
                  ),
                  icon: Icon(
                    song.favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 17,
                    color: song.favorite ? const Color(0xFFBC6275) : ink,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
            child: Text(
              '${song.artist} · ${song.voice}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.notes_rounded, size: 12, color: muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  song.review.isEmpty ? '等待你的第一条注脚' : '已有私人听后感',
                  style: const TextStyle(fontSize: 9, color: muted),
                ),
              ),
              if (song.rating > 0)
                Text(
                  '★ ${song.rating}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFB18B42),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _settings() => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ThemeSettings(),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 Vocalo1ng'),
            subtitle: const Text('版本 $appVersion · 开源项目与反馈'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutVocalo1ng()),
            ),
          ),
        ),
        if (!kIsWeb) const GatewaySettings(),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AdaptiveDialog(
              child: SizedBox(
                width: 950,
                height: MediaQuery.sizeOf(context).height * .85,
                child: _library(false),
              ),
            ),
          ),
          icon: const Icon(Icons.edit_note),
          label: const Text('查看原有个人音乐手记'),
        ),

        Text(
          '小小的收藏，认真保存。',
          style: TextStyle(
            fontSize: isPhoneLayout(context) ? 19 : 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        _info(
          Icons.lock_outline,
          '你的数据，留在本机',
          '私人收藏、评价与分享卡资料保存在此设备，可通过 JSON 文件在安卓和电脑之间合并导入。网易云云端歌单保存在对应账号。',
        ),
        _info(
          Icons.link,
          '三个入口，一份歌曲手记',
          '发现页支持网易云和 QQ 音乐搜索、听歌和漫游。音频与视频账号分别保存；网易云支持云端歌单。点击播放栏封面进入滚动歌词，百科自动匹配并在应用内阅读。',
        ),
        _info(
          Icons.image_outlined,
          '分享你自己的喜欢',
          '八种分享卡可导出 PNG，并可选择配色、字体和艺术字。默认封面由程序绘制，也可导入图片。',
        ),
        _info(
          Icons.music_note_outlined,
          '本地音频',
          '点击底部文件夹打开 MP3、WAV 等文件。本地文件与在线歌曲共用播放器和播放控制；文件不会上传。',
        ),
        const SizedBox(height: 18),
        DataTransfer(library: widget.library),
        const SizedBox(height: 24),
        const Text(
          'Vocalo1ng  $appVersion\n个人音乐记录工具 / 非官方客户端\n在线歌曲遵循当前账号、版权与地区可用性；第三方接口可能变化。',
          style: TextStyle(color: muted, fontSize: 11, height: 1.8),
        ),
      ],
    ),
  );

  Widget _info(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: green, size: 23),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.8),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AddSongDialog extends StatefulWidget {
  const AddSongDialog({super.key});
  @override
  State<AddSongDialog> createState() => _AddSongDialogState();
}

class _AddSongDialogState extends State<AddSongDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      artist = TextEditingController(),
      voice = TextEditingController(),
      aliases = TextEditingController();
  @override
  void dispose() {
    for (final c in [title, artist, voice, aliases]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('给喜欢的声音留个位置'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '先记录作品，再在歌曲详情中绑定网易云与 B 站链接。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 20),
              for (final (controller, label) in [
                (title, '歌曲名'),
                (artist, 'P 主 / 创作者'),
                (voice, '歌手 / 声库'),
              ]) ...[
                TextFormField(
                  controller: controller,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: label),
                  validator: (v) => v!.trim().isEmpty ? '请填写$label' : null,
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: aliases,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '别名 / 版本说明（选填）'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            Song(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              title: title.text.trim(),
              artist: artist.text.trim(),
              voice: voice.text.trim(),
              alias: aliases.text.trim(),
              tags: const ['我的曲库'],
              color: 0xFF2B8C7D,
              favorite: false,
            ),
          );
        },
        child: const Text('添加到曲库'),
      ),
    ],
  );
}
