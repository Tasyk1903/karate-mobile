import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';

Uri? notificationLink(ApiClient api, String? href) {
  if (href == null || href.isEmpty || RegExp(r'[\x00-\x20\\]').hasMatch(href)) {
    return null;
  }
  final raw = Uri.tryParse(href);
  if (raw == null || raw.userInfo.isNotEmpty || href.startsWith('//')) {
    return null;
  }
  if (raw.scheme.isNotEmpty && raw.scheme != 'https' && raw.scheme != 'http') {
    return null;
  }
  if (raw.scheme.isEmpty && !href.startsWith('/panel/')) return null;
  final uri = Uri.tryParse(api.publicUrl(href));
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

class NotificationMessage extends StatefulWidget {
  const NotificationMessage({
    super.key,
    required this.runs,
    required this.api,
    required this.strings,
    this.openLink,
  });
  final List<Map<String, dynamic>> runs;
  final ApiClient api;
  final AppStrings strings;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<NotificationMessage> createState() => _NotificationMessageState();
}

class _NotificationMessageState extends State<NotificationMessage> {
  final _recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await (widget.openLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication))) {
        throw const FormatException();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.notificationLinkError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    return Text.rich(
      TextSpan(
        children: widget.runs.map((run) {
          final uri = notificationLink(widget.api, run['href']?.toString());
          TapGestureRecognizer? recognizer;
          if (uri != null) {
            recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
            _recognizers.add(recognizer);
          }
          return TextSpan(
            text: run['text']?.toString() ?? '',
            recognizer: recognizer,
            style: uri == null
                ? null
                : const TextStyle(
                    color: AppColors.red,
                    decoration: TextDecoration.underline,
                  ),
          );
        }).toList(),
      ),
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
