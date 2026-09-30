import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../files/download_helper.dart';
import '../l10n/app_locale.dart';
import 'championship_document_share.dart';

class ChampionshipDocumentsScreen extends StatefulWidget {
  const ChampionshipDocumentsScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.championshipId,
  });
  final ApiClient api;
  final AppStrings strings;
  final int championshipId;
  @override
  State<ChampionshipDocumentsScreen> createState() =>
      _ChampionshipDocumentsScreenState();
}

class _ChampionshipDocumentsScreenState
    extends State<ChampionshipDocumentsScreen> {
  final _rows = <Map<String, dynamic>>[];
  int _page = 0, _last = 1;
  bool _loading = false;
  bool _retryReset = false;
  int? _busyDocument;
  String? _error;
  final _shareAnchor = GlobalKey();
  ChampionshipDocumentShare? _documentShare;
  int _shareCompleted = 0, _shareTotal = 0;
  bool _shareSheetOpen = false;
  String get _base => '/championships/${widget.championshipId}/documents';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _documentShare?.cancel();
    super.dispose();
  }

  Rect? _sharePosition() {
    final box = _shareAnchor.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareAll() async {
    if (_documentShare != null || _busyDocument != null || _loading) return;
    final operation = ChampionshipDocumentShare(
      api: widget.api,
      championshipId: widget.championshipId,
    );
    setState(() {
      _documentShare = operation;
      _shareCompleted = _shareTotal = 0;
    });
    PreparedDocumentShare? prepared;
    var handedOff = false;
    try {
      prepared = await operation.prepare(
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _shareCompleted = completed;
              _shareTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      if (prepared.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.noChampionshipDocuments)),
        );
        return;
      }
      setState(() => _shareSheetOpen = true);
      await DownloadHelper.shareFiles(
        prepared.files,
        subject: widget.strings.documents,
        sharePositionOrigin: _sharePosition(),
      );
      handedOff = true;
    } on DocumentShareCancelled {
      // Cancellation never opens the system sheet with a partial set.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.documentShareFailed)),
        );
      }
    } finally {
      try {
        if (!handedOff) await prepared?.discard();
      } finally {
        if (mounted) {
          setState(() {
            _documentShare = null;
            _shareSheetOpen = false;
          });
        }
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || _documentShare != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final page = reset ? 1 : _page + 1;
    try {
      final data = await widget.api.getJson(_base, query: {'page': '$page'});
      if (!mounted) return;
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll((data['data'] as List).cast<Map<String, dynamic>>());
        _page = page;
        _last = (data['meta']['last_page'] as num).toInt();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _retryReset = reset;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _file(
    Map<String, dynamic> item, {
    required bool download,
  }) async {
    if (_busyDocument != null || _documentShare != null) return;
    setState(() => _busyDocument = item['id'] as int);
    try {
      if (download) {
        final bytes = await widget.api.getBytes(
          '$_base/${item['id']}/file?download=1',
        );
        final file = await DownloadHelper.saveBytes(
          bytes: bytes,
          fileName: item['file_name'] as String,
        );
        if (!mounted) return;
        await DownloadHelper.share(file, sharePositionOrigin: _sharePosition());
      } else {
        final data = await widget.api.getJson('$_base/${item['id']}/link');
        final uri = Uri.parse(data['url'] as String);
        if (!['http', 'https'].contains(uri.scheme) ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError(widget.strings.documentOpenFailed);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyDocument = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: _shareAnchor,
            tooltip: s.shareAllDocuments,
            onPressed:
                _rows.isEmpty ||
                    _loading ||
                    _busyDocument != null ||
                    _documentShare != null
                ? null
                : _shareAll,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
        title: Text(
          s.documents,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          if (_documentShare != null) ...[
            LinearProgressIndicator(
              value: _shareTotal == 0 ? null : _shareCompleted / _shareTotal,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _shareTotal == 0
                          ? s.preparingDocuments
                          : s.documentShareProgress(
                              _shareCompleted,
                              _shareTotal,
                            ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: s.cancel,
                    onPressed: _shareSheetOpen
                        ? null
                        : () => _documentShare?.cancel(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in _rows) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_busyDocument == item['id'])
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    _busyDocument == null &&
                                        _documentShare == null
                                    ? () => _file(item, download: false)
                                    : null,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(s.openDocument),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _busyDocument == null &&
                                        _documentShare == null
                                    ? () => _file(item, download: true)
                                    : null,
                                icon: const Icon(
                                  Icons.download_outlined,
                                  size: 18,
                                ),
                                label: Text(s.downloadDocument),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null) Text(_error!),
                  if (!_loading && _error == null && _rows.isEmpty)
                    Text(
                      s.noChampionshipDocuments,
                      textAlign: TextAlign.center,
                    ),
                  if (!_loading && (_error != null || _page < _last))
                    TextButton(
                      onPressed: _documentShare == null
                          ? () => _load(reset: _error != null && _retryReset)
                          : null,
                      child: Text(_error != null ? s.retry : s.moreRecords),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
