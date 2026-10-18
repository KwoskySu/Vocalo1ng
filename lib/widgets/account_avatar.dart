import 'package:flutter/material.dart';
import '../services/music.dart';

/// The source badge keeps the two accounts distinguishable, even for equal photos.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.music,
    required this.bilibili,
    this.size = 30,
    this.qq = false,
  });
  final MusicService music;
  final bool bilibili;
  final bool qq;
  final double size;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) {
      final profile = bilibili
          ? music.bilibiliProfile
          : qq
          ? music.qqProfile
          : music.profile;
      final source = profile?['avatar'] as String? ?? '';
      final color = bilibili
          ? const Color(0xFFCE7188)
          : qq
          ? const Color(0xFF24996A)
          : const Color(0xFFC64747);
      final platform = bilibili
          ? 'B 站'
          : qq
          ? 'QQ 音乐'
          : '网易云';
      return Semantics(
        label: profile == null
            ? '$platform未登录'
            : '$platform账号：${profile['nickname']}',
        image: true,
        child: SizedBox(
          width: size + 5,
          height: size + 5,
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: source.isEmpty
                      ? ColoredBox(
                          color: color.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person_outline,
                            color: color,
                            size: size * 0.65,
                          ),
                        )
                      : Image.network(
                          music.image(source),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              color: color,
                              size: size * 0.65,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      bilibili ? Icons.smart_display : Icons.music_note,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
