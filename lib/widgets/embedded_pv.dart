import 'package:flutter/material.dart';
import '../services/music.dart';
import 'pv_player.dart';

class EmbeddedPv extends StatefulWidget {
  const EmbeddedPv({super.key, required this.music, required this.bvid});
  final MusicService music;
  final String bvid;
  @override
  State<EmbeddedPv> createState() => _EmbeddedPvState();
}

class _EmbeddedPvState extends State<EmbeddedPv> {
  late Future<String> source;
  String? uid;
  @override
  void initState() {
    super.initState();
    uid = widget.music.bilibiliProfile?['uid'] as String?;
    source = resolve();
    widget.music.addListener(accountChanged);
  }

  Future<String> resolve() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await resolveOnce();
      } catch (error) {
        if (!mounted ||
            attempt == 1 ||
            (error is MusicApiException &&
                [400, 401, 403].contains(error.status)))
          rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    throw StateError('无法初始化播放器');
  }

  Future<String> resolveOnce() async {
    final data = await widget.music.request(
      '/api/pv/player',
      body: {'bvid': widget.bvid},
    );
    return Uri.parse(
      widget.music.base,
    ).resolve(data['url'] as String).toString();
  }

  void accountChanged() {
    final next = widget.music.bilibiliProfile?['uid'] as String?;
    if (uid == next) return;
    uid = next;
    setState(() => source = resolve());
  }

  @override
  void dispose() {
    widget.music.removeListener(accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: source,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return PvPlayer(
          key: ValueKey(snapshot.data),
          bvid: widget.bvid,
          pageUrl: snapshot.data,
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${snapshot.error}'),
              TextButton(
                onPressed: () => setState(() => source = resolve()),
                child: const Text('重试播放'),
              ),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    },
  );
}
