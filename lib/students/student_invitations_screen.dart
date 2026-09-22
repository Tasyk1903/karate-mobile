import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'student_actions.dart';

class StudentInvitationsScreen extends StatefulWidget {
  const StudentInvitationsScreen({
    super.key,
    required this.api,
    required this.strings,
  });
  final ApiClient api;
  final AppStrings strings;
  @override
  State<StudentInvitationsScreen> createState() =>
      _StudentInvitationsScreenState();
}

class _StudentInvitationsScreenState extends State<StudentInvitationsScreen> {
  final _emails = TextEditingController();
  String _code = '';
  String? _error;
  var _rows = <Map<String, dynamic>>[];
  var _results = <Map<String, dynamic>>[];
  var _page = 0, _last = 1, _total = 0;
  bool _loading = false, _sending = false;
  final _deleting = <int>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getJson(
        '/student-invitations',
        query: {'page': '${more ? _page + 1 : 1}'},
      );
      if (!mounted) return;
      setState(() {
        _code = response['code'].toString();
        final rows = (response['data'] as List).cast<Map<String, dynamic>>();
        _rows = more ? [..._rows, ...rows] : rows;
        final meta = response['meta'] as Map;
        _page = meta['current_page'] as int;
        _last = meta['last_page'] as int;
        _total = meta['total'] as int;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final emails = _emails.text
        .split(RegExp(r'[,;\s]+'))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (_sending || emails.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await widget.api.postJson(
        '/student-invitations',
        body: {
          'emails': emails,
          'locale': widget.strings.locale.isRu ? 'ru' : 'en',
        },
      );
      if (!mounted) return;
      setState(
        () => _results = (response['results'] as List)
            .cast<Map<String, dynamic>>(),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final id = row['id'] as int;
    if (_deleting.contains(id) ||
        !await confirmStudentAction(
          context,
          widget.strings,
          widget.strings.cancelInvitation,
          widget.strings.delete,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _deleting.add(id));
    try {
      await widget.api.deleteJson('/student-invitations/$id');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.inviteStudent, style: const TextStyle(fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_code.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.coachCode, style: const TextStyle(fontSize: 12)),
                subtitle: SelectableText(
                  _code,
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: IconButton(
                  tooltip: s.copyCoachCode,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(s.codeCopied)));
                    }
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _emails,
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: s.invitationEmails,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(s.sendInvitations),
            ),
            for (final result in _results)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(result['email'].toString()),
                subtitle: Text(s.invitationResult(result['status'].toString())),
              ),
            const Divider(height: 32),
            Text(
              '${s.pendingInvitations}: $_total',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            for (final row in _rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  row['email'].toString(),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  tooltip: s.delete,
                  onPressed: _deleting.contains(row['id'])
                      ? null
                      : () => _remove(row),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_loading || _sending)
              const Center(child: CircularProgressIndicator()),
            if (_error != null && !_loading)
              TextButton(onPressed: _load, child: Text(s.retry)),
            if (_page < _last && !_loading)
              TextButton(
                onPressed: () => _load(more: true),
                child: Text(s.moreRecords),
              ),
          ],
        ),
      ),
    );
  }
}
