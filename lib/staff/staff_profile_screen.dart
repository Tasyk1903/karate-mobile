import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../account/delete_account_dialog.dart';
import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../l10n/staff_strings.dart';
import '../navigation/coach_bottom_nav.dart';
import 'staff_widgets.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({
    super.key,
    required this.api,
    required this.strings,
  });
  final ApiClient api;
  final AppStrings strings;
  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  Map<String, dynamic>? _profile;
  final _fields = <String, TextEditingController>{};
  final _files = <String, File>{};
  final _removed = <String>{};
  bool _loading = true, _editing = false, _busy = false, _dirty = false;
  String? _error;
  static const _documents = [
    'avatar',
    'passport',
    'brand',
    'insurance',
    'iko_card',
    'certificate',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _receive(Map<String, dynamic> profile) {
    _profile = profile;
    final fields = profile['fields'];
    if (fields is Map) {
      for (final entry in fields.entries) {
        _fields
                .putIfAbsent(entry.key as String, TextEditingController.new)
                .text =
            entry.value?.toString() ?? '';
      }
    }
    _files.clear();
    _removed.clear();
    _dirty = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getJson('/staff/profile');
      if (mounted) {
        setState(() {
          _receive(response['data'] as Map<String, dynamic>);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = staffError(e, widget.strings);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pick(String field) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 3000,
        maxHeight: 3000,
        imageQuality: 90,
      );
      if (!mounted || image == null) return;
      setState(() {
        _files[field] = File(image.path);
        _removed.remove(field);
        _dirty = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = staffError(e, widget.strings));
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final removed = _removed.where((f) => f != 'avatar').toList();
      final response = await widget.api.postMultipartFiles(
        '/staff/profile',
        fields: {
          for (final entry in _fields.entries)
            if (entry.key != 'weight' ||
                _profile!['capabilities']['weight'] == true)
              entry.key: entry.value.text.trim(),
          if (_removed.contains('avatar')) 'remove_avatar': '1',
          for (var i = 0; i < removed.length; i++)
            'remove_documents[$i]': removed[i],
        },
        files: _files,
      );
      if (mounted) {
        setState(() {
          _receive(response['data'] as Map<String, dynamic>);
          _editing = false;
          _busy = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.strings.savedScore)));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = staffError(e, widget.strings);
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_dirty &&
        !await staffConfirm(
          context,
          widget.strings,
          widget.strings.unsavedQuestion,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _receive(_profile!);
      _editing = false;
      _error = null;
    });
  }

  String? _url(String field) {
    if (field == 'avatar') return _profile?['avatar_url'] as String?;
    final documents = _profile?['documents'] as Map?;
    return documents?[field] as String?;
  }

  Future<void> _view(String field) async {
    final url = _url(field);
    if (url == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: widget.strings.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  widget.api.publicUrl(url),
                  headers: widget.api.mediaHeaders(url),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(widget.strings.requestFailed),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String name, TextEditingController controller) {
    final s = widget.strings;
    final enabled =
        !_busy &&
        (name != 'weight' || _profile!['capabilities']['weight'] == true);
    final label = s.staffField(name);
    if (name == 'gender') {
      return DropdownButtonFormField<String>(
        initialValue: ['m', 'f'].contains(controller.text)
            ? controller.text
            : null,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: 'm', child: Text(s.adultMale)),
          DropdownMenuItem(value: 'f', child: Text(s.adultFemale)),
        ],
        onChanged: !enabled
            ? null
            : (value) => setState(() {
                controller.text = value ?? '';
                _dirty = true;
              }),
      );
    }
    if (name == 'rang') {
      final values = [
        for (int i = 0; i <= 10; i++) '$i кю',
        for (int i = 1; i <= 10; i++) '$i дан',
      ];
      if (controller.text.isNotEmpty && !values.contains(controller.text)) {
        values.insert(0, controller.text);
      }
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(s.rankValue(v))))
            .toList(),
        onChanged: !enabled
            ? null
            : (value) => setState(() {
                controller.text = value ?? '';
                _dirty = true;
              }),
      );
    }
    final date = name == 'birthday' || name == 'last_examination_date';
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: date,
      style: const TextStyle(fontSize: 14),
      keyboardType: name == 'weight'
          ? TextInputType.number
          : name == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: date
            ? IconButton(
                tooltip: s.delete,
                onPressed: !enabled
                    ? null
                    : () {
                        controller.clear();
                        setState(() => _dirty = true);
                      },
                icon: const Icon(Icons.clear, size: 18),
              )
            : null,
      ),
      onChanged: (_) => setState(() => _dirty = true),
      onTap: !date
          ? null
          : () async {
              final now = DateTime.now();
              final parsed = DateTime.tryParse(controller.text);
              final selected = await showDatePicker(
                context: context,
                initialDate:
                    parsed != null &&
                        parsed.isBefore(now) &&
                        parsed.year >= 1900
                    ? parsed
                    : now,
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (mounted && selected != null) {
                setState(() {
                  controller.text =
                      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                  _dirty = true;
                });
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_editing && !_busy,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !_busy) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(s.profile, style: const TextStyle(fontSize: 16)),
          leading: _editing
              ? IconButton(
                  tooltip: s.cancel,
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            if (!_editing && _profile?['capabilities']['edit'] == true)
              IconButton(
                tooltip: s.edit,
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        bottomNavigationBar: _editing
            ? null
            : CoachBottomNav(
                api: widget.api,
                strings: s,
                active: CoachNavItem.profile,
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
            ? StaffError(
                error: _error ?? s.requestFailed,
                retry: _load,
                strings: s,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_editing) ...[
                    Center(
                      child: CircleAvatar(
                        radius: 36,
                        child: _profile!['avatar_url'] == null
                            ? const Icon(Icons.person_outline, size: 36)
                            : ClipOval(
                                child: Image.network(
                                  widget.api.publicUrl(_profile!['avatar_url']),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person_outline,
                                    size: 36,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _profile!['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.api.isJudge ? s.judgeRole : s.masterRole,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profile!['email'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (widget.api.isJudge)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          '${s.judgePosition}: ${_position(s)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ] else ...[
                    for (final entry in _fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _field(entry.key, entry.value),
                      ),
                    for (final field in _documents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.staffField(field),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: _files.containsKey(field)
                            ? Text(
                                s.photoSelected,
                                style: const TextStyle(fontSize: 12),
                              )
                            : _removed.contains(field)
                            ? Text(s.documentRemoved)
                            : null,
                        onTap: _url(field) == null || _removed.contains(field)
                            ? null
                            : () => _view(field),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: s.upload,
                              onPressed: _busy ? null : () => _pick(field),
                              icon: const Icon(Icons.upload_outlined, size: 20),
                            ),
                            if (_url(field) != null ||
                                _files.containsKey(field))
                              IconButton(
                                tooltip: s.delete,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _files.remove(field);
                                        _removed.add(field);
                                        _dirty = true;
                                      }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(_busy ? s.saving : s.save),
                    ),
                    if (_profile!['capabilities']['delete_account'] == true)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => showDeleteAccountDialog(
                                context,
                                widget.api,
                                s,
                              ),
                        child: Text(s.deleteAccount),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  String _position(AppStrings s) {
    final p = _profile?['position'] as String?;
    if (p == 'referee_score') return s.refereePosition;
    final match = RegExp(r'^judge([1-4])_score$').firstMatch(p ?? '');
    return match == null ? s.noPosition : '${s.judgeRole} ${match.group(1)}';
  }
}
