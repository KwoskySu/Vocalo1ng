# Android independent runtime

APKs contain Flutter and an embedded Node.js Mobile gateway. GatewayService runs in the private :music process. Account files stay in application-private storage; a computer or external server is not required.

- Adapters: server/; entry point: server/android_bootstrap.cjs.
- Native bridge: android/app/src/main/kotlin/app/vocashelf/vocashelf/.
- Audio: media_kit in Flutter. MediaSession and notification live in GatewayService; internal broadcasts reach Flutter without opening an activity.
- Wiki transport validates HTTPS destinations.
- Personal library exchange uses explicit JSON import/export and does not transfer platform credentials.

## Building on Windows

Install Flutter, SDK 36, NDK, CMake and compatible Java. Scripts default to E:/gpt-vocal for dependencies and outputs. Adjust the script variables for another machine. SDK binaries, gateway.zip, signing material and personal data are not committed.

tools/prepare-android-runtime.ps1 obtains the official Node.js Mobile runtime and packages production dependencies. tools/build-native-android.ps1 -SplitPerAbi creates per-architecture APKs; omitting the switch creates a universal APK. Use a stable private signing identity for distribution; the development configuration uses local Android debug signing.

Desktop distribution requires the complete Flutter release folder plus its configured gateway runtime, production packages, current server source and QQ Python environment. See lib/services/native_bootstrap.dart for deployment paths.
