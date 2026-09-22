import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'student_edit_screen.dart';
import 'student_models.dart';

class StudentProfileSetupScreen extends StatefulWidget {
  const StudentProfileSetupScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.onCompleted,
    required this.onLogout,
  });

  final ApiClient api;
  final AppStrings strings;
  final Future<void> Function() onCompleted, onLogout;

  @override
  State<StudentProfileSetupScreen> createState() =>
      _StudentProfileSetupScreenState();
}

class _StudentProfileSetupScreenState extends State<StudentProfileSetupScreen> {
  StudentDetail? _student;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final response = await widget.api.getJson(
        '/students/${widget.api.accountId}',
      );
      if (mounted) {
        setState(
          () => _student = StudentDetail.fromJson(
            response['student'] as Map<String, dynamic>,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_student != null) {
      return StudentEditScreen(
        strings: widget.strings,
        api: widget.api,
        student: _student!,
        setup: true,
        onCompleted: widget.onCompleted,
        onLogout: widget.onLogout,
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.strings.studentProfileSetup),
          actions: [
            IconButton(
              tooltip: widget.strings.logout,
              icon: const Icon(Icons.logout),
              onPressed: () async {
                try {
                  await widget.onLogout();
                } catch (error) {
                  if (mounted) setState(() => _error = error.toString());
                }
              },
            ),
          ],
        ),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(widget.strings.retry),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
