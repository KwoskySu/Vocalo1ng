import 'package:flutter/material.dart';
import '../services/app_info.dart';
import 'song_detail.dart';
import 'brand_mark.dart';

class AboutVocalo1ng extends StatelessWidget {
  const AboutVocalo1ng({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关于 Vocalo1ng')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  const BrandMark(size: 64),
                  const SizedBox(height: 12),
                  Text(
                    appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text('版本 $appVersion'),
                  const SizedBox(height: 12),
                  const Text('听见歌声，也留下每一份喜欢。', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.code),
                          title: const Text('GitHub 开源项目'),
                          subtitle: const Text('KwoskySu / Vocalo1ng'),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () =>
                              openSource(context, Uri.parse(projectUrl)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.system_update_alt),
                          title: const Text('版本与下载'),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => openSource(
                            context,
                            Uri.parse(projectReleasesUrl),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.bug_report_outlined),
                          title: const Text('反馈问题与建议'),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () =>
                              openSource(context, Uri.parse(projectIssuesUrl)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('源码许可 · GPL-3.0-or-later'),
                          onTap: () => openSource(
                            context,
                            Uri.parse('$projectUrl/blob/main/LICENSE'),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.balance),
                          title: const Text('第三方开源许可'),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: appName,
                            applicationVersion: appVersion,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '本地收藏、手记和设置保存在设备上，可通过 JSON 导入导出。账号凭证不随开源源码发布。',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本应用为个人非官方客户端，与网易云音乐、QQ音乐、哔哩哔哩及VocaWiki无隶属关系。音乐、PV、歌词、百科文字与图片的权利归原权利人；具体可用性取决于平台、地区和账号权限。',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
