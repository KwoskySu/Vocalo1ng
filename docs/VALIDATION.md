# Validation scope

Focused checks cover adapters, scoped streams, retries, comment cursors, danmaku formats, responsive layouts and notifications.

Recent regression coverage:
- Android 16 compact and expanded notification cards carry explicit visible progress and elapsed/duration text; the notification and session both advance each second. Missing transient duration retains the prior value for the same media ID.
- Birthday countdown uses calendar dates across year boundaries; saved wiki and comments remain in collection tabs; Android portrait/landscape with enlarged fonts fits the calendar cards.
- Vocabirth reads validate calendar dates, parse tab-separated records, deduplicate IDs, limit thumbnail hosts, coalesce requests and retry transient failures. A live 10/19 read returned 79 records during development.
- Windows desktop overlay compiles with no-activate, transparent layered window styles and transparent hit testing. Native desktop appearance and cross-program click behavior have not been device/UI verified in this environment.
- API 28 notification reconstruction retains the progress panel without a large artwork column.
- API 36 receives duration, position, buffer, seek actions and a separate session activity; buffering pauses time extrapolation.
- Notification seeking dispatches internal transport broadcasts rather than opening an activity.
- Comment cursors advance and overlapping comments are deduplicated. Restricted previews do not advertise unsupported paging.
- Phone landscape is separate from desktop; stacked cover effects fit small thumbnails.
- About pages fit portrait and landscape; fullscreen enters and restores window mode.

Robolectric does not reproduce vendor SystemUI or a real MediaSession binder service. API 36 checks capture actual platform calls; they do not prove that all devices render identically.

Device validation should include notifications in expanded and collapsed states, buffering, seeking, pause/resume, process recreation and gestures. Public endpoint tests do not guarantee future availability, premium quality or regional access. Never put personal credentials in fixtures.

## 0.4.11 local changes

- Nine targeted Flutter checks passed: retained collection content, birthday countdown, desktop previous/next and mouse dragging, calendar alignment, six immersive modes at portrait/short-landscape/desktop sizes, and existing Android navigation/cover/account layouts with enlarged text.
- Native telemetry was compiled and exercised locally without opening windows: CPU, GPU, memory usage, configured memory value and WASAPI loopback availability were returned. The FFT uses local output samples; silence clears the signal. GPU counters may be unavailable on other hardware.
- The Windows runner compiles with real loopback FFT, five graph styles, six palettes, full-work-area placement, tray/hotkey toggles and visibility messages. Native overlay appearance, global shortcut conflicts and cross-program click behavior still need interactive device verification.
- Live publication tests validate independent typography, artwork and background settings as well as safe bounds and owner isolation.
- Immersive layouts use the existing line timestamps. They do not manufacture word-level timing. Folia is a design reference, not a bundled runtime.
- Android artifacts are compiled locally; no emulator installation or physical-device visual verification is claimed for this revision.


## 0.4.12 immersive interaction and desktop hosting

- Ten targeted Flutter checks passed: native window calls remain absent across five immersive enter/exit cycles; 25 drag updates commit one seek only after release; separate style preview selection updates visibly at 320px; desktop left click opens settings without activation and passes independent font/background/info settings; six bilingual stage modes and existing Android layouts fit their tested sizes.
- Immersion no longer changes the native fullscreen state automatically. A single retained lyric layer replaces outgoing AnimatedSwitcher layers; backdrop animation repaints its own boundary and hover only reveals hidden controls. Position streams update the transport locally.
- Windows desktop hosting attaches the layered child window to Explorer's wallpaper host behind the icon view, converts screen to parent coordinates, and never falls back to topmost on host failure. A fully transparent background skips panel painting and retains 100% content alpha. Font scale and individual information toggles persist independently.
- The Windows runner builds, but Explorer variants, icon occlusion and actual desktop transparency have not been visually verified here. Android packages are compiled without attempting emulator installation or claiming physical-device verification.


## 0.4.13 immersive resource lifetime and automatic fullscreen

