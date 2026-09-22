import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';

class StudentJoinCoachScreen extends StatefulWidget {
  const StudentJoinCoachScreen({
    super.key,
    required this.api,
    required this.strings,
  });

  final ApiClient api;
  final AppStrings strings;

  @override
  State<StudentJoinCoachScreen> createState() => _StudentJoinCoachScreenState();
}

class _StudentJoinCoachScreenState extends State<StudentJoinCoachScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _coach;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    bool joined = false;
    try {
      final coach = _coach;
      final result = await widget.api.postJson(
        coach == null ? '/account/coach/preview' : '/account/coach/join',
        body: {
          'coach_code': _code.text.trim(),
          if (coach != null) ...{'coach_id': coach['id'], 'confirmed': true},
        },
      );
      if (!mounted) return;
      if (coach == null) {
        final value = result['coach'];
        if (value is! Map<String, dynamic> ||
            value['id'] is! int ||
            value['name'] is! String) {
          throw ApiException(widget.strings.invalidServerResponse);
        }
        setState(() => _coach = value);
      } else {
        final user = result['user'];
        if (result['joined'] != true ||
            user is! Map<String, dynamic> ||
            user['id'] != widget.api.accountId) {
          throw ApiException(widget.strings.invalidServerResponse);
        }
        if (!widget.api.setIdentity(user)) {
          throw ApiException(widget.strings.invalidServerResponse);
        }
        joined = true;
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          if (error is ApiException &&
              [403, 409, 422].contains(error.statusCode)) {
            _coach = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (joined && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.pageFor(context),
        appBar: AppBar(
          title: Text(s.joinCoach, style: const TextStyle(fontSize: 16)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _code,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: s.coachCode,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {
                  _coach = null;
                  _error = null;
                }),
                onSubmitted: (_) {
                  if (_coach == null) _submit();
                },
              ),
              if (_coach != null) ...[
                const SizedBox(height: 24),
                Text(s.coach, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  _coach!['name'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(s.club, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  _coach!['club']?.toString().trim().isNotEmpty == true
                      ? _coach!['club'].toString()
                      : s.clubNotSpecified,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy || _code.text.trim().isEmpty ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _coach == null ? Icons.search : Icons.person_add_alt_1,
                      ),
                label: Text(
                  _coach == null ? s.findCoach : s.confirmJoinCoach,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
