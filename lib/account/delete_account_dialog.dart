import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

Future<void> showDeleteAccountDialog(
  BuildContext context,
  ApiClient api,
  AppStrings strings,
) async {
  final password = TextEditingController();
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(strings.deleteAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.deleteAccountWarning),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  enabled: !busy,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: strings.password),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (busy) return;
                      if (password.text.isEmpty) {
                        setState(() => error = strings.passwordRequired);
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await api.postJson(
                          '/account/delete',
                          body: {
                            'password': password.text,
                            'confirmed': true,
                            'locale': strings.locale.name,
                          },
                        );
                        await api.onUnauthorized?.call();
                      } catch (failure) {
                        if (dialogContext.mounted) {
                          setState(() {
                            busy = false;
                            error = failure is ApiException
                                ? failure.message
                                : strings.accountDeleteFailed;
                          });
                        }
                      }
                    },
              child: Text(strings.deleteAccount),
            ),
          ],
        ),
      ),
    ),
  );
  password.dispose();
}
