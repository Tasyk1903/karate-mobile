import '../education/education_screen.dart';
import '../tournaments/quick_fights_screen.dart';

import 'package:flutter/material.dart';

import '../about/about_screen.dart';
import '../api/api_client.dart';
import '../account/agreements_screen.dart';
import '../examinations/examinations_screen.dart';
import '../l10n/app_locale.dart';
import '../settings/trainer_settings_screen.dart';
import '../students/students_screen.dart';
import '../theme/app_colors.dart';
import '../tournaments/championships_screen.dart';

import 'coach_navigation.dart';
import '../l10n/staff_strings.dart';
export 'coach_navigation.dart' show CoachNavItem;

class CoachBottomNav extends StatelessWidget {
  const CoachBottomNav({
    super.key,
    required this.strings,
    required this.api,
    required this.active,
  });

  final AppStrings strings;
  final ApiClient api;
  final CoachNavItem? active;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? 14 : 10),
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset > 0 ? 5 : 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          if (api.bottomAvailable('judging'))
            Expanded(
              child: _NavItem(
                icon: Icons.fact_check_outlined,
                label: strings.judging,
                active: active == CoachNavItem.judging,
                onTap: () =>
                    CoachNavigation.of(context)
                        .open(context, CoachNavItem.judging),
              ),
            ),
          if (api.bottomAvailable('reviews'))
            Expanded(
              child: _NavItem(
                icon: Icons.rate_review_outlined,
                label: strings.masterReviews,
                active: active == CoachNavItem.reviews,
                onTap: () =>
                    CoachNavigation.of(context)
                        .open(context, CoachNavItem.reviews),
              ),
            ),
          if (api.bottomAvailable('rating'))
            Expanded(
              child: _NavItem(
                icon: Icons.leaderboard_rounded,
                label: strings.rating,
                active: active == CoachNavItem.rating,
                onTap: () => _openRating(context),
              ),
            ),
          if (api.bottomAvailable('feed'))
            Expanded(
              child: _NavItem(
                icon: Icons.view_agenda_rounded,
                label: strings.feed,
                active: active == CoachNavItem.feed,
                onTap: () => _openFeed(context),
              ),
            ),
          if (api.bottomAvailable('profile'))
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline_rounded,
                label: strings.profile,
                active: active == CoachNavItem.profile,
                onTap: () => _openProfile(context),
              ),
            ),
          _MoreButton(strings: strings, api: api),
        ],
      ),
    );
  }

  void _openFeed(BuildContext context) =>
      CoachNavigation.of(context).open(context, CoachNavItem.feed);

  void _openRating(BuildContext context) =>
      CoachNavigation.of(context).open(context, CoachNavItem.rating);

  void _openProfile(BuildContext context) =>
      CoachNavigation.of(context).open(context, CoachNavItem.profile);
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.strings, required this.api});

  final AppStrings strings;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: strings.more,
      visualDensity: VisualDensity.compact,
      onPressed: () => _openMenu(context),
      icon: Icon(Icons.menu_rounded, color: AppColors.mutedFor(context)),
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
    );
  }

  void _openMenu(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (api.menuAvailable('students'))
                      _MenuTile(
                        icon: Icons.groups_outlined,
                        label: strings.students,
                        onTap: () => _pushTo(
                          context,
                          StudentsScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('tournaments'))
                      _MenuTile(
                        icon: Icons.emoji_events_outlined,
                        label: strings.tournaments,
                        onTap: () => _pushTo(
                          context,
                          ChampionshipsScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('quick_fights'))
                      _MenuTile(
                        icon: Icons.bolt_outlined,
                        label: strings.quickFights,
                        onTap: () => _pushTo(
                          context,
                          QuickFightsScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('exams'))
                      _MenuTile(
                        icon: Icons.work_outline_rounded,
                        label: strings.exams,
                        onTap: () => _pushTo(
                          context,
                          ExaminationsScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('education'))
                      _MenuTile(
                        icon: Icons.school_outlined,
                        label: strings.education,
                        onTap: () => _pushTo(
                          context,
                          EducationScreen(strings: strings, api: api),
                        ),
                      ),
                    const Divider(),
                    if (api.menuAvailable('agreements'))
                      _MenuTile(
                        icon: Icons.description_outlined,
                        label: strings.agreements,
                        onTap: () => _pushTo(
                          context,
                          AgreementsScreen(api: api, strings: strings),
                        ),
                      ),
                    if (api.menuAvailable('settings'))
                      _MenuTile(
                        icon: Icons.settings_outlined,
                        label: strings.settings,
                        onTap: () => _pushTo(
                          context,
                          TrainerSettingsScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('about'))
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        label: strings.about,
                        onTap: () => _pushTo(
                          context,
                          AboutScreen(strings: strings, api: api),
                        ),
                      ),
                    if (api.menuAvailable('logout'))
                      _MenuTile(
                        icon: Icons.logout_rounded,
                        label: strings.logout,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _logout(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigation = CoachNavigation.of(context);
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(strings.logoutQuestion),
            content: error == null ? null : Text(error!),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
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
                          await navigation.onLogout();
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setState(() {
                              busy = false;
                              error = strings.logoutFailed;
                            });
                          }
                        }
                      },
                child: Text(strings.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pushTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.accentFor(context)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? AppColors.accentFor(context)
                  : AppColors.mutedFor(context),
              size: 20,
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: active
                      ? AppColors.accentFor(context)
                      : AppColors.mutedFor(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
