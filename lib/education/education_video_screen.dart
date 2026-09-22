import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../media/protected_video_player.dart';
import '../students/student_actions.dart';
import '../account/agreements_screen.dart';
import '../account/payment_offer_dialog.dart';
import 'education_work_editor.dart';

class EducationVideoScreen extends StatefulWidget {
  const EducationVideoScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.video,
    this.workId,
  });
  final ApiClient api;
  final AppStrings strings;
  final Map<String, dynamic> video;
  final int? workId;
  @override
  State<EducationVideoScreen> createState() => _EducationVideoScreenState();
}

class _EducationVideoScreenState extends State<EducationVideoScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  Map<String, dynamic>? _payment;
  Timer? _poll;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.api.isStudent &&
        widget.workId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _poll?.cancel();
    setState(() {
      _loading = _data == null;
      _failed = false;
    });
    try {
      if (widget.api.isStudent && widget.workId != null) {
        final response = await widget.api.getJson(
          '/education/works/${widget.workId}/payment',
        );
        if (!mounted || generation != _loadGeneration) return;
        _payment = response['payment'] as Map<String, dynamic>?;
      }
      final data = widget.workId == null
          ? widget.video
          : (await widget.api.getJson(
                  '/education/works/${widget.workId}',
                ))['data']
                as Map<String, dynamic>;
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _data = data;
          _loading = false;
        });
        if (['creating', 'pending'].contains(_payment?['status'])) {
          _poll = Timer(const Duration(seconds: 8), () {
            if (mounted) _load();
          });
        }
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await acceptPaymentOffer(context, widget.api, widget.strings)) {
        return;
      }
      final response = await widget.api.postJson(
        '/education/works/${widget.workId}/payment',
        body: {'accepted': true, 'retry': _payment?['status'] == 'canceled'},
      );
      final url = Uri.tryParse(
        response['payment']?['payment_url']?.toString() ?? '',
      );
      if (url != null && url.scheme == 'https') {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await confirmStudentAction(
        context,
        widget.strings,
        widget.strings.delete,
        widget.strings.delete,
      )) {
        return;
      }
      await widget.api.postJson(
        '/education/works/${widget.workId}/delete',
        body: {'confirmed': true},
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s.video,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.educationLoadFailed),
                  TextButton(onPressed: _load, child: Text(s.retry)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  d!['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.workId != null) ...[
                  if (widget.api.isStudent)
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (d['can_edit'] == true)
                          IconButton(
                            tooltip: s.edit,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await editEducationWork(
                                          context,
                                          widget.api,
                                          s,
                                          work: {...d, 'id': widget.workId},
                                        ) &&
                                        mounted) {
                                      _load();
                                    }
                                  },
                          ),
                        if (d['can_delete'] == true)
                          IconButton(
                            tooltip: s.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy ? null : _delete,
                          ),
                        if (d['can_pay'] == true &&
                            _payment?['status'] != 'conflict')
                          FilledButton(
                            onPressed: _busy ? null : _pay,
                            child: Text(
                              '${s.continueToPayment} · ${d['price']} RUB',
                            ),
                          ),
                        if (d['can_pay'] == true)
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AgreementsScreen(
                                  api: widget.api,
                                  strings: s,
                                ),
                              ),
                            ),
                            child: Text(s.agreements),
                          ),
                        if (_payment != null)
                          Text(
                            s.educationPaymentStatus(
                              _payment!['status'].toString(),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      d['category'],
                      d['rank'],
                    ].where((v) => v != null && v != '').join(' · '),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.coach}: ${d['coach_name'] ?? '—'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (d['club'] != null)
                    Text(
                      d['club'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  EducationReviewStatus(
                    reviewed: d['is_review'] == true,
                    paid: !widget.api.isStudent || d['is_payment'] == true,
                    strings: s,
                  ),
                ],
                const SizedBox(height: 16),
                if (d['video_url'] is String)
                  ProtectedVideoPlayer(
                    key: ValueKey(d['video_url']),
                    api: widget.api,
                    url: d['video_url'] as String,
                    strings: s,
                  ),
                if (d['is_review'] == true && d['review'] is Map)
                  for (final field in [
                    'description',
                    'point',
                    'detail_point',
                    'recommendation',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (field) {
                              'description' => s.educationComment,
                              'point' => s.educationPoint,
                              'detail_point' => s.educationDetailPoint,
                              _ => s.educationRecommendation,
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d['review'][field]?.toString() ?? '—',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}

class EducationReviewStatus extends StatelessWidget {
  const EducationReviewStatus({
    super.key,
    required this.reviewed,
    this.paid = true,
    required this.strings,
  });
  final bool reviewed;
  final bool paid;
  final AppStrings strings;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        reviewed ? Icons.check_circle_outline : Icons.schedule,
        size: 15,
        color: reviewed
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          reviewed
              ? strings.educationReviewed
              : paid
              ? strings.educationWaiting
              : strings.educationUnpaid,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
