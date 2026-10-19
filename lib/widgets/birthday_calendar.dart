import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import '../services/birthdays.dart';
import '../services/music.dart';
import '../services/wiki.dart';
import 'song_detail.dart';

class BirthdayCalendar extends StatefulWidget {
  const BirthdayCalendar({super.key, required this.music});
  final MusicService music;
  @override
  State<BirthdayCalendar> createState() => _BirthdayCalendarState();
}

class _BirthdayCalendarState extends State<BirthdayCalendar>
    with WidgetsBindingObserver {
  final prefs = BirthdayPreferences();
  final wiki = WikiService();
  final cards = PageController(viewportFraction: .92);
  final images = <String, String>{};
  late DateTime date, month;
  Timer? timer;
  List<Map<String, dynamic>> items = [];
  int limit = 24, revision = 0;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    date = DateUtils.dateOnly(DateTime.now());
    month = DateTime(date.year, date.month);
    prefs.load();
    query();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => checkDay());
  }

  void checkDay() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!mounted || DateUtils.isSameDay(today, date)) return;
    setState(() {
      date = today;
      month = DateTime(today.year, today.month);
    });
    query();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkDay();
  }

  @override
  void dispose() {
    timer?.cancel();
    revision++;
    WidgetsBinding.instance.removeObserver(this);
    prefs.dispose();
    wiki.dispose();
    cards.dispose();
    super.dispose();
  }

  Future<void> query() async {
    final version = ++revision;
    setState(() {
      loading = true;
      error = null;
      limit = 24;
      items = [];
    });
    try {
      final data = await widget.music.request(
        '/api/anniversaries',
        params: {
          'date':
              '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
        },
      );
      if (mounted && version == revision) {
        setState(
          () => items = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted && version == revision) setState(() => error = '$e');
    } finally {
      if (mounted && version == revision) setState(() => loading = false);
    }
  }

  Future<String> portrait(SingerBirthday singer) async {
    if (images.containsKey(singer.wiki)) return images[singer.wiki]!;
    final document = await wiki.article(title: singer.wiki);
    final nodes = html.parseFragment(document.html).querySelectorAll('img');
    final node =
        nodes
            .where(
              (n) => (int.tryParse(n.attributes['width'] ?? '0') ?? 0) >= 150,
            )
            .firstOrNull ??
        nodes.firstOrNull;
    return images[singer.wiki] = node?.attributes['src'] ?? '';
  }

  Future<void> upload(SingerBirthday singer) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: '角色图片',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 8 * 1024 * 1024) {
        throw StateError('请选择小于 8MB 的图片');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await file.readAsBytes(),
      );
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          final scale = math.min(
            1.0,
            640 / math.max(descriptor.width, descriptor.height),
          );
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * scale).round()),
            targetHeight: math.max(1, (descriptor.height * scale).round()),
          );
          try {
            final frame = await codec.getNextFrame();
            try {
              final bytes = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (bytes != null && mounted) {
                await prefs.setImage(singer.id, bytes.buffer.asUint8List());
              }
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('换图失败：$e')));
      }
    }
  }

  Widget countdown(SingerBirthday singer) {
    final days = singer.days(date), accent = Color(singer.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: .24),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: prefs.images[singer.id] != null
                      ? Image.memory(
                          prefs.images[singer.id]!,
                          fit: BoxFit.contain,
                        )
                      : FutureBuilder<String>(
                          future: portrait(singer),
                          builder: (context, snapshot) {
                            final src = snapshot.data ?? '';
                            if (src.isEmpty) {
                              return Center(
                                child: Text(
                                  singer.name.substring(0, 1),
                                  style: TextStyle(fontSize: 64, color: accent),
                                ),
                              );
                            }
                            return Image.network(
                              src,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.person_outline, size: 64),
                            );
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 12, 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        singer.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${singer.month}月${singer.day}日',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          days == 0 ? '生日快乐！' : '$days 天',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                      Text(
                        days == 0 ? '今天，一起为 TA 庆祝' : '距离下一次纪念日',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        singer.note,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 10),
                      ),
                      Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: '自定义角色图片',
                            onPressed: () => upload(singer),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                          ),
                          if (prefs.images.containsKey(singer.id))
                            IconButton(
                              tooltip: '恢复百科图片',
                              onPressed: () => prefs.setImage(singer.id, null),
                              icon: const Icon(Icons.restore),
                            ),
                          IconButton(
                            tooltip: '图片与日期出处：VocaWiki',
                            onPressed: () =>
                                openSource(context, Uri.parse(singer.source)),
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget monthCalendar() {
    final first = DateTime(month.year, month.month),
        count = DateUtils.getDaysInMonth(month.year, month.month),
        offset = first.weekday - 1;
    final today = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上个月',
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year} 年 ${month.month} 月',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(child: Center(child: Text(d))),
              ],
            ),
            const SizedBox(height: 6),
            for (int row = 0; row < (offset + count + 6) ~/ 7; row++)
              Row(
                children: [
                  for (int col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final day = row * 7 + col - offset + 1;
                          if (day < 1 || day > count) {
                            return const SizedBox(height: 38);
                          }
                          final singers = singerBirthdays
                              .where(
                                (s) => s.month == month.month && s.day == day,
                              )
                              .toList();
                          return Tooltip(
                            message: singers.map((s) => s.name).join('、'),
                            child: InkWell(
                              onTap: singers.isEmpty
                                  ? null
                                  : () {
                                      for (final s in singers) {
                                        if (!prefs.selected.contains(s.id)) {
                                          prefs.toggle(s.id);
                                        }
                                      }
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 38,
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: singers.isEmpty
                                      ? null
                                      : Color(
                                          singers.first.color,
                                        ).withValues(alpha: .2),
                                  border:
                                      today.year == month.year &&
                                          today.month == month.month &&
                                          today.day == day
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: TextStyle(
                                        fontWeight: singers.isEmpty
                                            ? null
                                            : FontWeight.bold,
                                      ),
                                    ),
                                    if (singers.isNotEmpty)
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Color(singers.first.color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 6),
            const Text(
              '有色日期为歌姬生日 / 首发纪念日，点击加入倒计时。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: prefs,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final selected =
            singerBirthdays.where((s) => prefs.selected.contains(s.id)).toList()
              ..sort((a, b) => a.days(date).compareTo(b.days(date)));
        return ListView(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 24),
          children: [
            Text(
              '把喜欢的日子，留在日历上',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('选择角色显示倒计时，多选后左右滑动。日期来自 VocaWiki，角色生日与声库首发纪念日已分别注明。'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final s in singerBirthdays)
                  FilterChip(
                    label: Text('${s.name} ${s.month}/${s.day}'),
                    selected: prefs.selected.contains(s.id),
                    avatar: CircleAvatar(
                      backgroundColor: Color(s.color),
                      radius: 5,
                    ),
                    onSelected: (_) => prefs.toggle(s.id),
                  ),
              ],
            ),
            if (selected.isNotEmpty)
              SizedBox(
                height: constraints.maxWidth < 600 ? 270 : 300,
                child: PageView.builder(
                  controller: cards,
                  itemCount: selected.length,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: cards,
                    child: countdown(selected[i]),
                    builder: (context, child) {
                      final page =
                          cards.hasClients &&
                              cards.position.hasContentDimensions
                          ? cards.page ?? 0
                          : 0.0;
                      final distance = (page - i).clamp(-1.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, distance.abs() * 8),
                        child: Transform.rotate(
                          angle: distance * .025,
                          child: Transform.scale(
                            scale: 1 - distance.abs() * .06,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (selected.length > 1)
              Text(
                '已选 ${selected.length} 位 · 左右滑动查看',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (constraints.maxWidth >= 720)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 480, child: monthCalendar()),
              )
            else
              ExpansionTile(
                title: const Text('查看生日日历'),
                initiallyExpanded: selected.isEmpty,
                children: [monthCalendar()],
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本日 VOCALOID 纪念查询',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新纪念查询',
                  onPressed: loading ? null : query,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text('${date.year}年${date.month}月${date.day}日 · 同一天投稿的歌曲'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    openSource(context, Uri.https('vocabirth.melodynade.com')),
                child: const Text('数据来源：Vocabirth · melodynade'),
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(error!),
                      TextButton.icon(
                        onPressed: query,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!loading && error == null && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('数据源中暂无这一天的歌曲记录。'),
              ),
            LayoutBuilder(
              builder: (context, box) {
                final cols = math.max(
                  1,
                  (box.maxWidth / (box.maxWidth < 600 ? 170 : 260)).floor(),
                );
                final width = (box.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in items.take(limit))
                      SizedBox(
                        width: width,
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => openSource(
                              context,
                              Uri.parse(item['url'] as String),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(
                                    widget.music.image(
                                      item['thumbnail'] as String,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.music_video),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${item['year']} / ${date.month} / ${date.day} · niconico',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (items.length > limit)
              TextButton(
                onPressed: () => setState(() => limit += 24),
                child: Text('显示更多 · 共 ${items.length} 首'),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    ),
  );
}
