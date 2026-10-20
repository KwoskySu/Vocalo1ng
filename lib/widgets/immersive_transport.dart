import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/playback.dart';

class ImmersiveTransport extends StatefulWidget {
  const ImmersiveTransport({
    super.key,
    required this.playback,
    required this.ink,
    required this.accent,
    required this.compact,
    required this.onInteraction,
    required this.onSeek,
  });
  final Playback playback;
  final Color ink, accent;
  final bool compact;
  final VoidCallback onInteraction, onSeek;
  @override
  State<ImmersiveTransport> createState() => _ImmersiveTransportState();
}

class _ImmersiveTransportState extends State<ImmersiveTransport> {
  double? draft;
  bool dragging = false, committing = false;
  Timer? expiry;
  int request = 0;
  @override
  void dispose() {
    expiry?.cancel();
    request++;
    super.dispose();
  }

  @override
  void didUpdateWidget(ImmersiveTransport old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      expiry?.cancel();
      draft = null;
      dragging = false;
      committing = false;
      request++;
    }
  }

  String time(int ms) {
    final s = math.max(0, ms ~/ 1000);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> commit(double value, int duration) async {
    final token = ++request;
    widget.onSeek();
    widget.onInteraction();
    setState(() {
      dragging = false;
      committing = true;
      draft = value;
    });
    expiry?.cancel();
    try {
      await widget.playback.player.seek(
        Duration(milliseconds: (value * duration).round()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('跳转失败，请重试')));
      }
    } finally {
      if (mounted && token == request) {
        setState(() => committing = false);
        expiry = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => draft = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: widget.playback.player.stream.position,
    initialData: widget.playback.player.state.position,
    builder: (context, snapshot) {
      final duration = widget.playback.player.state.duration.inMilliseconds;
      final at = (snapshot.data ?? Duration.zero).inMilliseconds;
      if (!dragging &&
          !committing &&
          draft != null &&
          (at - draft! * duration).abs() < 1000) {
        draft = null;
        expiry?.cancel();
      }
      final value =
          draft ?? (duration > 0 ? (at / duration).clamp(0.0, 1.0) : 0.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                time((value * duration).round()),
                style: TextStyle(color: widget.ink, fontSize: 11),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('immersive-seek'),
                  value: value,
                  onChangeStart: duration <= 0 || committing
                      ? null
                      : (v) {
                          widget.onInteraction();
                          expiry?.cancel();
                          setState(() {
                            dragging = true;
                            draft = v;
                          });
                        },
                  onChanged: duration <= 0 || committing
                      ? null
                      : (v) {
                          widget.onInteraction();
                          setState(() => draft = v);
                        },
                  onChangeEnd: duration <= 0 || committing
                      ? null
                      : (v) => commit(v, duration),
                  activeColor: widget.accent,
                  inactiveColor: widget.ink.withValues(alpha: .15),
                ),
              ),
              Text(
                time(duration),
                style: TextStyle(color: widget.ink, fontSize: 11),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一首',
                onPressed: widget.playback.previous,
                icon: Icon(Icons.skip_previous, color: widget.ink),
              ),
              const SizedBox(width: 18),
              StreamBuilder<bool>(
                stream: widget.playback.player.stream.playing,
                initialData: widget.playback.player.state.playing,
                builder: (_, state) => IconButton(
                  tooltip: state.data == true ? '暂停' : '播放',
                  onPressed: () {
                    widget.playback.player.playOrPause();
                    widget.onInteraction();
                  },
                  icon: Icon(
                    state.data == true
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: widget.ink,
                    size: widget.compact ? 34 : 44,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              IconButton(
                tooltip: '下一首',
                onPressed: widget.playback.next,
                icon: Icon(Icons.skip_next, color: widget.ink),
              ),
            ],
          ),
        ],
      );
    },
  );
}
