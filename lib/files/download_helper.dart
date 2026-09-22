import 'dart:io';

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

  static Future<void> share(DownloadedFile file) {
    return SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: file.name),
    );
  }
}
