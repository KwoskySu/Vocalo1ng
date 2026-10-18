import 'adaptive_dialog.dart';
import 'package:flutter/material.dart';
import '../services/music.dart';
import 'account_avatar.dart';
import 'music_login.dart';
import 'qq_login.dart';
import 'bilibili_login.dart';

Future<void> showAccounts(
  BuildContext context,
  MusicService music, {
  bool video = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => AdaptiveDialog(
    child: SizedBox(
      width: 560,
      height: 430,
      child: DefaultTabController(
        initialIndex: video ? 1 : 0,
        length: 2,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.headphones), text: '音频账号'),
                      Tab(
                        icon: Icon(Icons.smart_display_outlined),
                        text: '视频账号',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListenableBuilder(
                    listenable: music,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          '音频来源可在首页切换，两个账号分别保存。',
                          style: TextStyle(fontSize: 12),
                        ),
                        ListTile(
                          leading: AccountAvatar(music: music, bilibili: false),
                          title: const Text('网易云音乐'),
                          subtitle: Text(
                            music.profile?['nickname'] as String? ?? '未登录',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              if (!music.loggedIn) {
                                await showMusicLogin(context, music);
                                return;
                              }
                              await showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('网易云账号'),
                                  content: Text(
                                    '${music.profile!['nickname']} · 已保存登录',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('关闭'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await music.logout();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('退出登录'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Text(music.loggedIn ? '管理账号' : '扫码登录'),
                          ),
                        ),
                        ListTile(
                          leading: AccountAvatar(
                            music: music,
                            bilibili: false,
                            qq: true,
                          ),
                          title: const Text('QQ 音乐'),
                          subtitle: Text(
                            music.qqProfile?['nickname'] as String? ?? '未登录',
                          ),
                          trailing: TextButton(
                            onPressed: () => showQQLogin(context, music),
                            child: Text(
                              music.qqProfile == null ? '扫码登录' : '管理账号',
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '登录状态在本机加密保存。关闭页面、关闭服务后再次打开会自动恢复。',
                            style: TextStyle(fontSize: 11, height: 1.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: music,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        ListTile(
                          leading: AccountAvatar(music: music, bilibili: true),
                          title: const Text('哔哩哔哩'),
                          subtitle: Text(
                            music.bilibiliProfile?['nickname'] as String? ??
                                '未登录',
                          ),
                          trailing: TextButton(
                            onPressed: () => showBilibiliLogin(context, music),
                            child: Text(
                              music.bilibiliLoggedIn ? '管理账号' : '扫码登录',
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '视频使用独立的 B 站登录状态，并按账号权限提供可用画质。',
                            style: TextStyle(fontSize: 11, height: 1.8),
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
  ),
);
