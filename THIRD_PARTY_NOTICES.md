# Third-party notices

Copyright (C) 2026 Vocalo1ng contributors. Original project code is licensed under GPL-3.0-or-later. Dependencies retain their own licenses.

| Component | Source and notices |
| --- | --- |
| Flutter / Dart packages | Pinned in pubspec.lock; package metadata and in-app license page |
| Node.js Mobile 18.20.4 | https://github.com/nodejs-mobile/nodejs-mobile ; assets/licenses/Nodejs-Mobile-LICENSE.txt |
| NetEaseCloudMusicApiEnhanced | https://github.com/neteasecloudmusicapienhanced/api ; upstream package license |
| dash.js 4.7.4 | https://github.com/Dash-Industry-Forum/dash.js ; BSD-3-Clause |
| QQMusicApi Python 0.8.2 | https://github.com/luren-dc/QQMusicApi ; GPL-3.0, assets/licenses/GPL-3.0.txt |
| media_kit / mpv / FFmpeg | https://github.com/media-kit/media-kit ; package and bundled library licenses and sources |
| Noto Sans SC | https://github.com/google/fonts/tree/main/ofl/notosanssc ; SIL OFL 1.1, assets/fonts/OFL.txt |
| Noto Serif SC | https://github.com/google/fonts/tree/main/ofl/notoserifsc ; SIL OFL 1.1, assets/fonts/NotoSerifSC-OFL.txt |
| ZCOOL KuaiLe | https://github.com/google/fonts/tree/main/ofl/zcoolkuaile ; SIL OFL 1.1, assets/fonts/ZCOOLKuaiLe-OFL.txt |

Songs, videos, lyrics, comments and artwork belong to their rights holders and are not licensed by this repository. VocaWiki attribution and history links are preserved; images and quotations may have separate licenses.

Redistributors must preserve required dependency notices and comply with the licenses of bundled components. Credentials, account snapshots, local libraries and private QA screenshots are excluded from this source release.
# Calendar data and artwork

The calendar queries date-specific public records from https://vocabirth.melodynade.com/ (melodynade) on demand. It does not bundle or mirror the dataset. Result cards retain source attribution and niconico links. Singer reference dates and artwork are linked to their VocaWiki entries; birthdays and release anniversaries are labelled separately. Online artwork and song records retain their original rights. User-uploaded portraits stay in local preferences and are not included in the source or releases.

# Immersive presentation design references

- Folia Major: https://github.com/chthollyphile/folia-major (upstream AGPL-3.0); full-screen lyric spacing and depth concepts.
- Mineradio: https://github.com/XxHuberrr/Mineradio (upstream GPL-3.0); star-river and cinematic spatial presentation concepts.
- JIZURA: https://github.com/852wa/JIZURA (upstream MIT); authored typography and lyric-PV composition concepts.
- Catbot3 Audio Visualizer: https://catbot-3.com/pages/tools/audio-visualizer/ ; cover / metadata / spectrum presentation reference.

Vocalo1ng 0.4.18 independently implements its scene renderer and PCM analysis. No source, Three.js runtime, models, shaders, fonts, artwork, or compiled assets from these references are bundled. Design references are credited here; independently named scenes do not imply compatibility with their project files, renderers, expression packs or export pipelines. Animation follows existing line timestamps; no word-level or intelligent beat timing is invented.

# TOP chart material references

Apple's material hierarchy (https://developer.apple.com/design/human-interface-guidelines/materials) informed the separation between translucent surfaces and legible foreground text. Flutter's ImageFiltered and BackdropFilter documentation informed avoiding full-page backdrop blur (https://api.flutter.dev/flutter/widgets/ImageFiltered-class.html and https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html). The chart templates, frame painters, gradients and bounded cover-blur cache are original implementations; no external UI assets are bundled. VocaWiki source titles and article identifiers remain in editable chart data and the editor rather than being added automatically to exported artwork.
