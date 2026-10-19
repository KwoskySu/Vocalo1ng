# Vocalo1ng

面向 Android 和 Windows 的个人 VOCALOID 音乐播放器。当前版本 **0.4.10**。

- 网易云音乐 / QQ 音乐搜索、漫游、播放、双语歌词与账号管理。
- 封面取色、封面及歌词效果、横竖屏布局与全屏模式。
- 自动搜索 B 站 PV，内置画质、倍速、弹幕与分页评论。
- 应用内阅读 VocaWiki，提供歌曲百科、手记、评论收藏与自定义收藏夹。
- Android 独立运行，支持媒体通知；个人资料通过 JSON 导入导出。
- 我的收藏集中管理歌曲、百科和评论，原有收藏数据沿用。
- 生日日历：歌姬生日 / 首发纪念日、多选倒计时卡片和本地换图；当天投稿纪念曲按需读取 [Vocabirth](https://vocabirth.melodynade.com/) 公开数据，并保留来源与原曲链接。
- 12 种直播展示样式。独立展示页支持拖动、缩放、锁定；OBS 源保持无操作控件。Windows 桌面模式支持四边定位、透明点击穿透、封面、歌词、进度及默认音频输出设备的真实电平历史。

桌面模式从播放栏显示器按钮或直播设置进入；仅在 Windows 原生客户端可用。音频电平包含默认输出设备上其他程序的声音，不代表歌曲专属频谱。日历提醒目前为应用内倒计时和生日提示，不创建系统定时闹钟。

## 下载

查看 [Releases](https://github.com/KwoskySu/Vocalo1ng/releases)。Android 优先选择 ARM64 APK；Windows 请保留完整发行目录后运行 Vocalo1ng.exe。覆盖升级无需卸载旧版。iOS 工程保留，尚无签名发行版。

## 开发

需要 Flutter stable（Dart >=3.8）、Node.js >=22、pnpm。Windows 需要 Visual Studio C++ 桌面组件及 WebView2；QQ 音乐桌面适配需要 Python >=3.10。

```powershell
git clone https://github.com/KwoskySu/Vocalo1ng.git
cd Vocalo1ng
flutter pub get
pnpm install
.\tools\setup-qq.ps1
pnpm start
# 另开终端
flutter run -d windows
```

Web 开发：网关启动后运行 `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5418`。网关默认只绑定本机，部分功能受浏览器或平台限制。

Android 内置 Node.js Mobile 18.20.4，手机无需连接电脑。Windows 构建入口为 tools/build-native-windows.ps1，Android 为 tools/build-native-android.ps1。这些 PowerShell 打包脚本目前面向 Windows，依赖、缓存与产物默认位于 **E:/gpt-vocal**；不同电脑需要调整脚本开头的工具路径。Android 构建需要 SDK 36、NDK、CMake 和兼容 Java，见 [独立运行架构](docs/ANDROID-INDEPENDENT.md)。

## 定向检查

```powershell
node --test server/community_regression.test.mjs server/player_features.test.mjs server/player_legacy.test.mjs
flutter test test/about_fullscreen_test.dart test/player_layout_test.dart test/android_layout_test.dart test/player_refinements_test.dart
```

通知框架检查位于 android/app/src/test。JVM 框架检查不能代替厂商设备的实际视觉验收，见 [验证范围](docs/VALIDATION.md)。

## 反馈与许可

[反馈问题](https://github.com/KwoskySu/Vocalo1ng/issues) · [版本下载](https://github.com/KwoskySu/Vocalo1ng/releases)

反馈时请附版本、系统 / WebView 版本和操作步骤。不要提交 Cookie、登录二维码、账号导出或密钥。

源码采用 **GPL-3.0-or-later**，见 [LICENSE](LICENSE)。第三方依赖、运行时和字体保留各自许可证，见 [第三方声明](THIRD_PARTY_NOTICES.md)。源码不包含账号状态、个人收藏、SDK 或打包运行时。

本项目为非官方个人客户端，与网易云音乐、QQ音乐、哔哩哔哩和 VocaWiki 无隶属关系。音乐、视频、歌词、评论、百科与图片的权利归原权利人；源码许可不覆盖这些在线内容。在线可用性遵循平台、地区和账号权限，第三方接口可能变化。
