import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadedFile {
  const DownloadedFile({required this.path, required this.name});

  final String path;
  final String name;
}

class DownloadHelper {
  const DownloadHelper._();

  static Future<DownloadedFile> saveBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return DownloadedFile(path: file.path, name: fileName);
  }

  static Future<void> share(DownloadedFile file, {Rect? sharePositionOrigin}) =>
      shareFiles(
        [file],
        subject: file.name,
        sharePositionOrigin: sharePositionOrigin,
      );

  static Future<void> shareFiles(
    List<DownloadedFile> files, {
    String? subject,
    Rect? sharePositionOrigin,
  }) {
    if (files.isEmpty) throw ArgumentError.value(files, 'files');
    return SharePlus.instance.share(
      ShareParams(
        files: [for (final file in files) XFile(file.path)],
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