- The backdrop owns two 256x256 native images (512 KiB pixel storage total, not total application/GPU memory). Shader and Picture objects are disposed after rasterization; rapid theme changes are coalesced into one in-flight worker. Clear, disposal and in-flight cancellation release images. No images/shaders are created per animation frame.
- Background paints at 20 fps only during visible foreground playback, uses a no-raster-cache hint and pauses on lifecycle/TickerMode changes. Memory-pressure events release the cache and disable its animation until re-entry. Lyric animation uses translation without a full-width opacity render target. High-DPR text sizes and malformed paragraph lengths are bounded.
- The full-window lyric route is opaque and suspends tickers underneath; closing restores the underlying page. The ordinary player animation stops during immersion. Menu settings moved to the end of the cover tool row; the immersion entry is icon-only.
- Native and web fullscreen requests are serialized/coalesced. Entering immersion requests fullscreen automatically; leaving/disposal requests the original state. A delayed-entry/early-exit regression confirms the final restore; five repeated enter/exit cycles confirm the expected native calls.
- Sixteen targeted Flutter checks passed. The headless 4K-size playing stress ran 960 frames across 32 mount/dispose cycles, with at most 23 layers. Optional VM-service GC sampling recorded retained heap 110868800 to 113853328 bytes, external usage unchanged at 131568 bytes, and post-GC RSS 329232384 to 337698816 bytes. These are test-runner measurements; they do not establish real-device GPU peaks or zero total memory growth. Native GPU/device performance remains an interactive validation item.
- Resource management follows Flutter's Shader.dispose API and rendering guidance: https://api.flutter.dev/flutter/dart-ui/Shader/dispose.html and https://docs.flutter.dev/perf/best-practices . The cache bound is specific to the owned backdrop bitmaps; framebuffers, fonts, the player and framework caches consume additional memory.


## 0.4.14 scene rebuild, real source visualizer and transparent desktop components

- The old ImmersiveBackdrop/image-pool renderer has been removed. Three manually selected design families offer nine original Canvas scenes; no intelligent beat mode, Three.js/WebGL engine, GPU texture history or outgoing lyric widget trees. At most 80 particles, 36 explicitly disposed paragraphs, 512 Unicode code points per paragraph, and 136 physical-pixel font sizes. Native framebuffer, font and playback memory still exists; these bounds are not a claim of zero total memory growth.
- Eleven targeted checks passed, including a local visual preview check. Nine scenes exercised 405 headless frames across 27 mount/dispose sequences at 320x700, 800x360 and 3840x2160, with fewer than 40 retained render layers. Cache eviction/disposal, bilingual semantics, one seek on release, repeat fullscreen restoration, native-frame sanitization, lease sharing and final-consumer stop were checked. Four original-content PNGs rendered with local Noto fonts were inspected; this is not Android hardware GPU/frame-time validation.
- Windows audio analysis uses per-process WASAPI loopback (current process tree), with 1024-point Hann FFT / 48 logarithmic bands / 128 waveform samples. A headless read-only native probe started process capture and returned CPU 8.46%, GPU 1.54%, RAM 45%, configured RAM 6000, CPU 3701 MHz on this host. GPU core/VRAM frequencies were unavailable (0 internally, displayed --). No global mix or microphone fallback is used. Windows process-loopback support requires build 20348+.
- Android analysis is a single MediaExtractor/MediaCodec worker over the currently playing source, PCM16/float only. It retains <=40 short analysis frames and decodes ahead about 600 ms; it does not retain whole-song PCM. Reads select a nearby timestamp; large seeks flush codec/history. Source failures retry at most three times before reporting unavailable; manual analysis refresh is available. It does not change the audio player, its quality, or permissions. Actual codec/CDN availability and thermal/frame-time behavior on phones remain device validation items.
- Fullscreen visualization has four real-signal styles, adjustable line width/strength, lifecycle suspension and exit restoration. Web native-source analysis is currently unsupported and explicitly reported; no generated/random spectrum substitutes for audio.
- Desktop composition uses a reusable premultiplied-alpha DIB and UpdateLayeredWindow: background alpha 0, no whole-window fade. A wallpaper child window stays below Explorer icons and other apps with transparent hit-testing; host failure does not fall back to a topmost window. Four normalized boxes are independently editable using left-click/drag/resize/sliders. Hide/host destruction releases the surface and telemetry consumer. Cover thumbnails are bounded to 768px after rejecting excessive dimensions. Shared audio/stat workers avoid duplicate capture for desktop plus the visualizer.
- CPU frequency is queried via CallNtPowerInformation, GPU and VRAM frequency via D3DKMT driver performance data; unsupported readings display --. RAM frequency remains the explicitly labelled WMI configured value. Actual Explorer wallpaper hierarchy/transparency and Android media-source decoding have not been visually verified on devices in this revision.
- Windows and Android release builds, signatures/version checks, archive privacy-path scan and final artifact hashes are recorded in E:/gpt-vocal/releases/0.4.14 and the local work log. No emulator installation, account reset or GitHub publication was performed.


## 0.4.15 text choreography and desktop auto fitting

