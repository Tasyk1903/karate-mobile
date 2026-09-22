import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

Future<bool> acceptPaymentOffer(
  BuildContext context,
  ApiClient api,
  AppStrings strings,
) async {
  final document = await api.getJson('/agreements/1');
  if (!context.mounted) return false;
  bool accepted = false, busy = false;
  String? error;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: Text(document['title']?.toString() ?? strings.agreements),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HtmlWidget(
                        document['content']?.toString() ?? '',
                        onTapUrl: (_) => true,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: accepted,
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => accepted = value == true),
                        title: Text(
                          strings.acceptOffer,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (error != null) Text(error!),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: !accepted || busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await api.postJson(
                              '/agreements/1/accept',
                              body: {
                                'accepted': true,
                                'version': document['version'],
                              },
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (failure) {
                            if (context.mounted) {
                              setState(() {
                                error = failure.toString();
                                busy = false;
                              });
                            }
                          }
                        },
                  child: Text(strings.continueToPayment),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
