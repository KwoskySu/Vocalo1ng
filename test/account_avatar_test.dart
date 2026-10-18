import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocashelf/services/music.dart';
import 'package:vocashelf/widgets/account_avatar.dart';

void main() {
  testWidgets(
    'each platform displays its own proxied avatar and responds to logout',
    (tester) async {
      final music = MusicService(base: 'http://localhost:5418');
      music.profile = {
        'uid': '1',
        'nickname': 'Cloud',
        'avatar': 'https://p1.music.126.net/cloud.jpg',
      };
      music.bilibiliProfile = {
        'uid': '2',
        'nickname': 'Bili',
        'avatar': 'https://i0.hdslb.com/bfs/face/bili.jpg',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              AccountAvatar(music: music, bilibili: false),
              AccountAvatar(music: music, bilibili: true),
            ],
          ),
        ),
      );
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as NetworkImage).url)
          .toList();
      expect(images, [
        music.image(music.profile!['avatar']),
        music.image(music.bilibiliProfile!['avatar']),
      ]);
      expect(find.bySemanticsLabel('网易云账号：Cloud'), findsOneWidget);
      expect(find.bySemanticsLabel('B 站账号：Bili'), findsOneWidget);
      music.bilibiliProfile = null;
      music.notifyListeners();
      await tester.pump();
      expect(find.bySemanticsLabel('B 站未登录'), findsOneWidget);
      expect(find.bySemanticsLabel('网易云账号：Cloud'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      music.dispose();
    },
  );
}