- Twelve targeted Flutter checks passed. Nine stage layouts now exercise the twelve independent text transforms across portrait, landscape and 4K test sizes. Previews, paragraph eviction, fullscreen restoration, decoder leases, seek behavior, and new desktop configuration throttling/persistence are covered. This is headless layout/resource checking, not real-device GPU timing.
- Text motion shapes one cached paragraph and reuses at most 32 grapheme groups (96 selection rectangles) via clipping/transforms; it does not allocate per-frame text layouts or full-window opacity layers. Main and translation share one entrance clock. Background/pause freezes tickers; paused/reduced-motion text renders completely instead of waiting on a zero-progress reveal. No intelligent or invented beat timing.
- A GDI+ read-only headless test uses the exact native fitting implementation. For a mixed Chinese/Japanese line, a 160x55 box selected 14.59px, an 800x220 box selected 74.86px, 100 resizes retained at most 32 fit entries, and manual mode retained 42px. Measuring with unbounded layout height avoids GDI+'s clipped-height report falsely claiming all lines fit.
- Desktop native updates are coalesced at 40ms separately from 180ms preference writes, so continuous dragging no longer suppresses updates until release. Progress uses its own normalized box, adjustable thickness (1–24) and thumb radius (0–20). Pixel sizes scale with DPI and are constrained to the bar box. Transparency, behind-icons hosting and click-through behavior are preserved.
- The reference audio page describes local audio import and video generation. No public song-import interface was found in the inspected page; live web inspection was unavailable. No external player or upload integration is claimed. Native FFT continues to drive eight Canvas styles; entry points and automatic fullscreen remain in both playback and lyric pages. Site/project names are absent from scene/effect labels; source acknowledgements remain in third-party documentation.
- Windows/Android packages remain local. Physical Android effects/frame pacing and Explorer wallpaper-layer behavior remain device verification items; user credentials and collections are not cleared.


## 0.4.16 combined immersion and Android media compatibility

- Eighteen targeted Flutter tests passed. A pixel comparison confirms that reduced-motion lyrics render identically to the complete static lyric. Existing portrait/landscape/4K scene checks also run with the optional 64-star layer enabled; text caches remain bounded and resources are disposed.
- Two Robolectric checks passed: API36 uses MediaStyle without custom RemoteViews and publishes MediaSession duration, buffered position, seek actions and playback speed; API28 retains the custom progress template after a framework rebuild. These checks do not establish that the original vendor-specific Android16 visibility issue has been reproduced or resolved on the user's phone.
- Modern media controls follow the session data described at https://developer.android.com/media/implement/surfaces/mobile . Notification authorization completion requests a fresh playback snapshot, and the About page opens system notification settings.
- The desktop redraw scheduler uses 33ms while a playing spectrum/record needs animation and 1000ms otherwise. Unchanged snapshots do not redraw; paused desktop consumers release audio capture. Explorer-host appearance and real-device GPU/frame-time measurements remain manual validation items.
- CatBot3's page and audio-visualizer.js were read as references for audio-driven spectrum/waveform rendering. The application uses its existing native analyzer; it does not call or bundle the external site's export engine.


## 0.4.17 TOP chart workshop
- Twenty-five targeted Flutter checks pass, including custom 1–100 limits without removing hidden entries, persistent typography, reload after external import, VocaWiki selection and canonical cover URLs, phone typography controls, twelve templates in three formats with large fonts, right-header settings, and navigation.
- Actual sequential export of three complete PNGs into a ZIP is checked (PNG signatures, dimensions and page filenames); sources, reasons and ordering survive persistence and portable-data validation. Pixel buffers are released after each page. Long content grows vertically; users choose 1–20 entries per image and excessive raster dimensions are reported instead of silently cropping.
- Twelve templates were rendered using the bundled OFL fonts and locally generated sample cover art. QA screenshots and editable user content are not source/release payloads. The image byte LRU is limited to 24 entries/4 MiB; covers, backgrounds, serialized data and exported ZIPs have separate explicit size bounds.
- Android portrait/landscape and 130% text checks pass. Live VocaWiki availability, system file/share chooser interaction and real-phone GPU behavior are outside these automated checks.

## 0.4.18 independent text and chart materials

- Twenty-six targeted Flutter checks pass, including migration of old automatic copy, independent per-entry text formatting and color editing, eighteen templates in four formats with large fonts, narrow-screen editing, portable data, and actual three-page glass/cover PNG export into a ZIP. A bundled-font montage of all eighteen styles was rendered and inspected locally.
- Empty authored fields stay empty in artwork. Automatic headings, page statistics, slogans and source URLs are removed; VocaWiki metadata remains in editable data. User-authored text is preserved. Each text role and individual entry override round-trips through JSON, including italic, underline, letter/line spacing and alignment. Per-entry frames inherit the global selection unless overridden.
- Enlarged cover backgrounds use a serialized raster worker and an LRU of at most twenty-four 96x96 pixel bitmaps (864 KiB owned pixel storage). Mounted widgets hold image clones; export buffers, decoded source covers, Flutter caches and other app resources consume additional memory. Native images, pictures and shaders are disposed. No full-card/page BackdropFilter is used. A pixel comparison verifies that blur changes the raster; cache bounds and disposal are checked.
- Physical-device GPU/frame pacing, live VocaWiki requests and native save/share panels were not exercised. Windows/Android release builds and final artifact checks passed; the four APKs retain the existing signing certificate.
