import 'audio_visualizer.dart';
import 'phone_theme.dart';
import '../services/lyric_menu.dart';
import 'immersive_stage.dart';
import 'desktop_mode.dart';
import 'adaptive_dialog.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/playback.dart';
import '../services/player_fullscreen.dart';
import '../models/music.dart';
import '../services/lyrics.dart';
import '../services/song_theme.dart';
import 'account_avatar.dart';
import 'track_lyrics.dart';
import 'playback_panels.dart';
import 'player_visuals.dart';
import 'lyric_stage.dart';
import 'atmosphere.dart';
import 'pv_browser.dart';
import 'theme_art_view.dart';
import '../services/theme_art.dart';
import 'song_detail.dart';
import 'comments.dart';
import 'collections.dart';
import 'player_tools.dart';
import 'live_mode.dart';
import 'cover_deck.dart';
import 'player_layout.dart';
import 'player_visual_preview.dart';
import 'journal_workspace.dart';

Future<void> showNowPlaying(
  BuildContext context,
  Playback playback,
  void Function(MusicTrack, String) onShare,
) => Navigator.of(context, rootNavigator: true).push<void>(
  PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'now-playing'),
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => NowPlaying(playback: playback, onShare: onShare),
  ),
);

class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key, required this.playback, required this.onShare});
  final Playback playback;
  final void Function(MusicTrack, String) onShare;
  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  late final StreamSubscription<Duration> position;
  late final StreamSubscription<bool> playing;
  late final StreamSubscription<bool> fullscreenSubscription;
  List<LyricLine> lines = [];
  List<String?> translations = [];
  String? trackId, error;
  String translation = '';
  bool loading = true,
      translated = true,
      wiki = false,
      video = false,
      journal = false,
      comments = false;
  int active = -1, generation = 0;
  bool immersive = false;
  bool? fullscreenBeforeImmersive;
  int fullscreenRevision = 0;
  @override
  void initState() {
    super.initState();
    lyricMenu.load();
    fullscreenSubscription = playerFullscreenChanges.listen((_) {
      if (mounted) setState(() {});
    });
    motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    playing = widget.playback.player.stream.playing.listen((on) {
      if (!mounted) return;
      if (on && video) {
        widget.playback.player.pause();
        return;
      }
      if (on && !immersive && !MediaQuery.disableAnimationsOf(context)) {
        motion.repeat();
      } else {
        motion.stop();
      }
    });
    position = widget.playback.player.stream.position.listen(updatePosition);
    widget.playback.addListener(trackChanged);
    trackChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (immersive || MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
    } else if (widget.playback.player.state.playing && !motion.isAnimating) {
      motion.repeat();
    }
  }

  void trackChanged() {
    final track = widget.playback.current;
    if (track == null || track.id == trackId) return;
    trackId = track.id;
    final request = ++generation;
    setState(() {
      lines = [];
      translations = [];
      translation = '';
      loading = true;
      error = null;
      active = -1;
      wiki = false;
      video = false;
      comments = false;
      journal = false;
    });
    widget.playback.music
        .lyrics(track.id)
        .then((data) {
          if (!mounted || request != generation) return;
          setState(() {
            translation = data.translated;
            lines = parseLyrics(data.original);
            translations = alignTranslations(lines, translation);
            loading = false;
          });
          updatePosition(widget.playback.player.state.position);
        })
        .catchError((Object e) {
          if (mounted && request == generation) {
            setState(() {
              error = '$e';
              loading = false;
            });
          }
        });
  }

  void updatePosition(Duration value) {
    if (!mounted || lines.isEmpty) return;
    final next = activeLyricIndex(lines, value);
    if (next != active) setState(() => active = next);
  }

  @override
  void dispose() {
    fullscreenSubscription.cancel();
    if (fullscreenBeforeImmersive != null || playerFullscreenActive) {
      unawaited(
        setPlayerFullscreen(
          fullscreenBeforeImmersive ?? false,
        ).catchError((_) {}),
      );
    }
    generation++;
    widget.playback.removeListener(trackChanged);
    position.cancel();
    playing.cancel();
    motion.dispose();
    super.dispose();
  }

  void options(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SizedBox(
      height: math.min(MediaQuery.sizeOf(context).height * .86, 760),
      child: VisualOptions(
        previewBuilder: isPhoneLayout(context)
            ? (_) => PlayerVisualPreview(
                url: widget.playback.music.image(
                  widget.playback.current!.cover,
                ),
                lines: lines,
                translations: translations,
                active: active,
              )
            : null,
      ),
    ),
  );
  void queue(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: PanelFrame(
        title: '播放列表',
        onClose: () => Navigator.pop(sheet),
        child: QueuePanel(playback: widget.playback),
      ),
    ),
  );
  Future<void> enterImmersive() async {
    if (immersive || !mounted) return;
    fullscreenBeforeImmersive ??= playerFullscreenActive;
    fullscreenRevision++;
    motion.stop();
    setState(() {
      immersive = true;
      wiki = false;
      video = false;
      comments = false;
      journal = false;
    });
    unawaited(
      setPlayerFullscreen(true).catchError((_) {
        if (mounted && immersive) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(const SnackBar(content: Text('未能切换系统全屏，仍可使用沉浸舞台')));
        }
      }),
    );
  }

  void leaveImmersive() {
    if (!immersive || !mounted) return;
    setState(() => immersive = false);
    final revision = ++fullscreenRevision;
    unawaited(
      setPlayerFullscreen(fullscreenBeforeImmersive ?? false)
          .then((_) {
            if (mounted && !immersive && revision == fullscreenRevision) {
              fullscreenBeforeImmersive = null;
            }
          })
          .catchError((_) {}),
    );
    if (widget.playback.player.state.playing &&
        !MediaQuery.disableAnimationsOf(context)) {
      motion.repeat();
    }
  }

  Future<void> runTool(String action) async {
    if (action == '可视化') {
      await showAudioVisualizer(context, widget.playback);
      return;
    }
    if (action == '沉浸') {
      if (immersive) {
        leaveImmersive();
      } else {
        await enterImmersive();
      }
      return;
    }
    if (action == '管理') {
      await showLyricMenuSettings(context);
      return;
    }
    if (action == '沉浸设置') {
      await showImmersiveSettings(context);
      return;
    }
    if (action == '全屏') {
      try {
        await setPlayerFullscreen(!playerFullscreenActive);
      } catch (_) {}
      return;
    }
    if (action == '收藏') {
      final track = widget.playback.current;
      if (track == null) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('喜爱与收藏'),
          content: CollectionActions(track: track),
          actions: [const CloseButton()],
        ),
      );
      return;
    }
    if (action == '样式') {
      options(context);
      return;
    }
    if (action == '直播') {
      await showLiveMode(context, widget.playback);
      return;
    }
    if (action == '桌面') {
      await showDesktopMode(context, widget.playback);
      return;
    }
    if (immersive) leaveImmersive();
    if (action == '视频') {
      await widget.playback.player.pause();
      if (!mounted) return;
      if (MediaQuery.sizeOf(context).shortestSide < 600) {
        final t = widget.playback.current!;
        await showPvs(context, widget.playback.music, t.title, t.artist);
        return;
      }
    }
    setState(() {
      wiki = action == '百科' && !wiki;
      video = action == '视频' && !video;
      journal = action == '手记' && !journal;
      comments = action == '评论' && !comments;
    });
  }

  Widget toolsMenu(Color ink) => PopupMenuButton<String>(
    tooltip: '歌词页菜单',
    icon: Icon(Icons.more_horiz, color: ink),
    onSelected: runTool,
    itemBuilder: (_) => [
      PopupMenuItem(value: '沉浸', child: Text(immersive ? '退出沉浸模式' : '进入沉浸模式')),
      const PopupMenuItem(value: '可视化', child: Text('音频可视化 · 自动全屏')),
      const PopupMenuItem(value: '沉浸设置', child: Text('沉浸设置 · 样式预览')),
      const PopupMenuItem(value: '全屏', child: Text('切换窗口全屏')),
      const PopupMenuItem(value: '管理', child: Text('歌词页菜单管理')),
      const PopupMenuDivider(),
      for (final name in [
        '视频',
        '百科',
        '收藏',
        '手记',
        '评论',
        '样式',
        '直播',
        if (desktopModeSupported) '桌面',
      ])
        PopupMenuItem(value: name, child: Text(name)),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([songAppearance, widget.playback, lyricMenu]),
    builder: (context, _) {
      final track = widget.playback.current;
      if (track == null) {
        return const AdaptiveDialog(
          child: Padding(padding: EdgeInsets.all(40), child: Text('请选择一首歌曲')),
        );
      }
      final theme = songAppearance.preset;
      final style = songAppearance.lyricStyle;
      final light = style == 4;
      final foreground = light ? const Color(0xFF243830) : Colors.white;
      final background = light
          ? theme.background
          : Color.lerp(theme.seed, Colors.black, .82)!;
      final muted = foreground.withValues(alpha: .55);
      final viewport = MediaQuery.sizeOf(context);
      final phoneLandscape =
          isPhoneLayout(context) && viewport.width > viewport.height;
      final url = widget.playback.music.image(track.cover);
      final art = selectedThemeArt(
        songAppearance.themeArt,
        identity: '${track.title} ${track.artist}',
        fallback: songAppearance.index,
      );
      if (immersive) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) leaveImmersive();
          },
          child: Dialog.fullscreen(
            child: ImmersivePlayer(
              playback: widget.playback,
              lines: lines,
              translations: translations,
              active: active,
              animation: motion,
              bilingual: translated,
              onExit: leaveImmersive,
              menu: toolsMenu(
                lyricMenu.immersiveStyle == 0
                    ? const Color(0xff23312d)
                    : Colors.white,
              ),
            ),
          ),
        );
      }
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (playerFullscreenActive) {
              unawaited(setPlayerFullscreen(false).catchError((_) {}));
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
                    .copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarContrastEnforced: false,
                      systemStatusBarContrastEnforced: false,
                    ),
            child: Dialog.fullscreen(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: light
                      ? theme.panel
                      : Color.lerp(theme.seed, Colors.black, .7),
                  dialogTheme: DialogThemeData(
                    backgroundColor: light
                        ? theme.panel
                        : Color.lerp(theme.seed, Colors.black, .7),
                    titleTextStyle: TextStyle(
                      color: foreground,
                      fontSize: 20,
                      fontFamily: 'NotoSansSC',
                    ),
                    contentTextStyle: TextStyle(
                      color: foreground,
                      fontFamily: 'NotoSansSC',
                    ),
                  ),
                  popupMenuTheme: PopupMenuThemeData(
                    color: light
                        ? theme.panel
                        : Color.lerp(theme.seed, Colors.black, .7),
                    textStyle: TextStyle(
                      color: foreground,
                      fontFamily: 'NotoSansSC',
                    ),
                  ),
                  bottomSheetTheme: BottomSheetThemeData(
                    backgroundColor: light
                        ? theme.panel
                        : Color.lerp(theme.seed, Colors.black, .7),
                  ),
                  iconTheme: IconThemeData(color: foreground),
                  chipTheme: Theme.of(context).chipTheme.copyWith(
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? (light
                                ? theme.seed.withValues(alpha: .18)
                                : Color.lerp(theme.seed, Colors.black, .35))
                          : (light
                                ? Colors.white
                                : Color.lerp(theme.seed, Colors.black, .75)),
                    ),
                    backgroundColor: light
                        ? Colors.white
                        : foreground.withValues(alpha: .07),
                    selectedColor: light
                        ? theme.seed.withValues(alpha: .18)
                        : theme.seed.withValues(alpha: .55),
                    labelStyle: TextStyle(
                      color: foreground,
                      fontFamily: 'NotoSansSC',
                    ),
                    secondaryLabelStyle: TextStyle(color: foreground),
                    checkmarkColor: foreground,
                    side: BorderSide(color: foreground.withValues(alpha: .18)),
                  ),
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: theme.seed,
                    brightness: light ? Brightness.light : Brightness.dark,
                    surface: light
                        ? theme.panel
                        : Color.lerp(theme.seed, Colors.black, .7),
                  ),
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: foreground,
                    displayColor: foreground,
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: false,
                  ),
                ),
                child: Builder(
                  builder: (context) => Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: background)),
                      if (art != null)
                        Positioned.fill(
                          child: ThemeArtView(
                            art: art,
                            light: light,
                            opacity: light ? .18 : .45,
                          ),
                        ),
                      if (art == null && !light && url.isNotEmpty)
                        Positioned.fill(
                          child: Opacity(
                            opacity: style == 5 ? .07 : .2,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 55,
                                sigmaY: 55,
                              ),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(),
                              ),
                            ),
                          ),
                        ),
                      if (style == 0 || style == 3 || style == 5 || style >= 6)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: motion,
                            builder: (_, _) => CustomPaint(
                              painter: Atmosphere(
                                theme.accent,
                                motion.value,
                                style,
                              ),
                            ),
                          ),
                        ),
                      SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: phoneLandscape ? 0 : 8,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: '收起歌词详情',
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: foreground,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '正在播放 · ${track.platform}',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (!isPhoneLayout(context))
                                    TextButton.icon(
                                      onPressed: () => options(context),
                                      icon: Icon(
                                        Icons.auto_awesome,
                                        color: foreground,
                                        size: 19,
                                      ),
                                      label: Text(
                                        '视觉实验室',
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (isPhoneLayout(context))
                                    IconButton(
                                      tooltip: '视觉实验室',
                                      onPressed: () => options(context),
                                      icon: Icon(
                                        Icons.auto_awesome,
                                        color: foreground,
                                        size: 20,
                                      ),
                                    ),
                                  toolsMenu(foreground),
                                  PopupMenuButton<int>(
                                    tooltip: '歌曲主题 · 40 套预设',
                                    icon: Icon(
                                      Icons.palette_outlined,
                                      color: foreground,
                                      size: 21,
                                    ),
                                    onSelected: (i) {
                                      if (i == -1) {
                                        songAppearance.setAutomatic(true);
                                        songAppearance.adapt(
                                          '${track.title} ${track.artist}',
                                          url,
                                        );
                                      } else {
                                        songAppearance.select(i);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      CheckedPopupMenuItem(
                                        value: -1,
                                        checked: songAppearance.automatic,
                                        child: const Text('自动适配歌曲封面'),
                                      ),
                                      for (
                                        var i = 0;
                                        i < songThemes.length;
                                        i++
                                      )
                                        PopupMenuItem(
                                          value: i,
                                          child: Text(songThemes[i].name),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final cinema =
                                      songAppearance.scrollStyle == 2;
                                  final platform = Theme.of(context).platform;
                                  final layout = PlayerLayout(
                                    viewport: MediaQuery.sizeOf(context),
                                    available: Size(
                                      box.maxWidth,
                                      box.maxHeight,
                                    ),
                                    mobile:
                                        platform == TargetPlatform.android ||
                                        platform == TargetPlatform.iOS,
                                    cinema: cinema,
                                  );
                                  final landscape = layout.landscape;
                                  final wide = layout.wide;
                                  final phone = layout.phone;
                                  if (phone && (wiki || comments || journal)) {
                                    return Column(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: PanelFrame(
                                              title: journal
                                                  ? '音乐手记与百科'
                                                  : comments
                                                  ? '${track.platform} · 评论区'
                                                  : '歌曲百科',
                                              onClose: () => setState(() {
                                                wiki = false;
                                                comments = false;
                                                journal = false;
                                              }),
                                              child: journal
                                                  ? JournalWorkspace(
                                                      key: ValueKey(
                                                        'note:${track.id}',
                                                      ),
                                                      playback: widget.playback,
                                                      track: track,
                                                    )
                                                  : comments
                                                  ? CommentPanel(
                                                      key: ValueKey(
                                                        'comments:${track.id}',
                                                      ),
                                                      music:
                                                          widget.playback.music,
                                                      track: track,
                                                    )
                                                  : SongWikiPanel(
                                                      music:
                                                          widget.playback.music,
                                                      track: track,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        controls(
                                          context,
                                          foreground,
                                          muted,
                                          compact: landscape,
                                        ),
                                      ],
                                    );
                                  }
                                  final horizontalAlbum =
                                      layout.horizontalAlbum;
                                  final coverSize = layout.coverSize;
                                  final cover = CoverDeck(
                                    size: coverSize,
                                    playback: widget.playback,
                                    child: MotionCover(
                                      url: url,
                                      size: coverSize,
                                      motion: motion,
                                      style: style,
                                    ),
                                  );
                                  final info = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: horizontalAlbum
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: horizontalAlbum
                                            ? TextAlign.left
                                            : TextAlign.center,
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: landscape
                                              ? 14
                                              : wide && !horizontalAlbum
                                              ? 24
                                              : phone
                                              ? 15
                                              : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (widget.playback.error != null)
                                        Text(
                                          widget.playback.error!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (!phone)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: video
                                                  ? '收起视频'
                                                  : '观看歌曲视频',
                                              icon: const Icon(
                                                Icons.smart_display_outlined,
                                                size: 21,
                                              ),
                                              onPressed: () async {
                                                if (MediaQuery.sizeOf(
                                                      context,
                                                    ).shortestSide <
                                                    600) {
                                                  await widget.playback.player
                                                      .pause();
                                                  if (!context.mounted) return;
                                                  await showPvs(
                                                    context,
                                                    widget.playback.music,
                                                    track.title,
                                                    track.artist,
                                                  );
                                                  return;
                                                }
                                                if (!video) {
                                                  await widget.playback.player
                                                      .pause();
                                                }
                                                if (mounted) {
                                                  setState(() {
                                                    video = !video;
                                                    wiki = false;
                                                    comments = false;
                                                    journal = false;
                                                  });
                                                }
                                              },
                                            ),
                                            AccountAvatar(
                                              music: widget.playback.music,
                                              bilibili: false,
                                              qq: track.isQQ,
                                              size: 23,
                                            ),
                                            Flexible(
                                              child: TextButton.icon(
                                                onPressed: () => setState(() {
                                                  wiki = !wiki;
                                                  video = false;
                                                  comments = false;
                                                  journal = false;
                                                }),
                                                icon: const Icon(
                                                  Icons.menu_book_outlined,
                                                  size: 17,
                                                ),
                                                label: Text(
                                                  wiki ? '收起百科' : '歌曲百科',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  );
                                  final albumTools = SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (lyricMenu.visible.contains('视频'))
                                          IconButton(
                                            tooltip: '观看歌曲视频',
                                            onPressed: () => runTool('视频'),
                                            icon: const Icon(
                                              Icons.smart_display_outlined,
                                            ),
                                          ),
                                        if (lyricMenu.visible.contains('百科'))
                                          IconButton(
                                            tooltip: '歌曲百科',
                                            onPressed: () => runTool('百科'),
                                            icon: const Icon(
                                              Icons.menu_book_outlined,
                                            ),
                                          ),
                                        if (lyricMenu.visible.contains('收藏'))
                                          CollectionActions(track: track),
                                        if (lyricMenu.visible.contains('手记'))
                                          IconButton(
                                            tooltip: '音乐手记与百科',
                                            onPressed: () => runTool('手记'),
                                            icon: const Icon(Icons.edit_note),
                                          ),
                                        if (lyricMenu.visible.contains('评论'))
                                          IconButton(
                                            tooltip: '歌曲评论区',
                                            onPressed: () => runTool('评论'),
                                            icon: const Icon(
                                              Icons.comment_outlined,
                                            ),
                                          ),
                                        PlayerTools(playback: widget.playback),
                                        if (lyricMenu.visible.contains('样式'))
                                          IconButton(
                                            tooltip: '歌词字体与滚动样式',
                                            onPressed: () => runTool('样式'),
                                            icon: const Icon(Icons.tune),
                                          ),
                                        if (lyricMenu.visible.contains('直播'))
                                          IconButton(
                                            tooltip: '直播模式窗口',
                                            onPressed: () => runTool('直播'),
                                            icon: const Icon(Icons.sensors),
                                          ),
                                        if (lyricMenu.visible.contains('可视化'))
                                          IconButton(
                                            tooltip: '音频可视化 · 自动全屏',
                                            onPressed: () => runTool('可视化'),
                                            icon: const Icon(Icons.graphic_eq),
                                          ),
                                        if (lyricMenu.visible.contains(
                                          '沉浸',
                                        )) ...[
                                          IconButton(
                                            tooltip: '沉浸模式',
                                            onPressed: enterImmersive,
                                            icon: const Icon(
                                              Icons.theater_comedy_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '沉浸设置',
                                            onPressed: () =>
                                                showImmersiveSettings(context),
                                            icon: const Icon(Icons.tune),
                                          ),
                                        ],
                                        TextButton.icon(
                                          onPressed: () =>
                                              showLyricMenuSettings(context),
                                          icon: const Icon(
                                            Icons.dashboard_customize_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('菜单设置'),
                                        ),
                                      ],
                                    ),
                                  );
                                  Widget album = landscape
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            cover,
                                            const SizedBox(height: 8),
                                            info,
                                            albumTools,
                                          ],
                                        )
                                      : phone
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                cover,
                                                const SizedBox(width: 14),
                                                Expanded(child: info),
                                              ],
                                            ),
                                            albumTools,
                                          ],
                                        )
                                      : horizontalAlbum
                                      ? Row(
                                          children: [
                                            cover,
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [info, albumTools],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            cover,
                                            const SizedBox(height: 20),
                                            info,
                                            albumTools,
                                          ],
                                        );
                                  if (wiki || video || comments || journal) {
                                    album = SizedBox(
                                      height: (wiki || comments)
                                          ? math.max(120, box.maxHeight - 100)
                                          : video
                                          ? (wide && !horizontalAlbum
                                                ? box.maxHeight - 115
                                                : math.min(
                                                    box.maxHeight * .62,
                                                    410,
                                                  ))
                                          : horizontalAlbum
                                          ? math.min(box.maxHeight * .48, 310)
                                          : wide
                                          ? box.maxHeight - 115
                                          : math.min(box.maxHeight * .5, 340),
                                      child: Stack(
                                        children: [
                                          Center(child: album),
                                          Positioned.fill(
                                            child: PanelFrame(
                                              title: journal
                                                  ? '音乐手记与百科'
                                                  : video
                                                  ? '歌曲视频 · B 站 PV'
                                                  : comments
                                                  ? '${track.platform} · 评论区'
                                                  : '歌曲百科',
                                              onClose: () => setState(() {
                                                wiki = false;
                                                video = false;
                                                comments = false;
                                                journal = false;
                                              }),
                                              child: journal
                                                  ? JournalWorkspace(
                                                      key: ValueKey(
                                                        'note:${track.id}',
                                                      ),
                                                      playback: widget.playback,
                                                      track: track,
                                                    )
                                                  : comments
                                                  ? CommentPanel(
                                                      key: ValueKey(
                                                        'comments:${track.id}',
                                                      ),
                                                      music:
                                                          widget.playback.music,
                                                      track: track,
                                                    )
                                                  : video
                                                  ? PvBrowser(
                                                      key: ValueKey(
                                                        'pv:${track.id}',
                                                      ),
                                                      music:
                                                          widget.playback.music,
                                                      title: track.title,
                                                      artist: track.artist,
                                                      embedded: true,
                                                    )
                                                  : SongWikiPanel(
                                                      key: ValueKey(track.id),
                                                      music:
                                                          widget.playback.music,
                                                      track: track,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  final lyrics = loading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : error != null
                                      ? Center(
                                          child: Text(
                                            error!,
                                            style: TextStyle(color: foreground),
                                          ),
                                        )
                                      : LyricStage(
                                          key: ValueKey(
                                            '${track.id}:$wiki:$video:$comments:$journal',
                                          ),
                                          lines: lines,
                                          translations: translations,
                                          bilingual: translated,
                                          active: active,
                                          style: songAppearance.scrollStyle,
                                          font: songAppearance.lyricFont,
                                          scale: songAppearance.lyricScale,
                                          effects: songAppearance.lyricEffects,
                                          foreground: foreground,
                                          accent: light
                                              ? theme.seed
                                              : theme.accent,
                                          onSeek: widget.playback.player.seek,
                                        );
                                  if (landscape) {
                                    return PhoneLandscapePlayer(
                                      album: album,
                                      lyrics: lyrics,
                                      controls: controls(
                                        context,
                                        foreground,
                                        muted,
                                        compact: true,
                                      ),
                                    );
                                  }
                                  if (wide && !cinema) {
                                    final albumPane = Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: CenteredAlbumPane(
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: landscape
                                                      ? 12
                                                      : 30,
                                                ),
                                                child: album,
                                              ),
                                            ),
                                          ),
                                          controls(context, foreground, muted),
                                        ],
                                      ),
                                    );
                                    final lyricPane = Expanded(child: lyrics);
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: landscape ? 8 : 35,
                                      ),
                                      child: Row(
                                        children:
                                            songAppearance.scrollStyle == 4
                                            ? [lyricPane, albumPane]
                                            : [albumPane, lyricPane],
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: wide ? 80 : 14,
                                          vertical: 4,
                                        ),
                                        child: album,
                                      ),
                                      Expanded(child: lyrics),
                                      controls(context, foreground, muted),
                                    ],
                                  );
                                },
                              ),
                            ),
                            if (art != null)
                              TextButton(
                                onPressed: () =>
                                    openSource(context, Uri.parse(art.source)),
                                child: Text(
                                  art.attribution,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted, fontSize: 9),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (translation.isNotEmpty)
                                              TextButton.icon(
                                                onPressed: () => setState(
                                                  () =>
                                                      translated = !translated,
                                                ),
                                                icon: const Icon(
                                                  Icons.translate,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  translated ? '双语已开启' : '显示翻译',
                                                ),
                                              ),
                                            TextButton.icon(
                                              onPressed: () => showDialog<void>(
                                                context: context,
                                                builder: (_) => TrackLyrics(
                                                  music: widget.playback.music,
                                                  track: track,
                                                  playback: widget.playback,
                                                  onShare: (lyrics) => widget
                                                      .onShare(track, lyrics),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.ios_share,
                                                size: 16,
                                              ),
                                              label: const Text('摘录歌词分享'),
                                            ),
                                            if (MediaQuery.sizeOf(
                                                      context,
                                                    ).width >
                                                    600 &&
                                                !phoneLandscape)
                                              Text(
                                                '主题 · ${theme.name}',
                                                style: TextStyle(
                                                  color: muted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: playerFullscreenActive
                                        ? '退出全屏'
                                        : '全屏模式',
                                    icon: Icon(
                                      playerFullscreenActive
                                          ? Icons.fullscreen_exit
                                          : Icons.fullscreen,
                                      color: foreground,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await setPlayerFullscreen(
                                          !playerFullscreenActive,
                                        );
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('当前环境未能开启全屏'),
                                            ),
                                          );
                                        }
                                      }
                                    },
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
            ),
          ),
        ),
      );
    },
  );
  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  Widget controls(
    BuildContext context,
    Color foreground,
    Color muted, {
    bool compact = false,
  }) {
    final progress = StreamBuilder<Duration>(
      stream: widget.playback.player.stream.position,
      initialData: widget.playback.player.state.position,
      builder: (context, snapshot) {
        final max = widget.playback.player.state.duration.inMilliseconds
            .toDouble();
        return SizedBox(
          height: isPhoneLayout(context) ? 28 : 48,
          child: Row(
            children: [
              Text(
                time(snapshot.data!),
                style: TextStyle(color: muted, fontSize: 10),
              ),
              Expanded(
                child: Slider(
                  value: snapshot.data!.inMilliseconds.toDouble().clamp(
                    0,
                    math.max(1, max),
                  ),
                  max: math.max(1, max),
                  onChanged: max > 0
                      ? (v) => widget.playback.player.seek(
                          Duration(milliseconds: v.round()),
                        )
                      : null,
                ),
              ),
              Text(
                time(widget.playback.player.state.duration),
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
    final transport = StreamBuilder<bool>(
      stream: widget.playback.player.stream.playing,
      initialData: widget.playback.player.state.playing,
      builder: (context, snapshot) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '播放方式：${widget.playback.mode.label}',
            icon: Icon(modeIcon(widget.playback.mode), color: muted, size: 20),
            onPressed: () => widget.playback.setMode(
              PlayMode.values[(widget.playback.mode.index + 1) %
                  PlayMode.values.length],
            ),
          ),
          IconButton(
            tooltip: '上一首',
            onPressed: widget.playback.previous,
            icon: Icon(Icons.skip_previous_rounded, color: muted),
          ),
          IconButton(
            tooltip: snapshot.data! ? '暂停' : '播放',
            onPressed: widget.playback.loading
                ? null
                : () {
                    if (widget.playback.error != null) {
                      widget.playback.play(widget.playback.current!);
                    } else {
                      widget.playback.player.playOrPause();
                    }
                  },
            icon: Icon(
              snapshot.data!
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: foreground,
              size: 44,
            ),
          ),
          IconButton(
            tooltip: '下一首',
            onPressed: widget.playback.next,
            icon: Icon(Icons.skip_next_rounded, color: muted),
          ),
          IconButton(
            tooltip: '播放列表与播放方式',
            onPressed: () => queue(context),
            icon: Icon(Icons.queue_music, color: muted, size: 22),
          ),
        ],
      ),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(width: 252, child: transport),
            const SizedBox(width: 12),
            Expanded(child: progress),
          ],
        ),
      );
    }
    return SizedBox(
      width: 440,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [progress, transport],
        ),
      ),
    );
  }
}
