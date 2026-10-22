# Vocalo1ng

面向 Android 和 Windows 的个人 VOCALOID 音乐播放器。当前版本 **0.4.18**。

- 网易云音乐 / QQ 音乐搜索、漫游、播放、双语歌词与账号管理。
- 封面取色、封面及歌词效果、横竖屏布局与全屏模式。
- 自动搜索 B 站 PV，内置画质、倍速、弹幕与分页评论。
- 应用内阅读 VocaWiki，提供歌曲百科、手记、评论收藏与自定义收藏夹。
- TOP 榜单工坊：自定义1–100名、每图1–20项；空白画布不附加固定标语、统计或来源字样。大标题、副标题、署名、页脚及每个条目的标题、理由、标签可独立设置字体、颜色、字号、字距、行距、粗斜体、下划线与对齐。提供18套样式、8组配色、11种边框选择、封面放大模糊和玻璃材质；横/竖/方/紧凑画幅及画布留白可调。支持VocaWiki选取、手动条目、排序、多份草稿和JSON互通，导出高清PNG或全部分页图片ZIP。设置移至右上角。
- Android 独立运行，支持媒体通知；个人资料通过 JSON 导入导出。
- 我的收藏集中管理歌曲、百科和评论，原有收藏数据沿用。
- 生日日历：歌姬生日 / 首发纪念日、多选倒计时卡片和本地换图；当天投稿纪念曲按需读取 [Vocabirth](https://vocabirth.melodynade.com/) 公开数据，并保留来源与原曲链接。
- 12 种直播展示样式，可分别设置字体、标题与翻译字号、封面形状和大小、背景及文字效果；独立展示页支持拖动、缩放、锁定。
- Windows 桌面模式重做为逐像素透明的壁纸层组件：封面、双语歌词、频谱、硬件信息分别拖动 / 缩放，始终在图标和其他窗口后方，点击穿透；播放栏左键配置后开启，托盘双击或 Ctrl+Alt+D 切换。
- 沉浸舞台提供空间歌词、星海电台、文字影像三组九景；界面不以参考项目或网站命名。新增 12 种独立文字动画（上浮、揭幕、逐字、扇形、波浪、弹性、轴向展开、交错、切片、折页、呼吸、推镜），可组合场景、调节速度/幅度并实时预览。动画沿用行时间轴，不声称逐词对齐。
- 播放栏及歌词页提供音频可视化入口，选中当前歌曲后自动全屏，退出恢复。八种真实信号样式支持强度、线宽调整。参考页面提供本地文件工具，未发现公开歌曲导入 API；当前使用原生音源分析和独立绘制，不把歌曲或登录地址发送给外部网站。
- 桌面模式的文字默认随组件边框实时适配，可关闭自动适配改用手动比例；缩小边框时会测量完整文本并收小字号。配置拖动实时更新，磁盘保存合并执行。底部进度条成为第五个组件，可分别调位置、宽高、线条粗细及圆点大小。

桌面模式仅在 Windows 原生客户端可用。Windows 实时音频图需要支持进程回环的系统（Windows 11 / Windows 10 build 20348+），不会回退为采集其他程序。安卓只保留最多 40 个短频谱帧，不缓存整首 PCM；源不可解码时明确显示不可用，原播放不受影响。CPU/GPU/显存频率由系统及驱动报告；驱动不支持显示 --。内存频率为配置值。Web 端当前不提供原生音源分析。日历提醒目前为应用内倒计时和生日提示，不创建系统定时闹钟。

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
