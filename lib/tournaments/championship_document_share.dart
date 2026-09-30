import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../files/download_helper.dart';

class DocumentShareCancelled implements Exception {}

class PreparedDocumentShare {
  PreparedDocumentShare(this.directory, this.files);

  final Directory directory;
  final List<DownloadedFile> files;

  Future<void> discard() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // The OS can evict cache files; remaining batches are retried by pruning.
    }
  }
}

/// Downloads the complete authorized set before handing any file to another app.
class ChampionshipDocumentShare {
  ChampionshipDocumentShare({
    required this.api,
    required this.championshipId,
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final ApiClient api;
  final int championshipId;
  final Future<Directory> Function() _temporaryDirectory;
  bool _cancelled = false;
  final _cancellation = Completer<void>();

  void cancel() {
    _cancelled = true;
    if (!_cancellation.isCompleted) _cancellation.complete();
  }

  Future<T> _waitFor<T>(Future<T> request) => Future.any([
    request,
    _cancellation.future.then<T>((_) => throw DocumentShareCancelled()),
  ]);

  void _checkCancelled() {
    if (_cancelled) throw DocumentShareCancelled();
  }

  Future<PreparedDocumentShare> prepare({
    required void Function(int completed, int total) onProgress,
  }) async {
    Directory? directory;
    try {
      final base = '/championships/$championshipId/documents';
      final documents = <int, Map<String, dynamic>>{};
      var page = 1;
      while (true) {
        _checkCancelled();
        final data = await _waitFor(
          api.getJson(base, query: {'page': '$page'}),
        );
        _checkCancelled();
        for (final item
            in (data['data'] as List).cast<Map<String, dynamic>>()) {
          documents[item['id'] as int] = item;
        }
        if (page >= (data['meta']['last_page'] as num).toInt()) break;
        page++;
      }
      final cache = Directory(
        '${(await _temporaryDirectory()).path}/championship-shares',
      );
      await cache.create(recursive: true);
      await _prune(cache);
      _checkCancelled();
      directory = await cache.createTemp('batch-');
      final files = <DownloadedFile>[];
      onProgress(0, documents.length);
      for (final item in documents.values) {
        _checkCancelled();
        final bytes = await _waitFor(
          api.getBytes('$base/${item['id']}/file', query: {'download': '1'}),
        );
        _checkCancelled();
        final name = _fileName(item);
        final file = File('${directory.path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        files.add(DownloadedFile(path: file.path, name: name));
        onProgress(files.length, documents.length);
      }
      _checkCancelled();
      return PreparedDocumentShare(directory, List.unmodifiable(files));
    } catch (_) {
      if (directory != null) {
        await PreparedDocumentShare(directory, const []).discard();
      }
      rethrow;
    }
  }

  static String _fileName(Map<String, dynamic> item) {
    final title = (item['name'] as String)
        .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"/\\|?*]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final extension = (item['extension'] as String).toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) {
      throw const FormatException('Invalid document extension');
    }
    // IDs prevent collisions; limit Unicode code points to fit filesystem names.
    final shortTitle = String.fromCharCodes(title.runes.take(48));
    return '${item['id']}-${shortTitle.isEmpty ? 'document' : shortTitle}.$extension';
  }

  static Future<void> _prune(Directory cache) async {
    // Keep successful shares long enough for Android recipients to read files.
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final item in cache.list(followLinks: false)) {
      if (item is! Directory) continue;
      try {
        if ((await item.stat()).modified.isBefore(cutoff)) {
          await item.delete(recursive: true);
        }
      } on FileSystemException {
        // An OS cache cleanup or another completed share may remove it first.
      }
    }
  }
}
