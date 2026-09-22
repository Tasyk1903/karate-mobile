import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../l10n/staff_strings.dart';

String staffError(Object error, AppStrings s) =>
    error is ApiException ? error.message : s.requestFailed;

Future<bool> staffConfirm(
  BuildContext context,
  AppStrings s,
  String title,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    ) ??
    false;

class StaffError extends StatelessWidget {
  const StaffError({
    super.key,
    required this.error,
    required this.retry,
    required this.strings,
  });
  final String error;
  final VoidCallback retry;
  final AppStrings strings;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(error, style: const TextStyle(fontSize: 13)),
        TextButton(onPressed: retry, child: Text(strings.retry)),
      ],
    ),
  );
}

class StaffMark extends StatelessWidget {
  const StaffMark({super.key, required this.reviewed, required this.strings});
  final bool reviewed;
  final AppStrings strings;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        reviewed ? Icons.check_circle_outline : Icons.schedule,
        size: 16,
        color: reviewed
            ? Colors.green
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          reviewed ? strings.reviewedWorks : strings.pendingWorks,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
