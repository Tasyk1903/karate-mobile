import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../theme/app_colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.strings, required this.api});
  final AppStrings strings;
  final ApiClient api;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.api.getJson('/about');
  }

  Future<void> _contact(String email) async {
    if (email.trim().isEmpty || email.contains(RegExp(r'[\r\n]'))) return;
    try {
      if (!await launchUrl(Uri(scheme: 'mailto', path: email))) {
        throw StateError('unavailable');
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
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.about, style: const TextStyle(fontSize: 18)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.aboutLoadFailed),
                    TextButton(
                      onPressed: () => setState(() {
                        _data = widget.api.getJson('/about');
                      }),
                      child: Text(s.retry),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final project = Map<String, dynamic>.from(
            data['project'] as Map? ?? {},
          );
          final company = Map<String, dynamic>.from(
            data['company'] as Map? ?? {},
          );
          final bank = Map<String, dynamic>.from(data['bank'] as Map? ?? {});
          final contacts = Map<String, dynamic>.from(
            data['contacts'] as Map? ?? {},
          );
          String value(Map<String, dynamic> map, String key) =>
              map[key]?.toString() ?? '';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: AspectRatio(
                    key: const ValueKey('about-image'),
                    aspectRatio: 1.65,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0, 0.08, 0.72, 1],
                      ).createShader(bounds),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0, 0.06, 0.94, 1],
                        ).createShader(bounds),
                        child: Image.asset(
                          'assets/images/about-kyokushin.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value(project, 'title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(value(project, 'lead')),
              const SizedBox(height: 12),
              Text(value(project, 'description')),
              for (final feature in project['features'] as List? ?? [])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(feature.toString()),
                ),
              const SizedBox(height: 12),
              Text(value(project, 'goal')),
              _section(s.companyInfo, [
                (s.companyName, value(company, 'name')),
                (s.taxId, value(company, 'inn')),
                (s.companyAddress, value(company, 'address')),
              ]),
              _section(s.bankDetails, [
                (s.bank, value(bank, 'bank')),
                (s.bik, value(bank, 'bik')),
                (s.account, value(bank, 'account')),
                (s.correspondentAccount, value(bank, 'correspondent_account')),
              ]),
              _section(s.contacts, [
                (s.workTime, value(contacts, 'work_time')),
              ]),
              for (final entry in [
                (s.generalQuestions, value(contacts, 'email')),
                (s.partnership, value(contacts, 'partners_email')),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline, color: AppColors.red),
                  title: Text(entry.$1),
                  subtitle: Text(entry.$2),
                  onTap: entry.$2.isEmpty ? null : () => _contact(entry.$2),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: s,
        api: widget.api,
        active: null,
      ),
    );
  }

  Widget _section(String title, List<(String, String)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 32),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.$1, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(row.$2),
            ],
          ),
        ),
    ],
  );
}
