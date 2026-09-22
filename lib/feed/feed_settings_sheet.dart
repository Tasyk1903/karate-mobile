import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

class FeedSettingsSheet extends StatefulWidget {
  const FeedSettingsSheet({
    super.key,
    required this.api,
    required this.strings,
  });
  final ApiClient api;
  final AppStrings strings;
  @override
  State<FeedSettingsSheet> createState() => _FeedSettingsSheetState();
}

class _FeedSettingsSheetState extends State<FeedSettingsSheet> {
  Map<String, dynamic>? _city, _organization;
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getJson('/feed/settings');
      if (mounted) {
        setState(() {
          _city = data['city'] as Map<String, dynamic>?;
          _organization = data['organization'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(bool city) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FeedOptionDialog(
        api: widget.api,
        strings: widget.strings,
        city: city,
      ),
    );
    if (mounted && result != null) {
      setState(() {
        if (city) {
          _city = result;
        } else {
          _organization = result['id'] == null ? null : result;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _city == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.putJson(
        '/feed/settings',
        body: {
          'city_id': _city!['id'],
          'organization_id': _organization?['id'],
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.feedSettings,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const LinearProgressIndicator()
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.feedCity, style: const TextStyle(fontSize: 12)),
                  subtitle: Text(
                    _city?['name']?.toString() ?? s.feedChooseCity,
                  ),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _saving ? null : () => _choose(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.organization,
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    _organization?['name']?.toString() ??
                        s.feedAllOrganizations,
                  ),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _saving ? null : () => _choose(false),
                ),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(fontSize: 12)),
                TextButton(
                  onPressed: _saving ? null : _load,
                  child: Text(s.retry),
                ),
              ],
              FilledButton(
                onPressed: _loading || _saving || _city == null ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedOptionDialog extends StatefulWidget {
  const _FeedOptionDialog({
    required this.api,
    required this.strings,
    required this.city,
  });
  final ApiClient api;
  final AppStrings strings;
  final bool city;
  @override
  State<_FeedOptionDialog> createState() => _FeedOptionDialogState();
}

class _FeedOptionDialogState extends State<_FeedOptionDialog> {
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  Timer? _debounce;
  int _generation = 0, _page = 0, _lastPage = 1;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(true);
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(bool reset) async {
    final generation = ++_generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items.clear();
    });
    try {
      final result = await widget.api.getJson(
        '/feed/settings/options',
        query: {
          'type': widget.city ? 'cities' : 'organizations',
          'search': _search.text.trim(),
          'page': '$page',
        },
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll((result['data'] as List).cast<Map<String, dynamic>>());
        _page = page;
        _lastPage = (result['meta']['last_page'] as num).toInt();
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(
        widget.city ? s.feedCity : s.organization,
        style: const TextStyle(fontSize: 16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.45,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: s.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) {
                _generation++;
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(true),
                );
              },
            ),
            if (!widget.city)
              ListTile(
                title: Text(s.feedAllOrganizations),
                onTap: () =>
                    Navigator.pop(context, <String, dynamic>{'id': null}),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final item in _items)
                    ListTile(
                      dense: true,
                      title: Text(
                        item['name'].toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  if (_error != null) Text(_error!),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_error != null || _page < _lastPage)
                    TextButton(
                      onPressed: () => _load(_page == 0),
                      child: Text(_error != null ? s.retry : s.moreRecords),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}
