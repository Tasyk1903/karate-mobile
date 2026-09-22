import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

class AgreementsScreen extends StatefulWidget {
  const AgreementsScreen({
    super.key,
    required this.api,
    required this.strings,
    this.gate = false,
    this.onCompleted,
    this.onLogout,
  });
  final ApiClient api;
  final AppStrings strings;
  final bool gate;
  final Future<void> Function()? onCompleted;
  final Future<void> Function()? onLogout;

  @override
  State<AgreementsScreen> createState() => _AgreementsScreenState();
}

class _AgreementsScreenState extends State<AgreementsScreen> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _document;
  bool _busy = true;
  bool _accepted = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.getJson(
        '/agreements',
        query: {'page': '$_page'},
      );
      if (!mounted) return;
      setState(() {
        _items = (data['data'] as List? ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _lastPage = (data['last_page'] as num?)?.toInt() ?? 1;
        _document = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.strings.agreementsUnavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(int id) async {
    setState(() {
      _busy = true;
      _error = null;
      _accepted = false;
    });
    try {
      final document = await widget.api.getJson('/agreements/$id');
      if (mounted) setState(() => _document = document);
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.strings.agreementsUnavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy || !_accepted || _document == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.postJson(
        '/agreements/${_document!['id']}/accept',
        body: {
          'version': _document!['version'],
          'accepted': true,
          'locale': widget.strings.locale.name,
        },
      );
      if (!mounted) return;
      if (widget.gate && result['agreements_required'] == false) {
        await widget.onCompleted?.call();
      } else {
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : widget.strings.agreementsUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _link(String value) async {
    final uri = Uri.tryParse(value);
    final match = RegExp(r'^/panel/(?:documents|agreement-doc)/(\d+)$')
        .firstMatch(uri?.path ?? '');
    if (uri != null && !uri.hasAuthority && match != null) {
      await _open(int.parse(match[1]!));
    } else if (uri?.scheme == 'https' && uri!.userInfo.isEmpty) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return PopScope(
      canPop: !widget.gate,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.gate && _document == null,
          centerTitle: true,
          title: Text(
            strings.agreements,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          leading: _document == null
              ? null
              : IconButton(
                  tooltip: strings.agreements,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _document = null),
                ),
          actions: [
            if (widget.gate)
              IconButton(
                tooltip: strings.logout,
                icon: const Icon(Icons.logout, size: 20),
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await widget.onLogout?.call();
                        } catch (_) {
                          if (mounted) {
                            setState(() => _error = strings.logoutFailed);
                          }
                        }
                      },
              ),
          ],
        ),
        body: SafeArea(
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: _document == null
                            ? _load
                            : () => _open(_document!['id'] as int),
                        child: Text(strings.retry),
                      ),
                    ],
                    if (_document != null) ...[
                      Text(
                        _document!['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectionArea(
                        child: HtmlWidget(
                          _document!['content']?.toString() ?? '',
                          textStyle: const TextStyle(fontSize: 13, height: 1.5),
                          onTapUrl: _link,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _accepted,
                        onChanged: (value) =>
                            setState(() => _accepted = value ?? false),
                        title: Text(
                          strings.acceptAgreement,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      FilledButton(
                        onPressed: _accepted ? _accept : null,
                        child: Text(strings.continueLabel),
                      ),
                    ] else ...[
                      for (final item in _items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item['title']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            item['accepted_at'] != null
                                ? strings.agreementAccepted
                                : item['required'] == true
                                ? strings.agreementRequired
                                : '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _open(item['id'] as int),
                        ),
                      if (_items.isEmpty) Text(strings.agreementsUnavailable),
                      if (_lastPage > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: strings.previousPage,
                              onPressed: _page > 1
                                  ? () {
                                      _page--;
                                      _load();
                                    }
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('$_page / $_lastPage'),
                            IconButton(
                              tooltip: strings.nextPage,
                              onPressed: _page < _lastPage
                                  ? () {
                                      _page++;
                                      _load();
                                    }
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      if (widget.gate)
                        TextButton(
                          onPressed: widget.onCompleted,
                          child: Text(strings.retry),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
