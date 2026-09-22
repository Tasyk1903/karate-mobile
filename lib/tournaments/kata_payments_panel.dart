import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

class KataPaymentsPanel extends StatefulWidget {
  const KataPaymentsPanel({
    super.key,
    required this.api,
    required this.strings,
    this.tournamentId,
    this.applicationId,
    this.onFulfilled,
  });
  final ApiClient api;
  final AppStrings strings;
  final int? tournamentId;
  final String? applicationId;
  final Future<void> Function()? onFulfilled;
  @override
  State<KataPaymentsPanel> createState() => KataPaymentsPanelState();
}

class KataPaymentsPanelState extends State<KataPaymentsPanel>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _rows = [];
  Timer? _timer;
  bool _busy = false, _active = true;
  String? _error;
  int _lastPage = 1, _page = 1;
  final _notified = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_active &&
          (_rows.any(
                (r) =>
                    ['creating', 'pending', 'processing'].contains(r['status']),
              ) ||
              _error != null)) {
        refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh({bool next = false}) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var page = next ? _page + 1 : 1;
      List<Map<String, dynamic>> rows;
      if (widget.applicationId != null) {
        final response = await widget.api.getJson(
          '/online-kata/applications/${widget.applicationId}',
        );
        rows = [Map<String, dynamic>.from(response['payment'] as Map)];
      } else {
        final response = await widget.api.getJson(
          '/online-kata/applications',
          query: {
            if (widget.tournamentId != null)
              'tournament_id': '${widget.tournamentId}',
            'page': '$page',
          },
        );
        rows = (response['data'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _lastPage =
            ((response['meta'] as Map?)?['last_page'] as num?)?.toInt() ?? 1;
        // The scheduler reconciles every application; poll only one here to bound provider/API traffic.
        final pending = rows
            .where(
              (r) =>
                  ['creating', 'pending', 'processing'].contains(r['status']),
            )
            .firstOrNull;
        if (pending != null) {
          final response = await widget.api.getJson(
            '/online-kata/applications/${pending['id']}',
          );
          rows[rows.indexOf(pending)] = Map<String, dynamic>.from(
            response['payment'] as Map,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _rows = next ? [..._rows, ...rows] : rows;
        _page = page;
      });
      for (final row in rows) {
        if (row['status'] == 'fulfilled' &&
            _notified.add(row['id'].toString())) {
          await widget.onFulfilled?.call();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = widget.strings.paymentCheckFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    try {
      final url = Uri.parse(row['payment_url'].toString());
      if (url.scheme != 'https' ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('url');
      }
    } catch (_) {
      if (mounted) setState(() => _error = widget.strings.paymentOpenFailed);
    }
  }

  Future<void> _retry(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.paymentRetryTitle),
        content: Text(widget.strings.paymentRetryText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.strings.save),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.postJson(
        '/online-kata/applications/${row['id']}/retry',
        body: {'confirmed': true},
      );
      await refresh();
    } catch (_) {
      if (mounted) setState(() => _error = widget.strings.paymentCheckFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_rows.isEmpty && _error == null && !_busy) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.paymentApplications,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.retry,
                onPressed: _busy ? null : refresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Text(_error!, style: const TextStyle(fontSize: 12)),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    row['student_name']?.toString() ?? '#${row['student_id']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    s.kataPaymentStatus(row['status']?.toString() ?? ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: row['status'] == 'fulfilled'
                          ? Colors.green.shade700
                          : ['canceled', 'conflict'].contains(row['status'])
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  if (row['status'] == 'conflict')
                    Text(
                      s.paymentConflictHelp,
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (row['payment_url'] != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _open(row),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(
                          s.continueToPayment,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  if (row['can_retry'] == true)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _retry(row),
                        child: Text(
                          s.paymentRetryTitle,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_page < _lastPage)
            TextButton(
              onPressed: _busy ? null : () => refresh(next: true),
              child: Text(s.loadMore),
            ),
        ],
      ),
    );
  }
}
