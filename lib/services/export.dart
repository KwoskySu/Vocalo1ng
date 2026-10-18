import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> exportFile(Uint8List bytes, String name, String mime) async {
  if (!kIsWeb &&
      const [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: name)],
        fileNameOverrides: [name],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(bytes, mimeType: mime, name: name).saveTo(location.path);
  return true;
}
