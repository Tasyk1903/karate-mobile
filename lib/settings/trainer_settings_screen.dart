import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../theme/app_colors.dart';

class TrainerSettingsScreen extends StatefulWidget {
  const TrainerSettingsScreen({
    super.key,
    required this.strings,
    required this.api,
  });

  final AppStrings strings;
  final ApiClient api;

  @override
  State<TrainerSettingsScreen> createState() => _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends State<TrainerSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  final Map<String, bool> _settings = {
    'can_attach_to_tournaments_for_students': false,
    'can_visible_number_fight_to_tournaments_for_students': false,
    'can_attach_to_examination_for_students': false,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.api.getJson('/trainer/settings');
      final settings = response['settings'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        for (final key in _settings.keys) {
          _settings[key] = settings[key] == true;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.strings.settingsLoadFailed;
        _isLoading = false;
      });
    }
  }

  Future<void> _setSetting(String key, bool value) async {
    final previous = _settings[key] ?? false;
    setState(() {
      _settings[key] = value;
      _isSaving = true;
      _error = null;
    });

    try {
      final response = await widget.api.putJson(
        '/trainer/settings',
        body: _settings,
      );
      final settings = response['settings'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        for (final itemKey in _settings.keys) {
          _settings[itemKey] = settings[itemKey] == true;
        }
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settings[key] = previous;
        _error = widget.strings.settingsSaveFailed;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageFor(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppColors.backgroundImage(context),
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.46),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _SettingsHeader(title: widget.strings.trainerSettings),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.red,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                          children: [
                            if (_error != null) ...[
                              _ErrorBanner(
                                message: _error!,
                                onRetry: _loadSettings,
                                retryLabel: widget.strings.retry,
                              ),
                              const SizedBox(height: 18),
                            ],
                            _SettingsCard(
                              isSaving: _isSaving,
                              children: [
                                _SettingToggleTile(
                                  icon: Icons.emoji_events_outlined,
                                  title:
                                      widget.strings.studentsTournamentAccess,
                                  value:
                                      _settings['can_attach_to_tournaments_for_students'] ??
                                      false,
                                  onChanged: (value) => _setSetting(
                                    'can_attach_to_tournaments_for_students',
                                    value,
                                  ),
                                ),
                                const _SettingDivider(),
                                _SettingToggleTile(
                                  icon: Icons.bolt_outlined,
                                  title: widget.strings.studentsDataAccess,
                                  accent: const Color(0xFFF5A400),
                                  value:
                                      _settings['can_visible_number_fight_to_tournaments_for_students'] ??
                                      false,
                                  onChanged: (value) => _setSetting(
                                    'can_visible_number_fight_to_tournaments_for_students',
                                    value,
                                  ),
                                ),
                                const _SettingDivider(),
                                _SettingToggleTile(
                                  icon: Icons.school_outlined,
                                  title: widget.strings.studentsExamAccess,
                                  value:
                                      _settings['can_attach_to_examination_for_students'] ??
                                      false,
                                  onChanged: (value) => _setSetting(
                                    'can_attach_to_examination_for_students',
                                    value,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: widget.strings,
        api: widget.api,
        active: null,
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const SizedBox(width: 18),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(context),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.accentFor(context),
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 58),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, required this.isSaving});

  final List<Widget> children;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isSaving ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderFor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  const _SettingToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.red,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.22,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.red,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE5E7EB),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.borderFor(context));
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.accentFor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              retryLabel,
              style: TextStyle(
                color: AppColors.accentFor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
