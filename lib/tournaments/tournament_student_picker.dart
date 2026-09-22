import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'tournament_models.dart';

class TournamentStudentPicker extends StatefulWidget {
  const TournamentStudentPicker({
    super.key,
    required this.api,
    required this.strings,
    required this.path,
    required this.submit,
    this.single = false,
    this.optionsPath,
    this.parseStudent,
  });

  final ApiClient api;
  final AppStrings strings;
  final String path;
  final bool single;
  final String? optionsPath;
  final TournamentAttachStudent Function(Map<String, dynamic>)? parseStudent;
  final Future<void> Function(List<TournamentAttachStudent>) submit;

  @override
  State<TournamentStudentPicker> createState() =>
      _TournamentStudentPickerState();
}

class _TournamentStudentPickerState extends State<TournamentStudentPicker> {
  final _search = TextEditingController();
  final _selected = <int, TournamentAttachStudent>{};
  final _items = <TournamentAttachStudent>[];
  Timer? _debounce;
  var _page = 0;
  var _lastPage = 1;
  var _generation = 0;
  var _loading = false;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final generation = ++_generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items.clear();
    });
    try {
      final response = await widget.api.getJson(
        widget.optionsPath ?? '${widget.path}/students/attach-options',
        query: {'page': '$page', 'search': _search.text.trim()},
      );
      if (!mounted || generation != _generation) return;
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      setState(() {
        _page = page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? page;
        _items.addAll(
          (response['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(widget.parseStudent ?? TournamentAttachStudent.fromJson),
        );
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || _selected.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit(_selected.values.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.attachStudent,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${strings.selected}: ${_selected.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    enabled: !_submitting,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: strings.search,
                    ),
                    onChanged: (_) {
                      _generation++;
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => _load(reset: true),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          if (_loading) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (_page < _lastPage ||
                              (_error != null && _items.isEmpty)) {
                            return TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _load(reset: _items.isEmpty),
                              child: Text(
                                _error != null
                                    ? strings.retry
                                    : strings.moreRecords,
                              ),
                            );
                          }
                          return _items.isEmpty
                              ? Center(
                                  child: Text(
                                    strings.noAttachOptions,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        final student = _items[index];
                        return CheckboxListTile(
                          secondary: CircleAvatar(
                            radius: 18,
                            backgroundImage: (student.avatar ?? '').isNotEmpty
                                ? NetworkImage(
                                    widget.api.publicUrl(student.avatar!),
                                  )
                                : null,
                            child: (student.avatar ?? '').isEmpty
                                ? const Icon(Icons.person_outline, size: 18)
                                : null,
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selected.containsKey(student.id),
                          onChanged: _submitting
                              ? null
                              : (checked) => setState(() {
                                  if (widget.single) _selected.clear();
                                  if (checked == true) {
                                    _selected[student.id] = student;
                                  } else {
                                    _selected.remove(student.id);
                                  }
                                }),
                          title: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (student.age != null) '${student.age}',
                              if ((student.weight ?? '').isNotEmpty)
                                '${student.weight} ${strings.weightKg}',
                              if ((student.rang ?? '').isNotEmpty)
                                widget.strings.rankValue(student.rang),
                              student.club,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selected.isEmpty || _submitting
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(strings.attach),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
