import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'kata_payments_panel.dart';
import 'tournament_detail_screen.dart';
import 'tournament_models.dart';

String? kataPaymentId(Uri uri) {
  if (uri.scheme != 'karaterating' ||
      uri.host != 'payment' ||
      uri.pathSegments.length != 1) {
    return null;
  }
  final id = uri.pathSegments.single;
  return RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)
      ? id
      : null;
}

class KataPaymentReturnScreen extends StatefulWidget {
  const KataPaymentReturnScreen({
    super.key,
    required this.api,
    required this.strings,
    this.applicationId,
  });
  final ApiClient api;
  final AppStrings strings;
  final String? applicationId;
  @override
  State<KataPaymentReturnScreen> createState() =>
      _KataPaymentReturnScreenState();
}

class _KataPaymentReturnScreenState extends State<KataPaymentReturnScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.applicationId != null) _openTournament();
  }

  Future<void> _openTournament() async {
    try {
      final result = await widget.api.getJson(
        '/online-kata/applications/${widget.applicationId}',
      );
      final p = result['payment'] as Map;
      final response = await widget.api.getJson(
        '/championships/${p['championship_id']}/tournaments/${p['tournament_id']}',
      );
      final detail = Map<String, dynamic>.from(response['tournament'] as Map);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TournamentDetailScreen(
            api: widget.api,
            strings: widget.strings,
            championship: Championship.fromJson({'id': p['championship_id']}),
            item: TournamentItem.fromJson({
              ...detail,
              'id': p['tournament_id'],
              'championship_id': p['championship_id'],
            }),
          ),
        ),
      );
    } catch (_) {
      // Payment ownership is independent of access to the tournament after enrollment closes.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.strings.paymentApplications,
        style: const TextStyle(fontSize: 16),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        KataPaymentsPanel(
          api: widget.api,
          strings: widget.strings,
          applicationId: widget.applicationId,
        ),
      ],
    ),
  );
}
