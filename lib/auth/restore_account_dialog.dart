import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

Future<void> restoreAccountDialog(
  BuildContext context,
  ApiClient api,
  AppStrings s,
) async {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool sent = false, busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(s.restoreAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  enabled: !busy && !sent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: s.email),
                ),
                if (sent) ...[
                  Text(
                    s.restoreEmailSent,
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextField(
                    controller: code,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.verificationCode),
                  ),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: s.password),
                  ),
                  TextField(
                    controller: confirmation,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: s.repeatPassword),
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            if (sent)
              TextButton(
                onPressed: busy ? null : () => setState(() => sent = false),
                child: Text(s.retry),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await api.postJson(
                          sent ? '/auth/restore/confirm' : '/auth/restore',
                          authenticated: false,
                          body: {
                            'email': email.text.trim(),
                            if (sent) ...{
                              'code': code.text.trim(),
                              'password': password.text,
                              'password_confirmation': confirmation.text,
                            },
                          },
                        );
                        if (!context.mounted) return;
                        if (sent) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            sent = true;
                            busy = false;
                          });
                        }
                      } catch (failure) {
                        if (context.mounted) {
                          setState(() {
                            error = failure.toString();
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(sent ? s.restoreAccount : s.sendCode),
            ),
          ],
        ),
      ),
    ),
  );
  email.dispose();
  code.dispose();
  password.dispose();
  confirmation.dispose();
}
